model ValveVaporizing
  "可能发生汽化的（几乎）不可压缩流体阀门，内置音速壅塞(Choked Flow)的防爆处理逻辑"
  import SI = Modelica.SIunits;
  import Modelica.Fluid.Types.CvTypes;
  import Modelica.Constants.pi;

  // 【物理地基】：继承 PartialValve 基类。
  // 基类内部已经写死了“绝对等焓膨胀”的能量守恒方程。
  // constrainedby 强制要求传入的工质 Medium 必须具备计算气液两相流(TwoPhase)的能力。
  extends BaseClasses.PartialValve(
    redeclare replaceable package Medium =
        Modelica.Media.Water.WaterIF97_ph 
    constrainedby 
      Modelica.Media.Interfaces.PartialTwoPhaseMedium);

  // =====================================================================
  // 1. ISA S75 标准气动与恢复参数
  // =====================================================================
  parameter Real Fl_nominal=0.9
    "额定液态压力恢复系数 (Liquid pressure recovery factor)。决定了缩流断面的压力下潜深度。";

  replaceable function FlCharacteristic =
      Modelica.Fluid.Valves.BaseClasses.ValveCharacteristics.one 
    constrainedby 
    Modelica.Fluid.Valves.BaseClasses.ValveCharacteristics.baseFun
    "压力恢复系数 Fl 随阀门开度动态变化的特性曲线";

  Real Ff "液体临界压力比系数 (Ff coefficient, 详见 IEC/ISA 标准)";
  Real Fl "实时压力恢复系数 (Pressure recovery coefficient Fl, 详见 IEC/ISA 标准)";

  SI.Pressure dpEff "有效压降 (Effective pressure drop，这是截断闪蒸灾难的终极变量)";
  Medium.Temperature T_in "入口温度";
  Medium.AbsolutePressure p_sat "入口温度对应的饱和蒸汽压 (引发闪蒸的物理界限)";
  Medium.AbsolutePressure p_in "入口压力";
  Medium.AbsolutePressure p_out "出口压力";

  // =====================================================================
  // 2. 摩擦与层流-湍流过渡平滑参数
  // =====================================================================
  constant SI.ReynoldsNumber Re_turbulent = 4000
    "全开阀门视作直管时的湍流临界雷诺数 -- 阀门关闭时 dp_turbulent 会动态增加";

  parameter Boolean use_Re = system.use_eps_Re
    "= true 时，湍流过渡区由雷诺数 Re 定义；否则由极小流量 m_flow_small 定义" 
    annotation(Dialog(tab="Advanced"), Evaluate=true);

  // 【动态数值保护】：计算层流到湍流过渡的压差阈值 (dp_turbulent)。
  // 这保证了在压差极小、流速极慢时，方程能平滑过渡到线性层流，避免无限求导。
  SI.AbsolutePressure dp_turbulent = if not use_Re then dp_small else 
    max(dp_small, (Medium.dynamicViscosity(state_a) + Medium.dynamicViscosity(state_b))^2*pi/8*Re_turbulent^2
                  /(valveCharacteristic(opening_actual)*Av*(Medium.density(state_a) + Medium.density(state_b))));

initial equation
  // 汽化阀门的工况太复杂，不支持根据工作点(OpPoint)反推 Cv 值，只支持正向输入。
  assert(not CvData == CvTypes.OpPoint, "汽化阀门模型不支持 OpPoint 选项 (OpPoint option not supported for vaporizing valve)");

