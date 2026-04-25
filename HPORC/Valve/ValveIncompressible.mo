model ValveIncompressible "用于（几乎）不可压缩流体的基础调节阀"
  import SI = Modelica.SIunits;
  extends BaseClasses.PartialValve; // 继承基类：直接获取绝对等焓方程、开度滤波、流导换算等核心能力
  import Modelica.Fluid.Types.CvTypes;
  import Modelica.Constants.pi;
  import Utilities = Modelica.Fluid.Utilities;

  // =====================================================================
  // 1. 层流-湍流过渡平滑参数 (防奇异核心)
  // =====================================================================
  constant SI.ReynoldsNumber Re_turbulent = 4000
  "全开状态下视作直管时的湍流临界雷诺数。当阀门关小时，等效的 dp_turbulent 会动态增大";

  parameter Boolean use_Re = system.use_eps_Re
  "= true 时，湍流过渡区由雷诺数 Re 决定；否则由全局极小流量 m_flow_small 决定" 
    annotation(Dialog(tab="Advanced"), Evaluate=true);

  // 【架构师深度批注】：
  // 纯液体流量公式是 m = Av * sqrt(dp)。当 dp=0 时，sqrt 的导数是无穷大，会导致求解器雅可比矩阵爆炸！
  // 官方的黑魔法是：在极小压差 (dp_turbulent) 范围内，把抛物线偷偷替换成一段平滑的直线（模拟层流）。
  // 这里复杂的公式，是根据雷诺数、动态粘度、密度动态反推出来的“层流压差界限”。
  // 注意里面的 max(relativeFlowCoefficient, 0.001)，这防止了阀门全关时除以零的绝症！
  SI.AbsolutePressure dp_turbulent = if not use_Re then dp_small else 
    max(dp_small, (Medium.dynamicViscosity(state_a) + Medium.dynamicViscosity(state_b))^2*pi/8*Re_turbulent^2
                  /(max(relativeFlowCoefficient,0.001)*Av*(Medium.density(state_a) + Medium.density(state_b))));

protected
  Real relativeFlowCoefficient "当前物理开度对应的相对流通能力比例 (0~1)";

// =====================================================================
// 2. 初始方程：额定工作点反推
// =====================================================================
initial equation
  if CvData == CvTypes.OpPoint then
      // 如果工程师不输入 Cv/Kv，而是输入了 nominal (额定) 工况点的压降和流量，
      // 模型会在第 0 秒，利用这个公式自动反推出阀门的绝对流通面积 Av！
      m_flow_nominal = valveCharacteristic(opening_nominal)*Av*sqrt(rho_nominal)*Utilities.regRoot(dp_nominal, dp_small)
    "通过额定工作点反推确定 Av 面积";
  end if;

// =====================================================================
// 3. 核心流量方程 (纯粹的平方根定律)
// =====================================================================
equation
  // 理论基础公式：m_flow = valveCharacteristic(opening) * Av * sqrt(rho) * sqrt(dp);

  // 从基类获取特性曲线映射（例如：线性、等百分比等）
  relativeFlowCoefficient = valveCharacteristic(opening_actual);

  if checkValve then
    // 模式 A：单向阀模式 (绝对禁止倒流)
    m_flow = homotopy(relativeFlowCoefficient*Av*sqrt(Medium.density(state_a))*
                           Utilities.regRoot2(dp,dp_turbulent,1.0,0.0,use_yd0=true,yd0=0.0),
                      relativeFlowCoefficient*m_flow_nominal*dp/dp_nominal);

  elseif not allowFlowReversal then
    // 模式 B：普通不倒流模式
    m_flow = homotopy(relativeFlowCoefficient*Av*sqrt(Medium.density(state_a))*
                           Utilities.regRoot(dp, dp_turbulent),
                      relativeFlowCoefficient*m_flow_nominal*dp/dp_nominal);

  else
    // 模式 C：【默认】允许流体双向流动
    // regRoot2：在 dp=0 附近用抛物线-直线平滑拼接技术，消灭了零点导数无穷大。
    // homotopy：同伦算法。在第 0 秒使用后半段的“纯线性方程”粗解，收敛后再渐变到前半段的“平方根物理真解”。
    m_flow = homotopy(relativeFlowCoefficient*Av*
                           Utilities.regRoot2(dp,dp_turbulent,Medium.density(state_a),Medium.density(state_b)),
                      relativeFlowCoefficient*m_flow_nominal*dp/dp_nominal);
  end if;

// =====================================================================
// 4. 官方文档说明 (中英双语本地化)
// =====================================================================
annotation (
Documentation(info="<html>
<p>
本阀门模型基于 IEC 534/ISA S.75 标准进行尺寸计算，专用于不可压缩流体 (液体)。</p>

<p>
本模型的所有底层参数详见阀门基类：
<a href=\"modelica://Modelica.Fluid.Valves.BaseClasses.PartialValve\">PartialValve</a>。
</p>

<p>
<b>【适用范围界定】</b>：<br>
本模型假设流体具有极低的压缩性，这对于所有液体都是成立的。<br>
<b>妙用提示</b>：本模型也可以用于气体/蒸汽回路！前提是：阀门前后的压降 $\Delta P$ 必须小于入口绝对压力 $P_{in}$ 的 0.2 倍。在这种微小压降下，气体密度在阀内几乎不发生变化，可近似按不可压缩流体处理计算，从而极大提升仿真速度。</p>

<p>
如果 <code>checkValve</code> 为 false，阀门允许流体反向流动，并具备对称的流量特性曲线；否则，反向流动将被彻底截止 (即单向阀行为)。
</p>

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
end ValveIncompressible;