model ValveCompressible
  "用于可压缩流体（气体/蒸汽）的调节阀，内置音速壅塞(Choked Flow)计算逻辑"
  extends BaseClasses.PartialValve;
  import Modelica.Fluid.Types.CvTypes;
  import SI = Modelica.SIunits;
  import Utilities = Modelica.Fluid.Utilities;
  import Modelica.Constants.pi;

  // =====================================================================
  // 1. 气体专用的额定工作点与临界压降参数
  // =====================================================================
  parameter Medium.AbsolutePressure p_nominal "额定入口绝对压力" 
    annotation(Dialog(group="Nominal operating point"));

  parameter Real Fxt_full=0.5
    "全开状态下的临界压降比公式系数 Fk*xt。它决定了气体压降到什么比例时会达到音速并发生壅塞。";

  replaceable function xtCharacteristic =
      Modelica.Fluid.Valves.BaseClasses.ValveCharacteristics.one 
    constrainedby 
    Modelica.Fluid.Valves.BaseClasses.ValveCharacteristics.baseFun
    "临界压降比特征函数 (描述 Fxt 随阀门开度的动态变化)";

  Real Fxt "实时临界压降比极限";
  Real x "实际压降比 (dp/p)";
  Real xs "饱和/壅塞压降比 (被截断后的压降比，用于截断计算)";
  Real Y "气体膨胀系数 (Compressibility/Expansion factor，修正气体密度随压力下降的体积膨胀效应)";
  Medium.AbsolutePressure p "迎风侧绝对压力 (上游压力)";

  // =====================================================================
  // 2. 摩擦与层流-湍流过渡平滑参数
  // =====================================================================
  constant SI.ReynoldsNumber Re_turbulent = 4000
    "全开状态下视作直管时的湍流临界雷诺数 -- 阀门关闭时 dp_turbulent 会动态增加";

  parameter Boolean use_Re = system.use_eps_Re
    "= true 时，湍流过渡区由雷诺数 Re 定义；否则由极小流量 m_flow_small 定义" 
    annotation(Dialog(tab="Advanced"), Evaluate=true);

  SI.AbsolutePressure dp_turbulent = if not use_Re then dp_small else 
    max(dp_small, (Medium.dynamicViscosity(state_a) + Medium.dynamicViscosity(state_b))^2*pi/8*Re_turbulent^2
                  /(max(valveCharacteristic(opening_actual),0.001)*Av*Y*(Medium.density(state_a) + Medium.density(state_b))));

protected
  // 用于 OpPoint 模式下反推 Av 的内部标称变量
  parameter Real Fxt_nominal(fixed=false) "额定临界压降比";
  parameter Real x_nominal(fixed=false) "额定压降比";
  parameter Real xs_nominal(fixed=false)
    "额定饱和(壅塞)压降比";
  parameter Real Y_nominal(fixed=false) "额定气体膨胀系数";

initial equation
  // =====================================================================
  // 3. 初始方程：依据气动力学标准反推流通面积 Av
  // =====================================================================
  if CvData == CvTypes.OpPoint then
    // 通过给定的额定工作点条件，反推阀门的绝对物理流通面积 Av
    Fxt_nominal = Fxt_full*xtCharacteristic(opening_nominal);
    x_nominal = dp_nominal/p_nominal;
    xs_nominal = smooth(0, if x_nominal > Fxt_nominal then Fxt_nominal else x_nominal);
    Y_nominal = 1 - abs(xs_nominal)/(3*Fxt_nominal);
    m_flow_nominal = valveCharacteristic(opening_nominal)*Av*Y_nominal*sqrt(rho_nominal)*Utilities.regRoot(p_nominal*xs_nominal, dp_small);
  else
    // 哑变量占位符
    Fxt_nominal = 0;
    x_nominal = 0;
    xs_nominal = 0;
    Y_nominal = 0;
  end if;

