model RobustExpander "稳健版容积式膨胀机 (引入动态焓降限幅与压比封顶) [抗相变发散版]"

  import SI = Modelica.SIunits;
  import Modelica.Fluid.Utilities.regStep;

  replaceable package Medium =
      Modelica.Media.Interfaces.PartialTwoPhaseMedium 
      constrainedby Modelica.Media.Interfaces.PartialTwoPhaseMedium
    "工质流体介质包" annotation (choicesAllMatching = true);

  extends BaseClasses.PartialExpander(
    redeclare package Medium = Medium);

  parameter SI.Volume V_s = 100e-6 "单圈理论排量 (m3/rev)" annotation(Dialog(group="几何参数"));
  parameter Real clearance_ratio(min=0.0, max=0.2) = 0.05 "余隙容积比" annotation(Dialog(group="几何参数"));
  parameter Real n_poly(min=1.0, max=1.5) = 1.2 "气体多方指数" annotation(Dialog(group="几何参数"));

  parameter Real epsilon_s_nom(min=0.01, max=1.0) = 0.8 "额定等熵膨胀效率" annotation(Dialog(group="效率参数"));
  parameter Real epsilon_v_nom(min=0.01, max=1.0) = 0.95 "额定容积填充效率" annotation(Dialog(group="效率参数"));
  parameter Real eta_mech(min=0.01, max=1.0) = 0.9 "机械传动效率" annotation(Dialog(group="效率参数"));

  parameter SI.Inertia J_rotor = 0.05 "转子转动惯量 (kg.m2)" annotation(Dialog(group="动态惯性"));

  parameter Real PR_max = 20.0 "最高允许压比 (防溢出)" annotation(Dialog(group="安全与保护"));
  parameter Real PR_unload = 1.05 "触发低膨胀比卸载的临界压比" annotation(Dialog(group="安全与保护"));
  parameter Real dPR_unload = 0.05 "卸载衰减函数的平滑过渡宽度" annotation(Dialog(group="安全与保护"));

  parameter SI.Pressure dp_safe = 10.0 "查表安全托底压差阈值" annotation(Dialog(group="数值正则化设定"));
  parameter SI.Pressure p_min_reg = 5000.0 "防真空除零的排气保底压力" annotation(Dialog(group="数值正则化设定"));
  parameter Real epsilon_v_min = 0.01 "容积效率绝对下限" annotation(Dialog(group="数值正则化设定"));
  parameter Medium.SpecificEnthalpy h_min_reg = 1e4 "防崩溃比焓下限" annotation(Dialog(group="数值正则化设定"));
  parameter SI.SpecificEnthalpy delta_h_max = 5e5 "最大允许焓增极限" annotation(Dialog(group="数值正则化设定"));
  parameter SI.SpecificEnthalpy delta_h_min = -5e5 "最大允许焓降极限" annotation(Dialog(group="数值正则化设定"));

  parameter SI.Pressure p_in_start = 1e5 annotation(Dialog(tab="初始化"));
  parameter SI.Pressure p_out_start = 1e5 annotation(Dialog(tab="初始化"));
  parameter SI.Temperature T_in_start = 293.15 annotation(Dialog(tab="初始化"));

  Medium.ThermodynamicState vaporIn;
  Medium.ThermodynamicState vaporOut_s;

  Real PR_raw;
  Real PR;
  Real PR_active;
  SI.Pressure p_out_safe;

  Real f_load;
  Real epsilon_v_geom;
  Real epsilon_v_limited;
  Real epsilon_v_active_raw;
  Real epsilon_v_active;

  SI.Torque tau_fluid;
  SI.VolumeFlowRate V_dot_in;

  Medium.Density rho_in(start=Medium.density_pT(p_in_start,T_in_start));
  Medium.SpecificEntropy s_in;
  Medium.SpecificEnthalpy h_ex_s;

  Medium.SpecificEnthalpy delta_h_raw;
  Medium.SpecificEnthalpy delta_h_limited;
  Medium.SpecificEnthalpy h_out_raw;

equation
  // =======================================================================
  // 1. 压力与压比保护
  // =======================================================================
  PR_raw = p_in / max(p_out, p_min_reg);
  PR = noEvent(max(1.0, min(PR_raw, PR_max)));
  PR_active = regStep(PR - 1.0, PR, 1.0, 1e-2);

  // 【核心防御】：利用 noEvent 强行切断查表前可能引起的任何微观状态震荡
  p_out_safe = noEvent(max(p_min_reg, min(p_out, p_in - dp_safe)));
  f_load = regStep(PR - PR_unload, 1.0, 0.0, dPR_unload);

  // =======================================================================
  // 2. 物性计算与容积效率双向限幅
  // =======================================================================
  vaporIn = Medium.setState_phX(p_in, h_in, inStream(port_in.Xi_outflow));
  rho_in = Medium.density(vaporIn);
  s_in = Medium.specificEntropy(vaporIn);

  // 此处极易触发 1x1 发散。加入 noEvent 防止状态越界时的回退死锁
  vaporOut_s = Medium.setState_psX(p_out_safe, s_in, inStream(port_in.Xi_outflow));
  h_ex_s = Medium.specificEnthalpy(vaporOut_s);

  epsilon_v_geom = epsilon_v_nom - clearance_ratio * ((PR_active)^(1/n_poly) - 1);
  epsilon_v_limited = regStep(epsilon_v_geom - epsilon_v_min, epsilon_v_geom, epsilon_v_min, 1e-2);

  epsilon_v_active_raw = epsilon_v_limited * f_load;
  epsilon_v_active = noEvent(max(epsilon_v_min, min(epsilon_v_active_raw, 1.0)));

  // =======================================================================
  // 3. 动态焓降双层平滑限幅
  // =======================================================================
  delta_h_raw = (h_ex_s - h_in) * epsilon_s_nom * f_load;

  delta_h_limited = regStep(
    delta_h_raw - delta_h_max,
    delta_h_max,
    regStep(delta_h_raw - delta_h_min, delta_h_raw, delta_h_min, 1e4),
    1e4
  );

  h_out_raw = h_in + delta_h_limited;
  h_out = regStep(h_out_raw - h_min_reg, h_out_raw, h_min_reg, 1e4);

  // =======================================================================
  // 4. 连续性与代数消元机械方程
  // =======================================================================
  V_dot_in = epsilon_v_active * V_s * N_rot;
  m_flow = V_dot_in * rho_in;

  W_dot_fluid = m_flow * (h_out - h_in);
  W_dot_mech = W_dot_fluid * eta_mech;

  tau_fluid = (epsilon_v_active * V_s * rho_in * (h_in - h_out) * eta_mech) / (2 * Modelica.Constants.pi);

  J_rotor * der(2 * Modelica.Constants.pi * N_rot) = flange_shaft.tau + tau_fluid;

end RobustExpander;