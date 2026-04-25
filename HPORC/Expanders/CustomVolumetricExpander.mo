model CustomVolumetricExpander "白盒容积式透平V5.2：零流奇点绝杀版 (极性定标 + 鲁棒唤醒)"
  import SI = Modelica.SIunits;

  extends BaseClasses.PartialExpander;

  parameter SI.Volume V_s = 100e-6 "标称排量 (m3/rev)";
  parameter Real epsilon_v_nom = 0.95 "容积效率";
  parameter Real eta_is_nom = 0.80 "等熵效率";
  parameter Real eta_mech = 0.90 "机械传动效率";

  // 【救命回调】：恢复 1e-7，防止上游 basicHX1 跌穿零流容差引发 0/0 暴毙！
  parameter Real C_leak(unit="kg/(s.Pa)") = 1e-7 "等焓漏气/暖管底流系数";
  parameter SI.Pressure dp_eps = 1000.0 "启动扭矩压差平滑尺度 (Pa)";

  Medium.ThermodynamicState state_in;
  SI.Density rho_in;
  Medium.SpecificEnthalpy h_is_out;
  Medium.SpecificEnthalpy dh_is;
  Medium.SpecificEnthalpy dh_real;

  SI.MassFlowRate m_flow_disp "排量主流";
  SI.MassFlowRate m_flow_leak "暖管漏流";
  SI.Frequency N_rot_eff "单向有效转速";

  SI.Torque tau_ideal "理想驱动扭矩";
  Real f_dp "压差平滑门控因子";

equation
  state_in = Medium.setState_phX(p_in, h_in, inStream(port_in.Xi_outflow));
  rho_in = Medium.density(state_in);

  // 1. 绝对切断负向吞吐
  N_rot_eff = noEvent(max(N_rot, 0.0));

  m_flow_disp = rho_in * V_s * epsilon_v_nom * N_rot_eff;
  m_flow_leak = C_leak * noEvent(max(p_in - p_out, 0.0));
  m_flow = m_flow_disp + m_flow_leak;

  h_is_out = Medium.isentropicEnthalpy(max(p_out, 1000), state_in);
  dh_is = max(h_in - h_is_out, 0.0);
  dh_real = if p_in > p_out then eta_is_nom * dh_is else 0.0;

  // 2. 出口焓安全混合
  h_out = h_in - dh_real * m_flow_disp / max(m_flow, 1e-12);

  W_dot_fluid = -m_flow_disp * dh_real;

  // 3. 【极净单边平滑】：只在正压差侧启用 tanh，杜绝 t=0 时的任何扭矩抖动
  f_dp = noEvent(if p_in > p_out then Modelica.Math.tanh((p_in - p_out) / dp_eps) else 0.0);
  tau_ideal = (rho_in * V_s * epsilon_v_nom * dh_real * eta_mech) / (2 * Modelica.Constants.pi);

  // 4. 【极性定标】：带上负号，挂上前进挡！
  flange_shaft.tau = - f_dp * tau_ideal;

  W_dot_mech = flange_shaft.tau * (N_rot * 2 * Modelica.Constants.pi);

  annotation (Icon(coordinateSystem(extent={{-100,-100},{100,100}}), graphics={Text(origin={0,-40}, lineColor={0,0,255}, textString="V_s=%V_s")}));
end CustomVolumetricExpander;