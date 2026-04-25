partial model PartialDistributedVolume
    "分布式容积模型基类 (实现有限体积法的一维空间离散)"
    import Modelica.Fluid.Types;
    import Modelica.Fluid.Types.Dynamics;
    import Modelica.Media.Interfaces.Choices.IndependentVariables;
    import SI = Modelica.SIunits;

  outer System system "全局系统属性";

  replaceable package Medium =
    Modelica.Media.Interfaces.PartialMedium "组件内部的流体工质" 
      annotation (choicesAllMatching = true);

  // =======================================================================
  // 1. 离散化网格参数 (Discretization)
  // =======================================================================
  parameter Integer n=2 "离散流体体积的网格数量 (控制体积数)";

  // =======================================================================
  // 2. 提供给容积模型的输入量 (Inputs)
  // =======================================================================
  input SI.Volume[n] fluidVolumes
      "各离散网格的几何容积 (必须在继承此基类的子类中具体定义计算公式)";

  // =======================================================================
  // 3. 模型假设与动力学形式 (Assumptions)
  // =======================================================================
  parameter Types.Dynamics energyDynamics=system.energyDynamics
      "能量平衡方程的求解形式 (动态偏微分或稳态代数)" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学设置"));
  parameter Types.Dynamics massDynamics=system.massDynamics
      "质量平衡方程的求解形式" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学设置"));
  final parameter Types.Dynamics substanceDynamics=massDynamics
      "独立组分质量平衡方程的求解形式 (与总质量平衡保持一致)" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学设置"));
  final parameter Types.Dynamics traceDynamics=massDynamics
      "痕量物质平衡方程的求解形式" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学设置"));

  // =======================================================================
  // 4. 初始化设置 (Initialization)
  // =======================================================================
  parameter Medium.AbsolutePressure p_a_start=system.p_start
      "端口 a 处的初始压力猜想值" 
    annotation(Dialog(tab = "初始化"));
  parameter Medium.AbsolutePressure p_b_start=p_a_start
      "端口 b 处的初始压力猜想值" 
    annotation(Dialog(tab = "初始化"));
  final parameter Medium.AbsolutePressure[n] ps_start=if n > 1 then linspace(
        p_a_start, p_b_start, n) else {(p_a_start + p_b_start)/2}
      "各网格段初始压力的线性插值分布";

  parameter Boolean use_T_start=true "= true 时使用初始温度 T_start，否则使用初始比焓 h_start (用于处理相变工况)" 
     annotation(Evaluate=true, Dialog(tab = "初始化"));

  parameter Medium.Temperature T_start=if use_T_start then system.T_start else 
              Medium.temperature_phX(
        (p_a_start + p_b_start)/2,
        h_start,
        X_start) "初始温度猜想值" 
    annotation(Evaluate=true, Dialog(tab = "初始化", enable = use_T_start));
  parameter Medium.SpecificEnthalpy h_start=if use_T_start then 
        Medium.specificEnthalpy_pTX(
        (p_a_start + p_b_start)/2,
        T_start,
        X_start) else Medium.h_default "初始比焓猜想值" 
    annotation(Evaluate=true, Dialog(tab = "初始化", enable = not use_T_start));
  parameter Medium.MassFraction X_start[Medium.nX] = Medium.X_default
      "初始质量分数 m_i/m" 
    annotation (Dialog(tab="初始化", enable=Medium.nXi > 0));
  parameter Medium.ExtraProperty C_start[Medium.nC](
       quantity=Medium.extraPropertiesNames) = Medium.C_default
      "痕量物质的初始值" 
    annotation (Dialog(tab="初始化", enable=Medium.nC > 0));

  // =======================================================================
  // 5. 控制体积内部守恒总量声明 (Total quantities)
  // =======================================================================
  SI.Energy[n] Us "控制体积内流体的总内能";
  SI.Mass[n] ms "控制体积内流体的总质量";
  SI.Mass[n,Medium.nXi] mXis "控制体积内独立组分的总质量";
  SI.Mass[n,Medium.nC] mCs "控制体积内痕量物质的总质量";
  SI.Mass[n,Medium.nC] mCs_scaled "缩放后的痕量物质总质量 (提升求解器稳定性)";
  Medium.ExtraProperty Cs[n, Medium.nC] "痕量物质混合物含量";

  // 【实体化工质状态】
  Medium.BaseProperties[n] mediums(
    each preferredMediumStates=true,
    p(start=ps_start),
    each h(start=h_start),
    each T(start=T_start),
    each Xi(start=X_start[1:Medium.nXi]));

  // =======================================================================
  // 6. 控制体积边界通量源项 (Source terms)
  // 注意：这些源项必须由继承本类的子模型在外部具体定义 (如果不使用则设为 0)
  // =======================================================================
  Medium.MassFlowRate[n] mb_flows "净流入控制体积的质量通量 (源或汇)";
  Medium.MassFlowRate[n,Medium.nXi] mbXi_flows
      "净流入控制体积的组分质量通量 (源或汇)";
  Medium.ExtraPropertyFlowRate[n,Medium.nC] mbC_flows
      "净流入控制体积的痕量物质质量通量 (源或汇)";
  SI.EnthalpyFlowRate[n] Hb_flows "伴随质量流入的焓流率 (对流传热项)";
  SI.HeatFlowRate[n] Qb_flows "跨越系统边界的热流率 (如管壁导热传入的热量)";
  SI.Power[n] Wb_flows "对流体做的机械功通量 (如 p*dV 膨胀功或摩擦耗散生热)";

  protected
  parameter Boolean initialize_p = not Medium.singleState
      "= true 时，为压力建立初始方程 (对于不可压缩单状态流体跳过此步骤)";

