model TwoPhaseFriction "HP-ORC专属：两相流压降模型 (带两相摩擦乘子)"
  import SI = Modelica.SIunits;
  import Modelica.Constants.pi;

  // 1. 继承标准库交错网格流动接口，强制挂载两相流物性模板
  extends Modelica.Fluid.Pipes.BaseClasses.FlowModels.PartialStaggeredFlowModel(
    redeclare replaceable package Medium = Modelica.Media.Water.StandardWater 
      constrainedby Modelica.Media.Interfaces.PartialTwoPhaseMedium
  );

  // 2. 内部计算变量声明 (长度均为 n-1，即节点交界面数量)
  SI.Area A_mean[n-1] "交界面平均截面积";
  SI.Diameter D_mean[n-1] "交界面平均水力直径";

  Real Re[n-1] "交界面局部雷诺数";
  Real lambda[n-1] "单相达西摩擦系数";

  Medium.SaturationProperties sat[n-1] "交界面饱和物性数据包";
  SI.Pressure p_mean[n-1] "交界面平均压力";
  SI.SpecificEnthalpy h_mean[n-1] "交界面平均比焓";
  SI.SpecificEnthalpy h_liq[n-1] "局部饱和液态比焓";
  SI.SpecificEnthalpy h_vap[n-1] "局部饱和气态比焓";

  Real x_mean[n-1] "交界面平均干度";
  Real phi_LO_2[n-1] "两相摩擦乘子 (Two-Phase Multiplier)";
  SI.Pressure dp_friction[n-1] "纯摩擦压降";

equation
  // =========================================================================
  // 核心压降方程组：遍历每个交错网格交界面
  // =========================================================================
  for i in 1:n-1 loop

    // a. 严谨的几何平均化处理 (保证空间守恒)
    A_mean[i] = 0.5 * (crossAreas[i] + crossAreas[i+1]);
    D_mean[i] = 0.5 * (dimensions[i] + dimensions[i+1]);

    // b. 计算交界面当地雷诺数
    Re[i] = (4 * abs(m_flows[i])) / (pi * D_mean[i] * mus_act[i] + 1e-6);

    // c. 计算单相摩擦系数 (Blasius 公式)
    if Re[i] < 2000 then
       lambda[i] = 64 / max(Re[i], 1e-4);
    else
       lambda[i] = 0.3164 * (Re[i] + 1e-4)^(-0.25);
    end if;

    // d. 提取交界面热力学状态并生成饱和数据包
    p_mean[i] = (Medium.pressure(states[i]) + Medium.pressure(states[i+1])) / 2;
    h_mean[i] = (Medium.specificEnthalpy(states[i]) + Medium.specificEnthalpy(states[i+1])) / 2;

    sat[i] = Medium.setSat_p(p_mean[i]);
    h_liq[i] = Medium.bubbleEnthalpy(sat[i]);
    h_vap[i] = Medium.dewEnthalpy(sat[i]);

    // e. 计算平均干度与两相摩擦乘子
    // 【你的学术工作量】：后续可将此乘子替换为 Friedel 或 MSH 等经典关联式
    x_mean[i] = (h_mean[i] - h_liq[i]) / max((h_vap[i] - h_liq[i]), 1e-5);

    if x_mean[i] <= 0.05 then
       phi_LO_2[i] = 1.0; // 纯液相无额外惩罚
    elseif x_mean[i] >= 0.95 then
       phi_LO_2[i] = 1.0; // 纯气相无额外惩罚
    else
       phi_LO_2[i] = 2.5 + 5.0 * x_mean[i]; // 两相区压降惩罚 (临时拟合，需替换)
    end if;

    // f. 计算包含两相惩罚的摩擦压降
    dp_friction[i] = lambda[i] * (pathLengths[i] / D_mean[i])
                     * (1 / (2 * rhos_act[i] * A_mean[i]^2))
                     * m_flows[i] * abs(m_flows[i])
                     * phi_LO_2[i];

    // g. 闭合方程：向底层动量方程 (PartialDistributedFlow) 提供阻力推力 Fs_fg
    Fs_fg[i] = dp_friction[i] * A_mean[i] * nParallel;

  end for;
end TwoPhaseFriction;