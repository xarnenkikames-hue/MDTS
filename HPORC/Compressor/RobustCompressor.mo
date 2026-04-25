model RobustCompressor "稳健增强版容积式压缩机 (MSL 原生动力学 / 湿压缩机理修正版)"

    import SI = Modelica.SIunits;
    import Modelica.Fluid.Utilities.regStep;

    replaceable package Medium =
        Modelica.Media.Interfaces.PartialTwoPhaseMedium 
        constrainedby Modelica.Media.Interfaces.PartialTwoPhaseMedium
      "工质流体介质包" annotation (choicesAllMatching = true);

    extends BaseClasses.PartialCompressor(
      redeclare package Medium = Medium);

    // =======================================================================
    // 2. PARAMETERS
    // =======================================================================
    parameter SI.Volume V_s = 100e-6 "单圈理论排量 (m3/rev)" annotation(Dialog(group="几何参数"));
    parameter Real clearance_ratio(min=0.0, max=0.2) = 0.05 "余隙容积比" annotation(Dialog(group="几何参数"));
    parameter Real n_poly(min=1.0, max=1.5) = 1.2 "气体回膨胀多方指数" annotation(Dialog(group="几何参数"));

    parameter Real epsilon_s_nom(min=0.01, max=1.0) = 0.7 "额定等熵压缩效率" annotation(Dialog(group="效率参数"));
    parameter Real epsilon_v_nom(min=0.01, max=1.0) = 0.95 "额定容积效率" annotation(Dialog(group="效率参数"));

    parameter SI.Inertia J_rotor = 0.05 "转子转动惯量 (kg.m2)" annotation(Dialog(group="动态惯性"));

    parameter SI.TemperatureDifference SH_min = 5.0 "触发湿压缩惩罚的过热度阈值 (K)" annotation(Dialog(group="安全与惩罚矩阵"));
    parameter SI.TemperatureDifference dSH_reg = 2.0 "湿压缩惩罚的平滑过渡区间宽度 (K)" annotation(Dialog(group="安全与惩罚矩阵"));
    parameter Real f_sh_min(min=0.01, max=1.0) = 0.1 "深度湿压缩时的极限效率惩罚因子" annotation(Dialog(group="安全与惩罚矩阵"));

    parameter Real PR_unload = 1.05 "触发低压比完全卸载的临界压比" annotation(Dialog(group="安全与惩罚矩阵"));
    parameter Real dPR_unload = 0.05 "卸载衰减函数的平滑过渡宽度" annotation(Dialog(group="安全与惩罚矩阵"));

    parameter SI.Pressure dp_safe = 10.0 "查表安全托底压差阈值 (Pa)" annotation(Dialog(group="数值正则化设定"));
    parameter SI.Pressure p_min_reg = 100.0 "防真空除零的吸气保底压力 (Pa)" annotation(Dialog(group="数值正则化设定"));

    parameter SI.Pressure p_su_start = 2e5 annotation(Dialog(tab="初始化"));
    parameter SI.Pressure p_ex_start = 10e5 annotation(Dialog(tab="初始化"));
    parameter SI.Temperature T_su_start = 293.15 annotation(Dialog(tab="初始化"));
    parameter Medium.SpecificEnthalpy h_su_start = Medium.specificEnthalpy_pT(p_su_start, T_su_start) annotation(Dialog(tab="初始化"));
    parameter Medium.SpecificEnthalpy h_ex_start = Medium.specificEnthalpy_pT(p_ex_start, T_su_start + 40) annotation(Dialog(tab="初始化"));

    // =======================================================================
    // 5. VARIABLES
    // =======================================================================
    Medium.ThermodynamicState vaporIn "吸气口真实流体状态";
    Medium.ThermodynamicState vaporOut_s "排气口等熵理想流体状态";

    Real N_active "正则化后有效转速 (Hz)";
    Real PR "实际压比";
    Real PR_active "正则化托底压比";
    SI.Pressure p_b_safe "查表安全排气压力";

    Real f_load "低压比卸载平滑因子";
    Real f_sh "湿压缩惩罚因子";

    Real epsilon_v_raw "原始动态容积效率";
    Real epsilon_v_active "惩罚后的有效容积效率";

    SI.Torque tau_fluid "流体对转子施加的等效阻力矩";
    SI.VolumeFlowRate V_dot_su "实际吸气体积流量";

    Medium.Density rho_a(start=Medium.density_pT(p_su_start,T_su_start)) "吸气密度";
    Medium.SpecificEntropy s_a "吸气比熵";
    Medium.SpecificEnthalpy h_ex_s "等熵压缩理论排气比焓";

    SI.Temperature T_su "真实吸气温度";
    SI.Temperature T_sat_su "吸气压力下的饱和温度";
    SI.TemperatureDifference superheat "吸气过热度";

  equation
    // =======================================================================
    // A. 机械动力学约束 (原生微分方程)
    // =======================================================================
    N_active = regStep(N_rot, N_rot, 0.0, 1e-2);

    J_rotor * der(2 * Modelica.Constants.pi * N_rot) = flange_shaft.tau + tau_fluid;

    W_dot_mech = -tau_fluid * (2 * Modelica.Constants.pi * N_rot);
    W_dot_mech = W_dot_fluid;

    // =======================================================================
    // B. 系统级真实压力场与全参数化卸载保护
    // =======================================================================
    PR = p_b / max(p_a, p_min_reg);
    PR_active = regStep(PR - 1.0, PR, 1.0, 1e-2);
    p_b_safe = p_a + regStep(p_b - p_a, p_b - p_a, dp_safe, dp_safe / 2);
    f_load = regStep(PR - PR_unload, 1.0, 0.0, dPR_unload);

    // =======================================================================
    // C. 热力学解算与【湿压缩机理修正】
    // =======================================================================
    vaporIn = Medium.setState_phX(p_a, h_a, inStream(port_a.Xi_outflow));
    rho_a = Medium.density(vaporIn);
    s_a = Medium.specificEntropy(vaporIn);

    T_su = Medium.temperature(vaporIn);
    T_sat_su = Medium.saturationTemperature(p_a);
    superheat = T_su - T_sat_su;

    f_sh = regStep(superheat - SH_min, 1.0, f_sh_min, dSH_reg);

    vaporOut_s = Medium.setState_psX(p_b_safe, s_a, inStream(port_a.Xi_outflow));
    h_ex_s = Medium.specificEnthalpy(vaporOut_s);

    epsilon_v_raw = (epsilon_v_nom - clearance_ratio * ((PR_active)^(1/n_poly) - 1)) * f_sh;
    epsilon_v_active = regStep(epsilon_v_raw, epsilon_v_raw, 0.0, 1e-2);

    // 【神级修复】：彻底抛弃除法放大效应！
    // 正常工况下：f_sh = 1.0，等价于经典的 (h_ex_s - h_a) / epsilon_s_nom
    // 湿压缩工况下：f_sh -> 0.1，机器丧失有效压缩能力，焓升被强制降额萎缩，避免非物理狂飙。
    h_b = h_a + ((h_ex_s - h_a) / epsilon_s_nom) * f_sh * f_load;

    // =======================================================================
    // D. 流体质量与能量闭环
    // =======================================================================
    V_dot_su = epsilon_v_active * V_s * N_active;
    m_flow = V_dot_su * rho_a * f_load;
    W_dot_fluid = m_flow * (h_b - h_a);

    annotation (
      Icon(coordinateSystem(preserveAspectRatio=true, extent={{-100,-100},{100,100}}), graphics={
        Text(extent={{-40,0},{40,-20}}, textColor={0,0,127}, textString="Robust")}),
      Documentation(info="<html>
<p><b>成品容积式压缩机 (MSL 原生动力学 / 湿压缩机理修正版)</b></p>
<p>
<b>湿压缩排气焓修正：</b><br>
彻底修正了经典等熵公式在极低效率下引发的非物理焓升爆发现象。当过热度跌破安全阈值时，惩罚因子 <code>f_sh</code> 将直接削弱系统的实际等熵焓升。这完美还原了液击工况下，压缩机气缸丧失建压能力的真实物理过程，实现了系统能量的绝对安全降额。
</p>
</html>"));
  end RobustCompressor;