equation
  // 安全检查：如果流体不可压缩且体积固定，那么能量动态与质量动态必须同时是稳态，否则会产生超定方程组
  assert(not (energyDynamics<>Dynamics.SteadyState and massDynamics==Dynamics.SteadyState) or Medium.singleState,
         "物理错误：在控制体积固定的前提下，不可压缩流体的能量与质量动力学选项组合非法！");

  // =======================================================================
  // 7. 几何量与广延量的代数关系计算
  // =======================================================================
  for i in 1:n loop
    ms[i] =fluidVolumes[i]*mediums[i].d;      // m = V * rho
    mXis[i, :] = ms[i]*mediums[i].Xi;
    mCs[i, :]  = ms[i]*Cs[i, :];
    Us[i] = ms[i]*mediums[i].u;               // U = m * u
  end for;

  // =======================================================================
  // 8. 【核心偏微分方程】：能量与质量守恒律
  // =======================================================================
  // 8.1 能量守恒 (dU/dt = Q_in + W_in + H_in)
  if energyDynamics == Dynamics.SteadyState then
    for i in 1:n loop
      0 = Hb_flows[i] + Wb_flows[i] + Qb_flows[i];
    end for;
  else
    for i in 1:n loop
      der(Us[i]) = Hb_flows[i] + Wb_flows[i] + Qb_flows[i];
    end for;
  end if;

  // 8.2 总质量守恒 (dm/dt = m_flow_in)
  if massDynamics == Dynamics.SteadyState then
    for i in 1:n loop
      0 = mb_flows[i];
    end for;
  else
    for i in 1:n loop
      der(ms[i]) = mb_flows[i];
    end for;
  end if;

  // 8.3 独立组分质量守恒
  if substanceDynamics == Dynamics.SteadyState then
    for i in 1:n loop
      zeros(Medium.nXi) = mbXi_flows[i, :];
    end for;
  else
    for i in 1:n loop
      der(mXis[i, :]) = mbXi_flows[i, :];
    end for;
  end if;

  // 8.4 痕量物质守恒 (采用归一化缩放处理以防止舍入误差)
  if traceDynamics == Dynamics.SteadyState then
    for i in 1:n loop
      zeros(Medium.nC)  = mbC_flows[i, :];
    end for;
  else
    for i in 1:n loop
      der(mCs_scaled[i, :])  = mbC_flows[i, :]./Medium.C_nominal;
      mCs[i, :] = mCs_scaled[i, :].*Medium.C_nominal;
    end for;
  end if;

initial equation
  // =======================================================================
  // 9. 求解器初始化策略 (Initialization)
  // 用于消除 t=0 时刻的物理量跳变冲击
  // =======================================================================

  // 能量初始条件
  if energyDynamics == Dynamics.FixedInitial then
    // 强制赋予初始值
    if Medium.ThermoStates == IndependentVariables.ph or 
       Medium.ThermoStates == IndependentVariables.phX then
       mediums.h = fill(h_start, n);
    else
       mediums.T = fill(T_start, n);
    end if;

  elseif energyDynamics == Dynamics.SteadyStateInitial then
    // 强制初始导数为 0 (开局稳态)
    if Medium.ThermoStates == IndependentVariables.ph or 
       Medium.ThermoStates == IndependentVariables.phX then
       der(mediums.h) = zeros(n);
    else
       der(mediums.T) = zeros(n);
    end if;
  end if;

  // 质量初始条件
  if massDynamics == Dynamics.FixedInitial then
    if initialize_p then
      mediums.p = ps_start;
    end if;
  elseif massDynamics == Dynamics.SteadyStateInitial then
    if initialize_p then
      der(mediums.p) = zeros(n);
    end if;
  end if;

  // 组分初始条件
  if substanceDynamics == Dynamics.FixedInitial then
    mediums.Xi = fill(X_start[1:Medium.nXi], n);
  elseif substanceDynamics == Dynamics.SteadyStateInitial then
    for i in 1:n loop
      der(mediums[i].Xi) = zeros(Medium.nXi);
    end for;
  end if;

  // 痕量物质初始条件
  if traceDynamics == Dynamics.FixedInitial then
    Cs = fill(C_start[1:Medium.nC], n);
  elseif traceDynamics == Dynamics.SteadyStateInitial then
    for i in 1:n loop
      der(mCs[i,:])      = zeros(Medium.nC);
    end for;
  end if;

   annotation (Documentation(info="<html>
<p>
本接口和基类用于建立 <code><strong>n</strong></code> 个具有质量和能量储能能力的理想混合流体容积。<br>
它的核心目标是基于<strong>有限体积法 (Finite Volume Method)</strong> 对流体的一维空间流动进行空间离散化。
继承此基类的子类，必须在能量守恒方程中补全以下边界通量和源项：
</p>
<ul>
<li><code><strong>Qb_flows[n]</strong></code>：热流源项，例如跨越管段边界的热传导。</li>
<li><code><strong>Wb_flows[n]</strong></code>：机械功源项。</li>
</ul>
<p>
组件容积阵列 <code><strong>fluidVolumes[n]</strong></code> 是一个输入变量，必须在子类中进行几何赋值以闭合模型。
</p>
<p>
此外，子类还必须为跨越容积边界的流体流动定义以下对流源项：
</p>
<ul>
<li><code><strong>Hb_flows[n]</strong></code>：伴随对流产生的总焓流。</li>
<li><code><strong>mb_flows[n]</strong></code>：净质量流入量。</li>
<li><code><strong>mbXi_flows[n]</strong></code>：净组分质量流入量。</li>
<li><code><strong>mbC_flows[n]</strong></code>：净痕量物质流入量。</li>
</ul>
</html>"));
end PartialDistributedVolume;