equation
  // =====================================================================
  // 4. 核心气动方程：判定音速壅塞与计算膨胀系数
  // =====================================================================
  // 迎风侧压力判定：无论是正流还是倒流，迎风侧永远是压力较高的那一端
  p = max(port_a.p, port_b.p);

  // 计算当前开度下的临界压降比上限
  Fxt = Fxt_full*xtCharacteristic(opening_actual);

  // 实际压降比
  x = dp/p;

  // 【气体防爆截断】：
  // 如果实际压降比 x 超出了临界上限 Fxt，说明气体在阀门喉部达到了音速 (Mach 1)。
  // 此时利用 max 和 min 函数，将用于计算的压降比 xs 死死锁定在 Fxt 边界上！
  xs = max(-Fxt, min(x, Fxt));

  // 【气体膨胀系数 Y】：
  // ISA 标准公式：修正气体在通过缩流断面时的密度减小效应。当达到音速壅塞时，Y 恰好等于 2/3。
  Y = 1 - abs(xs)/(3*Fxt);

  // =====================================================================
  // 5. 质量流量方程与同伦算法
  // =====================================================================
  // 理论公式：m_flow = valveCharacteristic(opening) * Av * Y * sqrt(rho) * sqrt(p * xs);
  if checkValve then
    // 模式 A：单向阀模式，绝对不允许反向流动
    m_flow = homotopy(valveCharacteristic(opening_actual)*Av*Y*sqrt(Medium.density(state_a))*
                           (if xs>=0 then Utilities.regRoot(p*xs, dp_turbulent) else 0),
                      valveCharacteristic(opening_actual)*m_flow_nominal*dp/dp_nominal);

  elseif not allowFlowReversal then
    // 模式 B：普通不允许反向流动模式
    m_flow = homotopy(valveCharacteristic(opening_actual)*Av*Y*sqrt(Medium.density(state_a))*
                           Utilities.regRoot(p*xs, dp_turbulent),
                      valveCharacteristic(opening_actual)*m_flow_nominal*dp/dp_nominal);

  else
    // 模式 C：【默认】允许双向流动模式
    m_flow = homotopy(valveCharacteristic(opening_actual)*Av*Y*
                           Utilities.regRoot2(p*xs, dp_turbulent, Medium.density(state_a), Medium.density(state_b)),
                      valveCharacteristic(opening_actual)*m_flow_nominal*dp/dp_nominal);
  end if;

  // =====================================================================
  // 6. 官方文档说明 (中英双语本地化)
  // =====================================================================
  annotation (
  Documentation(info="<html>
<p>本阀门模型严格遵循 IEC 534/ISA S.75 标准进行尺寸计算，专用于可压缩流体（气体），不包含相变逻辑，但全面覆盖了气体音速壅塞 (Choked-flow) 工况。</p>

<p>
本模型的所有底层参数详见阀门基类：
<a href=\"modelica://Modelica.Fluid.Valves.BaseClasses.PartialValve\">PartialValve</a>。
</p>

<p>本模型完美适用于气体和蒸汽管路，能够处理入口与出口之间任意极端的压差比例。</p>

<p>特征乘积系数 $F_k \cdot x_T$ 由参数 <code>Fxt_full</code> 定义，默认假设为常数。如果你需要定义 $x_T$ 系数随阀门开度动态变化的特性，可以通过替换 <code>xtCharacteristic</code> 函数来实现。</p>
<p>如果 <code>checkValve</code> 为 false，阀门允许气体反向流动，并具备对称的流量特性曲线；否则，反向流动将被彻底截止 (即单向阀行为)。</p>

<p>
关于 <strong>Kv</strong> 和 <strong>Cv</strong> 参数的处理方式，详见用户指南：
<a href=\"modelica://Modelica.Fluid.UsersGuide.ComponentDefinition.ValveCharacteristics\">User's Guide</a>.
</p>

</html>",
    revisions="<html>
<ul>
<li><em>2005年11月2日</em>
    由 <a href=\"mailto:francesco.casella@polimi.it\">Francesco Casella</a> 编写:<br>
        自 ThermoPower 库移植。</li>
</ul>
</html>"));
end ValveCompressible;