equation
  // =====================================================================
  // 3. 获取迎风状态与计算 ISA 标准临界参数
  // =====================================================================
  p_in = port_a.p;
  p_out = port_b.p;
  T_in = Medium.temperature(state_a);

  // 【提取闪蒸引信】：查出当前入口温度下的饱和蒸汽压
  p_sat = Medium.saturationPressure(T_in);

  // IEC/ISA 经验公式：计算 Ff，修正真实流体在极速降压时的热力学迟滞效应
  Ff = 0.96 - 0.28*sqrt(p_sat/Medium.fluidConstants[1].criticalPressure);

  // 提取当前开度下的实时 Fl
  Fl = Fl_nominal*FlCharacteristic(opening_actual);

  // =====================================================================
  // 4. 【防崩溃核武器】：壅塞截断与有效压降 (dpEff)
  // =====================================================================
  // 如果实际出口压力 p_out 低于临界阈值，说明阀门内部已经发生剧烈闪蒸，气泡音速堵死流道。
  // 此时无论出口压力再怎么降，压差被强行截断（锁定）在最大有效值上！
  dpEff = if p_out < (1 - Fl^2)*p_in + Ff*Fl^2*p_sat then 
            Fl^2*(p_in - Ff*p_sat) else dp
    "考虑了可能发生的壅塞(Choked)工况后的有效压降";

  // =====================================================================
  // 5. 核心流量方程与同伦算法 (Homotopy)
  // =====================================================================
  if checkValve then
    // 模式 A：带有单向阀(Check Valve)功能，绝对不允许反向流动
    m_flow = homotopy(valveCharacteristic(opening_actual)*Av*sqrt(Medium.density(state_a))*
                           Utilities.regRoot2(dpEff,dp_turbulent,1.0,0.0,use_yd0=true,yd0=0.0),
                      valveCharacteristic(opening_actual)*m_flow_nominal*dp/dp_nominal);

  elseif not allowFlowReversal then
    // 模式 B：普通的不允许反向流动
    m_flow = homotopy(valveCharacteristic(opening_actual)*Av*sqrt(Medium.density(state_a))*
                           Utilities.regRoot(dpEff, dp_turbulent),
                      valveCharacteristic(opening_actual)*m_flow_nominal*dp/dp_nominal);

  else
    // 模式 C：【最常用模式】允许流体双向流动！
    // 物理：流量 = 开度特性 * 流通面积 * 混合密度 * 压差的平方根。
    // 数值：regRoot2 在 dp=0 处实现了绝对的 C1 连续平滑；
    //       homotopy 在仿真第 0 秒极其困难时，先用后面的纯线性公式探路，确保 100% 初始化成功！
    m_flow = homotopy(valveCharacteristic(opening_actual)*Av*
                           Utilities.regRoot2(dpEff,dp_turbulent,Medium.density(state_a),Medium.density(state_b)),
                      valveCharacteristic(opening_actual)*m_flow_nominal*dp/dp_nominal);
  end if;

  // =====================================================================
  // 6. 专属图标绘制与文档说明 (中英双语)
  // =====================================================================
  annotation (
    Icon(coordinateSystem(preserveAspectRatio=true, extent={{-100,-100},{100,100}}), graphics={
      // 在继承的基类阀门上，叠加代表"闪蒸/沸腾两相"的蓝色气泡
      Ellipse(extent={{15, 10}, {30, 25}}, lineColor={0,0,255}, fillColor={255,255,255}, fillPattern=FillPattern.Solid),
      Ellipse(extent={{-5, 25}, {10, 40}}, lineColor={0,0,255}, fillColor={255,255,255}, fillPattern=FillPattern.Solid),
      Ellipse(extent={{-25, 10}, {-10, 25}}, lineColor={0,0,255}, fillColor={255,255,255}, fillPattern=FillPattern.Solid),
      // 增加专属文字标识
      Text(extent={{-100,45},{100,85}}, textString="Vaporizing", textColor={0,0,255})
    }),
    Documentation(info="<html>
<p>本阀门模型严格遵循 IEC 534 / ISA S.75 国际标准进行尺寸计算。专为入口为不可压缩液体、出口可能闪蒸为两相流体的情况设计，完美涵盖了壅塞流动 (Choked Flow) 工况。</p>

<p>
本模型的所有底层参数详见阀门基类：
<a href=\"modelica://Modelica.Fluid.Valves.BaseClasses.PartialValve\">PartialValve</a>。
</p>

<p>模型的工作范围包含了壅塞流动：当出口压力过低，导致流体在缩流断面 (vena contracta) 发生闪蒸沸腾时，流量将被锁定；在其他情况下，模型假定为非壅塞的正常流动。</p>
<p><strong>注意：</strong> 本模型强制要求提供一个两相流工质包 (two-phase medium model)，以正确解算液态及潜在的气液两相热力学状态。</p>
<p>默认的液态压力恢复系数 <code>Fl</code> 是一个常数，由参数 <code>Fl_nominal</code> 定义。你可以通过替换 <code>FlCharacteristic</code> 函数，将恢复系数定义为随开度变化的动态函数。</p>
<p>如果 <code>checkValve</code> 为 false，阀门允许流体反向流动，并具备对称的流量特性曲线；否则，反向流动将被彻底截止 (即单向阀行为)。</p>

<p>
关于 <strong>Kv</strong> 和 <strong>Cv</strong> 参数的处理方式，详见用户指南：
<a href=\"modelica://Modelica.Fluid.UsersGuide.ComponentDefinition.ValveCharacteristics\">User's Guide</a>.
</p>
</html>",
      revisions="<html>
<ul>
<li><em>2005年11月2日</em>
    由 <a href=\"mailto:francesco.casella@polimi.it\">Francesco Casella</a> 教授编写:<br>
        自 ThermoPower 库移植并深度优化。</li>
</ul>
</html>"));
end ValveVaporizing;