partial model PartialLumpedVolume
  "集总容积基类：包含核心质量与能量守恒微积分方程 (Lumped volume with mass and energy balance)"
  import Modelica.Fluid.Types;
  import Modelica.Fluid.Types.Dynamics;
  import Modelica.Media.Interfaces.Choices.IndependentVariables;
  import SI = Modelica.SIunits;

  // 全局系统环境指针（用于获取默认环境压力、初始化状态等）
  outer Modelica.Fluid.System system "System properties";

  // 核心热力学状态机（可热插拔替换的介质模型，例如 CoolProp 有机工质库）
  replaceable package Medium =
    Modelica.Media.Interfaces.PartialMedium "组件内部填充的流体介质" 
      annotation (choicesAllMatching = true);

  // =======================================================================
  // 顶层外部输入 (Inputs provided to the volume model)
  // =======================================================================
  input SI.Volume fluidVolume "当前流体实际占据的容积 (Volume)";

  // =======================================================================
  // 物理微积分方程的动态选项 (Assumptions)
  // =======================================================================
  parameter Types.Dynamics energyDynamics=system.energyDynamics
  "能量守恒方程选项 (默认跟随系统全局设置)" 
    annotation(Evaluate=true, Dialog(tab = "Assumptions", group="Dynamics"));

  parameter Types.Dynamics massDynamics=system.massDynamics
  "质量守恒方程选项 (默认跟随系统全局设置)" 
    annotation(Evaluate=true, Dialog(tab = "Assumptions", group="Dynamics"));

  final parameter Types.Dynamics substanceDynamics=massDynamics
  "组分守恒方程选项 (强制与质量守恒绑定)" 
    annotation(Evaluate=true, Dialog(tab = "Assumptions", group="Dynamics"));

  final parameter Types.Dynamics traceDynamics=massDynamics
  "痕量物质守恒方程选项 (强制与质量守恒绑定)" 
    annotation(Evaluate=true, Dialog(tab = "Assumptions", group="Dynamics"));

  // =======================================================================
  // 仿真初值化配置 (Initialization) 
  // =======================================================================
  parameter Medium.AbsolutePressure p_start = system.p_start
  "压力的初始猜测值/固定值" 
    annotation(Dialog(tab = "Initialization"));

  parameter Boolean use_T_start = true
  "= true 时，使用 T_start 初始化；否则使用 h_start 初始化比焓" 
    annotation(Dialog(tab = "Initialization"), Evaluate=true);

  parameter Medium.Temperature T_start=
    if use_T_start then system.T_start else Medium.temperature_phX(p_start,h_start,X_start)
  "温度的初始猜测值/固定值" 
    annotation(Dialog(tab = "Initialization", enable = use_T_start));

  parameter Medium.SpecificEnthalpy h_start=
    if use_T_start then Medium.specificEnthalpy_pTX(p_start, T_start, X_start) else Medium.h_default
  "比焓的初始猜测值/固定值" 
    annotation(Dialog(tab = "Initialization", enable = not use_T_start));

  parameter Medium.MassFraction X_start[Medium.nX] = Medium.X_default
  "质量分数的初始值 m_i/m" 
    annotation (Dialog(tab="Initialization", enable=Medium.nXi > 0));

  parameter Medium.ExtraProperty C_start[Medium.nC](
       quantity=Medium.extraPropertiesNames) = Medium.C_default
  "痕量物质的初始值" 
    annotation (Dialog(tab="Initialization", enable=Medium.nC > 0));

  // =======================================================================
  // 热力学基础属性包与储能状态量实例化
  // =======================================================================
  Medium.BaseProperties medium(
    preferredMediumStates = (if energyDynamics == Dynamics.SteadyState and 
                                massDynamics   == Dynamics.SteadyState then false else true),
    p(start=p_start),
    h(start=h_start),
    T(start=T_start),
    Xi(start=X_start[1:Medium.nXi]));

  SI.Energy U "容积内流体的总内能 (Internal energy of fluid)";
  SI.Mass m "容积内流体的总质量 (Mass of fluid)";
  SI.Mass[Medium.nXi] mXi "各独立组分的总质量";
  SI.Mass[Medium.nC] mC "痕量物质的总质量";
  Medium.ExtraProperty C[Medium.nC] "痕量物质混合物浓度";

  // =======================================================================
  // 边界流变量 (必须由继承该类的上层设备来定义和赋值)
  // =======================================================================
  SI.MassFlowRate mb_flow "跨越系统边界的总质量流率 (Mass flows across boundaries)";
  SI.MassFlowRate[Medium.nXi] mbXi_flow
  "跨越边界的组分质量流率";
  Medium.ExtraPropertyFlowRate[Medium.nC] mbC_flow
  "跨越边界的痕量物质质量流率";

  SI.EnthalpyFlowRate Hb_flow
  "跨越边界的总焓流率（随质量流动带入的能量）或内部能量源/汇";
  SI.HeatFlowRate Qb_flow
  "跨越边界的热流率（纯传热）或内部热源";
  SI.Power Wb_flow "跨越边界的机械功（如体积膨胀功 p*dV 或 搅拌轴功）";

