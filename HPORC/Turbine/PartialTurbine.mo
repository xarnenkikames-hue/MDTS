partial model PartialTurbine
  "第一层：透平纯物理基类 (只包含守恒定律与机械动力学，完全解耦工质与气动方程)"

  import SI = Modelica.Units.SI;
  import Modelica.Constants;
  import Modelica.Math;

  // 【修复 1】：解耦工质，允许外部 redeclare 任意介质
  replaceable package Medium = Modelica.Media.Interfaces.PartialMedium annotation (choicesAllMatching = true);

  // =======================================================================
  // 【图形修复】：强行覆写 PartialTwoPort 的排气口坐标，将其移至右下角！
  // =======================================================================
 // =======================================================================
  // 【修复】：绝对纯净的继承！不跟编译器较劲，保留 port_b 在右侧中心 (100,0)
  // =======================================================================
  extends Modelica.Fluid.Interfaces.PartialTwoPort(
    redeclare package Medium = Medium,
    port_a(
      p(start = p_a_start),
      m_flow(start = m_flow_start, min = if allowFlowReversal then -Constants.inf else 0)),
    port_b(
      p(start = p_b_start),
      m_flow(start = -m_flow_start, max = if allowFlowReversal then +Constants.inf else 0))
  );

  // =======================================================================
  // 1. 初始化参数 (Initialization)
  // =======================================================================
  parameter Medium.AbsolutePressure p_a_start = system.p_start annotation(Dialog(tab="初始化", group="流体状态"));
  parameter Real PR_start(min=1.01) = 5.0 "初始化猜测压比" annotation(Dialog(tab="初始化", group="流体状态"));
  // 【修复 2】：使用初始化压比计算初始背压，避免硬编码 5.0
  parameter Medium.AbsolutePressure p_b_start = p_a_start / PR_start annotation(Dialog(tab="初始化", group="流体状态"));
  parameter Medium.MassFlowRate m_flow_start = system.m_flow_start annotation(Dialog(tab="初始化", group="流体状态"));
  parameter SI.AngularVelocity w_start = w_nominal annotation(Dialog(tab="初始化", group="机械状态"));

  // =======================================================================
  // 2. 机械与阻力参数 (Mechanical & Dynamics)
  // =======================================================================
  parameter SI.Inertia J = 0.05 "转子等效转动惯量" 
    annotation(Dialog(tab="机械与动力学", group="1. 基础机械参数"));
  parameter SI.AngularVelocity w_nominal = 314.159 "额定机械角速度" 
    annotation(Dialog(tab="机械与动力学", group="1. 基础机械参数"));
  parameter Real eta_mech(min=0, max=1) = 0.98 "综合机械效率" 
    annotation(Dialog(tab="机械与动力学", group="1. 基础机械参数"));

  parameter Real stallTorqueFactor(min=1) = 2.0 "低速堵转扭矩倍率" 
    annotation(Dialog(tab="机械与动力学", group="2. 极值与限幅控制"));

  parameter Real B_viscous(unit="N.m.s/rad") = 1e-3 "粘性摩擦系数" 
    annotation(Dialog(tab="机械与动力学", group="3. 摩擦与阻尼"));
  parameter SI.Torque tau_coulomb = 0 "库仑摩擦扭矩" 
    annotation(Dialog(tab="机械与动力学", group="3. 摩擦与阻尼"));
  parameter SI.AngularVelocity w_coulomb = 1 "库仑摩擦平滑尺度" 
    annotation(Dialog(tab="机械与动力学", group="3. 摩擦与阻尼"));

  // =======================================================================
  // 3. 全局数值保护参数 (Advanced Regularization)
  // =======================================================================
  parameter SI.Pressure dp_small = 1e3 "压差平滑尺度" 
    annotation(Dialog(tab="高级设置", group="数值平滑保护"));
  parameter SI.AngularVelocity w_eps = 10 "扭矩重构极小转速" 
    annotation(Dialog(tab="高级设置", group="数值平滑保护"));

  // =======================================================================
  // 接口法兰与传感器 (完美错开布局)
  // =======================================================================
  // 机械主轴移到右上角
  Modelica.Mechanics.Rotational.Interfaces.Flange_b shaft "机械输出轴" 
    annotation (Placement(transformation(extent={{90,30},{110,50}})));

  // 底部三个信号引脚 (从左到右：转速、功率、扭矩)
  Modelica.Blocks.Interfaces.RealOutput w_out(unit="rad/s") "轴角速度" 
    annotation (Placement(transformation(extent={{-50,-110},{-30,-90}})));
  Modelica.Blocks.Interfaces.RealOutput W_out(unit="W") "轴机械功率" 
    annotation (Placement(transformation(extent={{-10,-110},{10,-90}})));
  Modelica.Blocks.Interfaces.RealOutput tau_out(unit="N.m") "轴驱动扭矩" 
    annotation (Placement(transformation(extent={{30,-110},{50,-90}})));

  // --- 内部热力学状态 ---
  Medium.ThermodynamicState state_a;
  Medium.ThermodynamicState state_b;
  SI.Pressure p_in "动态迎风侧上游压力";
  SI.Pressure p_out "动态迎风侧下游压力";

  // 【虚拟接口】：强制要求子类计算以下变量
  SI.Pressure p_out_eff_ab "子类需提供的 A->B 壅塞修正背压";
  SI.Pressure p_out_eff_ba "子类需提供的 B->A 壅塞修正背压";
  Real eta_is_actual "子类需提供的实时等熵效率";

  SI.SpecificEnthalpy dh_is_actual "提供给子类的实时等熵焓降";
  SI.Pressure dp;
  SI.Density rho_in;

  // --- 机械状态 ---
  SI.Angle phi(start=0, fixed=true);
  SI.AngularVelocity w(start=w_start);
  SI.AngularAcceleration a;
  SI.Power W_fluid;
  SI.Power W_rotor;
  SI.Torque tau_fluid_raw;
  SI.Torque tau_fluid;
  SI.Torque tau_loss;
  SI.Torque tau_limit;

