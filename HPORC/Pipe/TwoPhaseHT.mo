model TwoPhaseHT "HP-ORC专属：两相流传热模型 (支持干度动态追踪)"
  import SI = Modelica.SIunits;

  // 1. 继承标准库官方接口，并强制挂载两相流物性模板
  extends Modelica.Fluid.Pipes.BaseClasses.HeatTransfer.PartialFlowHeatTransfer(
    redeclare replaceable package Medium = Modelica.Media.Water.StandardWater 
      constrainedby Modelica.Media.Interfaces.PartialTwoPhaseMedium
  );

  // 2. 内部计算变量声明
  SI.CoefficientOfHeatTransfer alpha[n] "局部对流传热系数";
  Real x_quality[n] "局部蒸汽干度";

  Medium.SaturationProperties sat[n] "当前节点饱和物性数据包";
  SI.SpecificEnthalpy h_liq[n] "饱和液态比焓";
  SI.SpecificEnthalpy h_vap[n] "饱和气态比焓";

equation
  // =========================================================================
  // 核心传热方程组：遍历每个有限体积热力学节点
  // =========================================================================
  for i in 1:n loop

    // a. 提取热力学状态，生成饱和数据包以获取饱和比焓
    sat[i] = Medium.setSat_p(Medium.pressure(states[i]));
    h_liq[i] = Medium.bubbleEnthalpy(sat[i]);
    h_vap[i] = Medium.dewEnthalpy(sat[i]);

    // b. 根据实际比焓计算干度 (利用 max 防止超临界状态下分母为零)
    x_quality[i] = (Medium.specificEnthalpy(states[i]) - h_liq[i]) / max((h_vap[i] - h_liq[i]), 1e-5);

    // c. 动态相态识别与传热系数 alpha 计算
    // 【你的学术工作量】：后续可将这里的常数替换为 Shah 或 Kandlikar 沸腾/冷凝关联式
    if x_quality[i] <= 0.05 then
      alpha[i] = 1500.0; // 过冷液相区
    elseif x_quality[i] >= 0.95 then
      alpha[i] = 300.0;  // 过热气相区
    else
      alpha[i] = 5000.0; // 两相相变区 (极高的换热系数)
    end if;

    // d. 闭合方程：向底层 DynamicPipe 提供热流率 Q_flows
    Q_flows[i] = alpha[i] * surfaceAreas[i] * (heatPorts[i].T - Ts[i]);

  end for;
end TwoPhaseHT;