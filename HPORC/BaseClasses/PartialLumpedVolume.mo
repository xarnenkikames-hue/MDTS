partial model PartialLumpedVolume "具有质量与能量守恒平衡的集总容积模型 (单体水箱基类)"
  import Modelica.Fluid.Types;
  import Modelica.Fluid.Types.Dynamics;
  import Modelica.Media.Interfaces.Choices.IndependentVariables;
  import SI = Modelica.SIunits;

  // 接入我们在上一步讲过的“全局宇宙常数”
  outer Modelica.Fluid.System system "全局系统属性";

  replaceable package Medium =
    Modelica.Media.Interfaces.PartialMedium "组件内部的工质模型" 
      annotation (choicesAllMatching = true);

  // =======================================================================
  // 1. 提供给容积模型的输入物理量
  // =======================================================================
  input SI.Volume fluidVolume "流体容积 (必须由外部实体模型输入具体的体积大小)";

  // =======================================================================
  // 2. 模型动力学假设 (由 system 全局组件控制默认值)
  // =======================================================================
  parameter Types.Dynamics energyDynamics=system.energyDynamics
  "能量平衡方程的求解形式 (动态/稳态)" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学设置"));

  parameter Types.Dynamics massDynamics=system.massDynamics
  "质量平衡方程的求解形式" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学设置"));

  final parameter Types.Dynamics substanceDynamics=massDynamics
  "组分平衡方程的求解形式" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学设置"));

  final parameter Types.Dynamics traceDynamics=massDynamics
  "痕量物质平衡方程的求解形式" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学设置"));

  // =======================================================================
  // 3. 极其关键的求解器初始化设定
  // =======================================================================
  parameter Medium.AbsolutePressure p_start = system.p_start
  "压力的初始猜测值" 
    annotation(Dialog(tab = "初始化"));

  parameter Boolean use_T_start = true
  "= true 时使用 T_start 初始化；= false 时使用 h_start 初始化 (两相区相变必备)" 
    annotation(Dialog(tab = "初始化"), Evaluate=true);

  parameter Medium.Temperature T_start=
    if use_T_start then system.T_start else Medium.temperature_phX(p_start,h_start,X_start)
  "温度的初始猜测值" 
    annotation(Dialog(tab = "初始化", enable = use_T_start));

  parameter Medium.SpecificEnthalpy h_start=
    if use_T_start then Medium.specificEnthalpy_pTX(p_start, T_start, X_start) else Medium.h_default
  "比焓的初始猜测值" 
    annotation(Dialog(tab = "初始化", enable = not use_T_start));

  parameter Medium.MassFraction X_start[Medium.nX] = Medium.X_default
  "组分质量分数 m_i/m 的初始值" 
    annotation (Dialog(tab="初始化", enable=Medium.nXi > 0));

  parameter Medium.ExtraProperty C_start[Medium.nC](
       quantity=Medium.extraPropertiesNames) = Medium.C_default
  "痕量物质的初始值" 
    annotation (Dialog(tab="初始化", enable=Medium.nC > 0));

  // =======================================================================
  // 4. 实体化流体介质状态
  // =======================================================================
  Medium.BaseProperties medium(
    // 算法优化：如果全是稳态方程，就不需要优先选择介质状态进行求导运算
    preferredMediumStates = (if energyDynamics == Dynamics.SteadyState and 
                                massDynamics   == Dynamics.SteadyState then false else true),
    p(start=p_start),
    h(start=h_start),
    T(start=T_start),
    Xi(start=X_start[1:Medium.nXi]));

  // =======================================================================
  // 5. 核心状态宏观物理量 (控制体积内的总储量)
  // =======================================================================
  SI.Energy U "容积内流体的总内能";
  SI.Mass m "容积内流体的总质量";
  SI.Mass[Medium.nXi] mXi "容积内独立组分的总质量";
  SI.Mass[Medium.nC] mC "容积内痕量物质的总质量";
  Medium.ExtraProperty C[Medium.nC] "痕量物质混合物含量";

  // =======================================================================
  // 6. 跨越边界的源/汇项 (必须由继承该基类的子类具体定义)
  // =======================================================================
  SI.MassFlowRate mb_flow "跨越边界的净质量流量";
  SI.MassFlowRate[Medium.nXi] mbXi_flow
  "跨越边界的独立组分净质量流量";
  Medium.ExtraPropertyFlowRate[Medium.nC] mbC_flow
  "跨越边界的痕量物质净流量";
  SI.EnthalpyFlowRate Hb_flow
  "跨越边界的伴随对流焓流，或能量源/汇";
  SI.HeatFlowRate Qb_flow
  "跨越边界的热流量，或能量源/汇 (如外部加热)";
  SI.Power Wb_flow "跨越边界的机械功源项 (如膨胀功或搅拌功)";