protected
  SI.Density rho_a;
  SI.Density rho_b;
  SI.SpecificEnthalpy h_is_a;
  SI.SpecificEnthalpy h_is_b;
  SI.SpecificEnthalpy h_out_real_a;
  SI.SpecificEnthalpy h_out_real_b;
  constant SI.Torque tau_floor = 1.0;
  SI.AngularVelocity w_abs_eff;

equation
  state_a = Medium.setState_phX(port_a.p, inStream(port_a.h_outflow), inStream(port_a.Xi_outflow));
  state_b = Medium.setState_phX(port_b.p, inStream(port_b.h_outflow), inStream(port_b.Xi_outflow));

  dp = port_a.p - port_b.p;
  rho_a = Medium.density(state_a);
  rho_b = Medium.density(state_b);

  rho_in = Modelica.Fluid.Utilities.regStep(dp, rho_a, rho_b, dp_small);
  p_in   = Modelica.Fluid.Utilities.regStep(dp, port_a.p, port_b.p, dp_small);
  p_out  = Modelica.Fluid.Utilities.regStep(dp, port_b.p, port_a.p, dp_small);

  0 = port_a.m_flow + port_b.m_flow;
  port_b.Xi_outflow = inStream(port_a.Xi_outflow);
  port_a.Xi_outflow = inStream(port_b.Xi_outflow);
  port_b.C_outflow  = inStream(port_a.C_outflow);
  port_a.C_outflow  = inStream(port_b.C_outflow);

  h_is_a = Medium.isentropicEnthalpy(p_out_eff_ab, state_a);
  h_is_b = Medium.isentropicEnthalpy(p_out_eff_ba, state_b);

  dh_is_actual = Modelica.Fluid.Utilities.regStep(dp, inStream(port_a.h_outflow) - h_is_a, inStream(port_b.h_outflow) - h_is_b, dp_small);

  h_out_real_a = inStream(port_a.h_outflow) - eta_is_actual*(inStream(port_a.h_outflow) - h_is_a);
  h_out_real_b = inStream(port_b.h_outflow) - eta_is_actual*(inStream(port_b.h_outflow) - h_is_b);
  port_b.h_outflow = h_out_real_a;
  port_a.h_outflow = h_out_real_b;

  W_fluid = semiLinear(port_a.m_flow, inStream(port_a.h_outflow) - port_b.h_outflow, port_a.h_outflow - inStream(port_b.h_outflow));

  W_rotor = eta_mech * W_fluid;
  shaft.phi = phi;
  der(phi)  = w;
  a         = der(w);

  w_abs_eff = sqrt(w*w + w_eps*w_eps);
  tau_fluid_raw = W_rotor / w_abs_eff;
  tau_limit = stallTorqueFactor*max(W_rotor, 0.0)/max(w_nominal, w_eps) + tau_floor;
  tau_fluid = tau_limit*Modelica.Math.tanh(tau_fluid_raw/tau_limit);
  tau_loss = B_viscous*w + tau_coulomb*Modelica.Math.tanh(w/max(w_coulomb, 1e-6));

  J*a = tau_fluid - tau_loss + shaft.tau;

  W_out = -shaft.tau*w;
  w_out = w;
  tau_out = tau_fluid;


 // =======================================================================
  // 核心基类图标设计 (完美适配原生的 port_b 位置)
  // =======================================================================
  annotation (
    Icon(coordinateSystem(extent={{-100,-100},{100,100}}, preserveAspectRatio=true), graphics={
      // 透平本体 (梯形，从左往右膨胀)
      Polygon(origin={0,0}, lineColor={0,0,255}, fillColor={0,127,255}, fillPattern=FillPattern.Solid, points={{-40,20},{40,45},{40,-45},{-40,-20}}),

      // 高压进气导流管 (左侧中心)
      Line(points={{-100, 0}, {-40, 0}}, color={0,0,255}, thickness=1.0),

      // 【修改】：低压排气导流管回到右侧中心，精准对接原生的 port_b
      Line(points={{40, 0}, {100, 0}}, color={0,0,255}, thickness=1.0),

      // 机械主轴传动杆 (右侧靠上，依然精准对接 Y=40 的 shaft)
      Line(points={{20, 25}, {20, 40}, {100, 40}}, color={0,0,0}, thickness=1.0),

      // 底部传感器引出线
      Line(points={{-40, -35}, {-40, -100}}, color={0,0,127}, pattern=LinePattern.Dash),
      Line(points={{0, -45}, {0, -100}}, color={0,0,127}, pattern=LinePattern.Dash),
      Line(points={{40, -35}, {40, -100}}, color={0,0,127}, pattern=LinePattern.Dash),

      Text(origin={0,-100}, lineColor={0,0,255}, extent={{-100,20},{100,-20}}, textString="%name")
    }),
    Documentation(info="<html><p><b>透平纯物理基类</b></p><p>处理了严谨的机械阻尼、堵转转矩限幅与信号输出。机械轴位于右上角，完美避开标准流体接口。</p></html>")
  );
end PartialTurbine;