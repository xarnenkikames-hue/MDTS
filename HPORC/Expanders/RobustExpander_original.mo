// =======================================================================
  // 2. 成品膨胀机模型
  // =======================================================================
  model RobustExpander_original "稳健版容积式膨胀机 (逻辑穿透修复 / 终极封版)"

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
    parameter Real eta_mech(min=0.01, max=1.0) = 0.9 "机械传动效率 (轴承与摩擦损失)" annotation(Dialog(group="效率参数"));

    parameter SI.Inertia J_rotor = 0.05 "转子转动惯量 (kg.m2)" annotation(Dialog(group="动态惯性"));

    parameter Real PR_unload = 1.05 "触发低膨胀比卸载的临界压比" annotation(Dialog(group="安全与保护"));
    parameter Real dPR_unload = 0.05 "卸载衰减函数的平滑过渡宽度" annotation(Dialog(group="安全与保护"));

    parameter SI.Pressure dp_safe = 10.0 "查表安全托底压差阈值" annotation(Dialog(group="数值正则化设定"));
    parameter SI.Pressure p_min_reg = 100.0 "防真空除零的排气保底压力" annotation(Dialog(group="数值正则化设定"));
    parameter Real epsilon_v_min = 0.01 "容积效率绝对下限" annotation(Dialog(group="数值正则化设定"));

    parameter SI.Pressure p_in_start = 10e5 annotation(Dialog(tab="初始化"));
    parameter SI.Pressure p_out_start = 2e5 annotation(Dialog(tab="初始化"));
    parameter SI.Temperature T_in_start = 400.15 annotation(Dialog(tab="初始化"));
    parameter Medium.SpecificEnthalpy h_in_start = Medium.specificEnthalpy_pT(p_in_start, T_in_start) annotation(Dialog(tab="初始化"));
    parameter Medium.SpecificEnthalpy h_out_start = Medium.specificEnthalpy_pT(p_out_start, T_in_start - 40) annotation(Dialog(tab="初始化"));

    Medium.ThermodynamicState vaporIn;
    Medium.ThermodynamicState vaporOut_s;

    Real N_active;
    Real PR;
    Real PR_active;
    SI.Pressure p_out_safe;

    Real f_load;
    Real epsilon_v_geom "纯几何维度的容积效率";
    Real epsilon_v_limited "防爆限幅后的容积效率";
    Real epsilon_v_active "叠加卸载因子后的最终有效容积效率";

    SI.Torque tau_fluid;
    SI.VolumeFlowRate V_dot_in;

    Medium.Density rho_in(start=Medium.density_pT(p_in_start,T_in_start));
    Medium.SpecificEntropy s_in;
    Medium.SpecificEnthalpy h_ex_s;

  equation
    N_active = regStep(N_rot, N_rot, 0.0, 1e-2);

    J_rotor * der(2 * Modelica.Constants.pi * N_rot) = flange_shaft.tau + tau_fluid;

    W_dot_mech = -tau_fluid * (2 * Modelica.Constants.pi * N_rot);
    W_dot_mech = W_dot_fluid * eta_mech;

    PR = p_in / max(p_out, p_min_reg);
    PR_active = regStep(PR - 1.0, PR, 1.0, 1e-2);

    p_out_safe = p_in - regStep(p_in - p_out, p_in - p_out, dp_safe, dp_safe / 2);
    f_load = regStep(PR - PR_unload, 1.0, 0.0, dPR_unload);

    vaporIn = Medium.setState_phX(p_in, h_in, inStream(port_in.Xi_outflow));
    rho_in = Medium.density(vaporIn);
    s_in = Medium.specificEntropy(vaporIn);

    vaporOut_s = Medium.setState_psX(p_out_safe, s_in, inStream(port_in.Xi_outflow));
    h_ex_s = Medium.specificEnthalpy(vaporOut_s);

    // 【终极机理修复】：先对几何过膨胀进行限幅托底，最后再乘以卸载因子切断！
    epsilon_v_geom = epsilon_v_nom - clearance_ratio * ((PR_active)^(1/n_poly) - 1);
    epsilon_v_limited = regStep(epsilon_v_geom - epsilon_v_min, epsilon_v_geom, epsilon_v_min, 1e-2);
    epsilon_v_active = epsilon_v_limited * f_load;

    h_out = h_in + ((h_ex_s - h_in) * epsilon_s_nom) * f_load;

    V_dot_in = epsilon_v_active * V_s * N_active;
    m_flow = V_dot_in * rho_in;

    W_dot_fluid = m_flow * (h_out - h_in);

  end RobustExpander_original;