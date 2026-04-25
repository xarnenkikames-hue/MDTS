model CustomVolumetricExpander_C0
  "白盒容积式透平：C0 单机台架版（单向、鲁棒唤醒）"

  import SI = Modelica.SIunits;

  extends PartialExpander_OneWay;

  parameter SI.Volume V_s = 100e-6 "标称排量 (m3/rev)";
  parameter Real epsilon_v_nom = 0.95 "容积效率";
  parameter Real eta_is_nom = 0.80 "等熵效率";
  parameter Real eta_mech = 0.90 "机械效率";

  parameter Real C_leak(unit="kg/(s.Pa)") = 1e-7
    "等焓漏流系数";
  parameter SI.Pressure dp_eps = 1000.0
    "压差平滑尺度";
  parameter SI.Pressure p_min_reg = 1000.0
    "出口压力下限保护";

  parameter SI.Frequency N_wake = 0.05
    "唤醒频率底座（Hz），避免零速完全无排量流";

  Medium.ThermodynamicState state_in;
  SI.Density rho_in;
  Medium.SpecificEnthalpy h_is_out;
  Medium.SpecificEnthalpy dh_is;
  Medium.SpecificEnthalpy dh_real;

  SI.Pressure dp_pos;
  Real f_dp "单边压差门控因子";
  SI.Frequency N_rot_eff "有效单向转速";

  SI.MassFlowRate m_flow_disp "排量主流";
  SI.MassFlowRate m_flow_leak "漏流";
  SI.Torque tau_ideal;

equation
  state_in = Medium.setState_ph(p_in, h_in);
  rho_in   = Medium.density(state_in);

  dp_pos = noEvent(max(p_in - p_out, 0.0));
  f_dp   = noEvent(Modelica.Math.tanh(dp_pos / dp_eps));

  // 核心修正 1：零速不再让排量流完全塌死
  N_rot_eff = noEvent(max(N_rot, N_wake));

  // 核心修正 2：排量流同时受转速与正压差门控
  m_flow_disp = rho_in * V_s * epsilon_v_nom * N_rot_eff * f_dp;
  m_flow_leak = C_leak * dp_pos;

  m_flow = noEvent(max(m_flow_disp + m_flow_leak, 0.0));

  h_is_out = Medium.isentropicEnthalpy(max(p_out, p_min_reg), state_in);
  dh_is    = noEvent(max(h_in - h_is_out, 0.0));
  dh_real  = eta_is_nom * dh_is * f_dp;

  // 排量主流做功，漏流等焓旁通
  h_out = h_in - dh_real * m_flow_disp / max(m_flow, 1e-9);

  W_dot_fluid = -m_flow_disp * dh_real;

  // 核心修正 3：扭矩按流体功率 / 有效角速度得到，避免“无流有扭矩”
  tau_ideal = eta_mech * max(-W_dot_fluid, 0.0)
              / (2 * Modelica.Constants.pi * max(N_rot_eff, 1e-4));

  flange_shaft.tau = -tau_ideal;

  W_dot_mech = flange_shaft.tau * (N_rot * 2 * Modelica.Constants.pi);

end CustomVolumetricExpander_C0;