protected
  parameter Boolean initialize_p = not Medium.singleState
  "= true 时为压力建立初始方程 (非单状态介质需要)";

  Real[Medium.nC] mC_scaled(min=fill(Modelica.Constants.eps, Medium.nC))
  "缩放后的痕量物质质量 (提升数值稳定性)";

equation
  assert(not (energyDynamics<>Dynamics.SteadyState and massDynamics==Dynamics.SteadyState) or Medium.singleState,
         "物理错误：在体积固定时，不可压缩流体的能量与质量动态选项组合非法！");

  // =======================================================================
  // 7. 总量关系代数方程
  // =======================================================================
  m = fluidVolume*medium.d; // 总质量 = 容积 * 密度
  mXi = m*medium.Xi;
  U = m*medium.u;           // 总内能 = 总质量 * 比内能
  mC = m*C;

  // =======================================================================
  // 8. 核心偏微分方程：能量与质量守恒
  // =======================================================================

  // 能量守恒: dU/dt = Hb + Qb + Wb
  if energyDynamics == Dynamics.SteadyState then
    0 = Hb_flow + Qb_flow + Wb_flow;
  else
    der(U) = Hb_flow + Qb_flow + Wb_flow;
  end if;

  // 质量守恒: dm/dt = mb_flow
  if massDynamics == Dynamics.SteadyState then
    0 = mb_flow;
  else
    der(m) = mb_flow;
  end if;

  // 组分质量守恒
  if substanceDynamics == Dynamics.SteadyState then
    zeros(Medium.nXi) = mbXi_flow;
  else
    der(mXi) = mbXi_flow;
  end if;

  // 痕量物质守恒 (带数值缩放抗发散)
  if traceDynamics == Dynamics.SteadyState then
    zeros(Medium.nC)  = mbC_flow;
  else
    der(mC_scaled) = mbC_flow./Medium.C_nominal;
  end if;
    mC = mC_scaled.*Medium.C_nominal;

initial equation
  // =======================================================================
  // 9. 求解器同伦与初始化策略 (极其影响发散与否)
  // =======================================================================
  if energyDynamics == Dynamics.FixedInitial then
    // 强制赋初值 (FixedInitial)
    if Medium.ThermoStates == IndependentVariables.ph or 
       Medium.ThermoStates == IndependentVariables.phX then
       medium.h = h_start; // 对制冷剂极其友好，直接锁定比焓
    else
       medium.T = T_start;
    end if;
  elseif energyDynamics == Dynamics.SteadyStateInitial then
    // 强制开局导数为零 (SteadyStateInitial)
    if Medium.ThermoStates == IndependentVariables.ph or 
       Medium.ThermoStates == IndependentVariables.phX then
       der(medium.h) = 0; // 强制比焓变化率为 0
    else
       der(medium.T) = 0; // 强制温度变化率为 0
    end if;
  end if;

  if massDynamics == Dynamics.FixedInitial then
    if initialize_p then
      medium.p = p_start;
    end if;
  elseif massDynamics == Dynamics.SteadyStateInitial then
    if initialize_p then
      der(medium.p) = 0; // 强制开局压力变化率 (dp/dt) 为 0，完美消灭水锤冲击！
    end if;
  end if;

  if substanceDynamics == Dynamics.FixedInitial then
    medium.Xi = X_start[1:Medium.nXi];
  elseif substanceDynamics == Dynamics.SteadyStateInitial then
    der(medium.Xi) = zeros(Medium.nXi);
  end if;

  if traceDynamics == Dynamics.FixedInitial then
    mC_scaled = m*C_start[1:Medium.nC]./Medium.C_nominal;
  elseif traceDynamics == Dynamics.SteadyStateInitial then
    der(mC_scaled) = zeros(Medium.nC);
  end if;

  annotation (
    Documentation(info="<html>
<p>
本接口和基类用于建立一个具有质量和能量储能能力的<strong>理想混合集总流体容积</strong> (Lumped Volume)。
在继承此基类的模型中，必须在能量平衡方程中补充以下边界通量和源项：
</p>
<ul>
<li><code><strong>Qb_flow</strong></code>，例如跨越容器壁面的对流或潜热热流量，以及</li>
<li><code><strong>Wb_flow</strong></code>，做功项，例如当体积不恒定时的膨胀功 <code>p*der(fluidVolume)</code>。</li>
</ul>
<p>
组件容积 <code><strong>fluidVolume</strong></code> 是一个输入变量，必须在继承的子类中进行几何设定以闭合模型。
</p>
<p>
此外，子类还必须为跨越容积边界的流体流动定义以下对流源项：
</p>
<ul>
<li><code><strong>Hb_flow</strong></code>，伴随流体流入的对流焓流，</li>
<li><code><strong>mb_flow</strong></code>，净流入质量流量，</li>
<li><code><strong>mbXi_flow</strong></code>，独立组分净质量流量，以及</li>
<li><code><strong>mbC_flow</strong></code>，痕量物质质量流量。</li>
</ul>
</html>"));
end PartialLumpedVolume;