protected
  parameter Boolean initialize_p = not Medium.singleState
  "= true 时为压力设置初始微积分方程";

  Real[Medium.nC] mC_scaled(min=fill(Modelica.Constants.eps, Medium.nC))
  "经过数值缩放的痕量物质质量";

equation
  assert(not (energyDynamics<>Dynamics.SteadyState and massDynamics==Dynamics.SteadyState) or Medium.singleState,
         "Bad combination of dynamics options and Medium not conserving mass if fluidVolume is fixed.");

  // =======================================================================
  // 宏观储能量与微观物性的绑定
  // =======================================================================
  m = fluidVolume*medium.d;
  mXi = m*medium.Xi;
  U = m*medium.u;
  mC = m*C;

  // =======================================================================
  // 能量与质量的常微分方程 (ODE)
  // =======================================================================
  if energyDynamics == Dynamics.SteadyState then
    0 = Hb_flow + Qb_flow + Wb_flow;
  else
    der(U) = Hb_flow + Qb_flow + Wb_flow;
  end if;

  if massDynamics == Dynamics.SteadyState then
    0 = mb_flow;
  else
    der(m) = mb_flow;
  end if;

  if substanceDynamics == Dynamics.SteadyState then
    zeros(Medium.nXi) = mbXi_flow;
  else
    der(mXi) = mbXi_flow;
  end if;

  if traceDynamics == Dynamics.SteadyState then
    zeros(Medium.nC)  = mbC_flow;
  else
    der(mC_scaled) = mbC_flow./Medium.C_nominal;
  end if;
    mC = mC_scaled.*Medium.C_nominal;

initial equation
  // =======================================================================
  // 高阶初值求解器逻辑 (Initialization of balances)
  // =======================================================================
  if energyDynamics == Dynamics.FixedInitial then
    if Medium.ThermoStates == IndependentVariables.ph or 
       Medium.ThermoStates == IndependentVariables.phX then
       medium.h = h_start;
    else
       medium.T = T_start;
    end if;
  elseif energyDynamics == Dynamics.SteadyStateInitial then
    if Medium.ThermoStates == IndependentVariables.ph or 
       Medium.ThermoStates == IndependentVariables.phX then
       der(medium.h) = 0;
    else
       der(medium.T) = 0;
    end if;
  end if;

  if massDynamics == Dynamics.FixedInitial then
    if initialize_p then
      medium.p = p_start;
    end if;
  elseif massDynamics == Dynamics.SteadyStateInitial then
    if initialize_p then
      der(medium.p) = 0;
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
为理想混合的流体容积（具备质量和能量储能能力）提供接口和物理基础模型基类。<br>
以下边界流量和能量源项是能量守恒方程的关键组成部分，必须在继承本类的上层设备模型中被赋予具体的计算公式：
</p>
<ul>
<li><code><strong>Qb_flow</strong></code>：跨越控制体边界的对流或相变潜热热流率，</li>
<li><code><strong>Wb_flow</strong></code>：系统做功项。比如如果这是一个活塞气缸（体积不恒定），则为 p*der(fluidVolume)。</li>
</ul>
<p>
组件的总容积 <code><strong>fluidVolume</strong></code> 作为一个输入项（input），必须在子类中被明确设定大小（例如等于储液罐体积 V），模型才能闭合。
</p>
<p>
此外，如果有流体进出该容积边界，子类还必须为以下源项写出具体的汇流方程：
</p>
<ul>
<li><code><strong>Hb_flow</strong></code>：流入/流出的绝对焓流，</li>
<li><code><strong>mb_flow</strong></code>：流入/流出的质量流，</li>
<li><code><strong>mbXi_flow</strong></code>：流入/流出的组分流，</li>
<li><code><strong>mbC_flow</strong></code>：流入/流出的痕量物质流。</li>
</ul>
</html>"));
end PartialLumpedVolume;