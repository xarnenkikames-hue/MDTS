model BasicHX "简易换热器总成模型 (由两根管道和中间的一层管壁装配而成) [抗沸腾震荡·消除代数环版]"

  import SI = Modelica.SIunits;
  import Modelica.Fluid.Types;
  import Modelica.Fluid.Pipes.BaseClasses;
  import Modelica.Fluid.Pipes;

  outer Modelica.Fluid.System system "全局系统属性";

  // =======================================================================
  // 1. General
  // =======================================================================
  parameter SI.Length length(min=0) "两侧流体的有效换热管长";
  parameter Integer nNodes(min=1) = 2 "空间离散网格数 (有限体积法节点数)";

  // 【核心修复】：必须改回 av_vb！确保换热器的两端是 Volume (容积)，这样才能与泵和阀门(Flow组件)完美对接，消除非线性代数环！
  parameter Types.ModelStructure modelStructure_1=Types.ModelStructure.av_vb
    "决定管程端口处是应用流动模型(Flow)还是容积模型(Volume)" 
    annotation(Evaluate=true, Dialog(tab="常规",group="流体 1"));
  parameter Types.ModelStructure modelStructure_2=Types.ModelStructure.av_vb
    "决定壳程端口处是应用流动模型(Flow)还是容积模型(Volume)" 
    annotation(Evaluate=true, Dialog(tab="常规",group="流体 2"));

  replaceable package Medium_1 = Modelica.Media.Water.StandardWater constrainedby 
    Modelica.Media.Interfaces.PartialMedium "管程流体 1 工质" 
    annotation(choicesAllMatching, Dialog(tab="常规",group="流体 1"));
  replaceable package Medium_2 = Modelica.Media.Water.StandardWater constrainedby 
    Modelica.Media.Interfaces.PartialMedium "壳程流体 2 工质" 
    annotation(choicesAllMatching,Dialog(tab="常规", group="流体 2"));

  parameter SI.Area crossArea_1 "管程流通截面积" annotation(Dialog(tab="常规",group="流体 1"));
  parameter SI.Area crossArea_2 "壳程流通截面积" annotation(Dialog(tab="常规",group="流体 2"));
  parameter SI.Length perimeter_1 "管程流道湿周 (换热周长)" annotation(Dialog(tab="常规",group="流体 1"));
  parameter SI.Length perimeter_2 "壳程流道湿周 (换热周长)" annotation(Dialog(tab="常规",group="流体 2"));

  final parameter Boolean use_HeatTransfer = true;

  // =======================================================================
  // 2. Heat transfer
  // =======================================================================
  replaceable model HeatTransfer_1 = BaseClasses.HeatTransfer.IdealFlowHeatTransfer 
    constrainedby BaseClasses.HeatTransfer.PartialFlowHeatTransfer annotation(choicesAllMatching, Dialog(tab="常规", group="流体 1", enable=use_HeatTransfer));
  replaceable model HeatTransfer_2 = BaseClasses.HeatTransfer.IdealFlowHeatTransfer 
    constrainedby BaseClasses.HeatTransfer.PartialFlowHeatTransfer annotation(choicesAllMatching, Dialog(tab="常规", group="流体 2", enable=use_HeatTransfer));

  parameter SI.Area area_h_1 "管程侧换热面积" annotation(Dialog(tab="常规",group="流体 1"));
  parameter SI.Area area_h_2 "壳程侧换热面积" annotation(Dialog(tab="常规",group="流体 2"));

  // =======================================================================
  // 3. Wall
  // =======================================================================
  parameter SI.Length s_wall(min=0) "管壁厚度" annotation (Dialog(group="管壁属性"));
  parameter SI.ThermalConductivity k_wall "管壁材料导热系数" annotation (Dialog(group="管壁属性"));
  parameter SI.SpecificHeatCapacity c_wall "管壁材料比热容" annotation(Dialog(tab="常规", group="管壁属性"));
  parameter SI.Density rho_wall "管壁材料密度" annotation(Dialog(tab="常规", group="管壁属性"));

  final parameter SI.Area area_h=(area_h_1 + area_h_2)/2;
  final parameter SI.Mass m_wall=rho_wall*area_h*s_wall;

  // =======================================================================
  // 4. Assumptions
  // =======================================================================
  parameter Boolean allowFlowReversal = system.allowFlowReversal annotation(Dialog(tab="假设"), Evaluate=true);
  parameter Types.Dynamics energyDynamics=system.energyDynamics annotation(Evaluate=true, Dialog(tab = "假设", group="动态特性"));
  parameter Types.Dynamics massDynamics=system.massDynamics annotation(Evaluate=true, Dialog(tab = "假设", group="动态特性"));
  parameter Types.Dynamics momentumDynamics=system.momentumDynamics annotation(Evaluate=true, Dialog(tab = "假设", group="动态特性"));

  // =======================================================================
  // 5. Initialization
  // =======================================================================
  parameter SI.Temperature Twall_start=293.15 "管壁初始温度猜想值" annotation(Dialog(tab="初始化", group="管壁"));
  parameter SI.TemperatureDifference dT=0 "初始温差猜想值" annotation (Dialog(tab="初始化", group="管壁"));

  // 【保留此核心良药】：严禁在相变区使用温度作为初始迭代变量！
  parameter Boolean use_T_start=false
    "为 true 时使用初始温度 T_start，为 false 时使用初始比焓 h_start (两相区抗崩溃必备)" 
    annotation(Evaluate=true, Dialog(tab = "初始化"));

  parameter Medium_1.AbsolutePressure p_a_start1=Medium_1.p_default annotation(Dialog(tab = "初始化", group = "流体 1"));
  parameter Medium_1.AbsolutePressure p_b_start1=Medium_1.p_default annotation(Dialog(tab = "初始化", group = "流体 1"));
  parameter Medium_1.Temperature T_start_1=if use_T_start then Medium_1.T_default else Medium_1.temperature_phX((p_a_start1 + p_b_start1)/2, h_start_1, X_start_1) annotation(Evaluate=true, Dialog(tab = "初始化", group = "流体 1", enable = use_T_start));
  parameter Medium_1.SpecificEnthalpy h_start_1=if use_T_start then Medium_1.specificEnthalpy_pTX((p_a_start1 + p_b_start1)/2, T_start_1, X_start_1) else Medium_1.h_default annotation(Evaluate=true, Dialog(tab = "初始化", group = "流体 1", enable = not use_T_start));
  parameter Medium_1.MassFraction X_start_1[Medium_1.nX]=Medium_1.X_default annotation (Dialog(tab="初始化", group = "流体 1", enable=(Medium_1.nXi > 0)));
  parameter Medium_1.MassFlowRate m_flow_start_1 = system.m_flow_start annotation(Evaluate=true, Dialog(tab = "初始化", group = "流体 1"));

  parameter Medium_2.AbsolutePressure p_a_start2=Medium_2.p_default annotation(Dialog(tab = "初始化", group = "流体 2"));
  parameter Medium_2.AbsolutePressure p_b_start2=Medium_2.p_default annotation(Dialog(tab = "初始化", group = "流体 2"));
  parameter Medium_2.Temperature T_start_2=if use_T_start then Medium_2.T_default else Medium_2.temperature_phX((p_a_start2 + p_b_start2)/2, h_start_2, X_start_2) annotation(Evaluate=true, Dialog(tab = "初始化", group = "流体 2", enable = use_T_start));
  parameter Medium_2.SpecificEnthalpy h_start_2=if use_T_start then Medium_2.specificEnthalpy_pTX((p_a_start2 + p_b_start2)/2, T_start_2, X_start_2) else Medium_2.h_default annotation(Evaluate=true, Dialog(tab = "初始化", group = "流体 2", enable = not use_T_start));
  parameter Medium_2.MassFraction X_start_2[Medium_2.nX]=Medium_2.X_default annotation (Dialog(tab="初始化", group = "流体 2", enable=Medium_2.nXi>0));
  parameter Medium_2.MassFlowRate m_flow_start_2 = system.m_flow_start annotation(Evaluate=true, Dialog(tab = "初始化", group = "流体 2"));

  // =======================================================================
  // 6. Components & Equations
  // =======================================================================
  replaceable model FlowModel_1 = BaseClasses.FlowModels.DetailedPipeFlow constrainedby BaseClasses.FlowModels.PartialStaggeredFlowModel annotation(choicesAllMatching, Dialog(tab="常规", group="流体 1"));
  replaceable model FlowModel_2 = BaseClasses.FlowModels.DetailedPipeFlow constrainedby BaseClasses.FlowModels.PartialStaggeredFlowModel annotation(choicesAllMatching, Dialog(tab="常规", group="流体 2"));
  parameter Types.Roughness roughness_1=2.5e-5 annotation(Dialog(tab="常规", group="流体 1"));
  parameter Types.Roughness roughness_2=2.5e-5 annotation(Dialog(tab="常规", group="流体 2"));

  SI.HeatFlowRate Q_flow_1 "管程侧传热总量";
  SI.HeatFlowRate Q_flow_2 "壳程侧传热总量";

  .HPORC.HeatExchanger.WallConstProps wall(
    rho_wall=rho_wall, c_wall=c_wall, T_start=Twall_start, k_wall=k_wall,
    dT=dT, s=s_wall, energyDynamics=energyDynamics, n=nNodes, area_h=area_h) 
    annotation (Placement(transformation(extent={{-29,-23},{9,35}})));

  Pipe.DynamicPipe pipe_1(
    redeclare final package Medium = Medium_1,
    final isCircular=false, final diameter=0, final nNodes=nNodes,
    final allowFlowReversal=allowFlowReversal, final energyDynamics=energyDynamics,
    final massDynamics=massDynamics, final momentumDynamics=momentumDynamics,
    final length=length, final use_HeatTransfer=use_HeatTransfer,
    redeclare final model HeatTransfer = HeatTransfer_1,
    final use_T_start=use_T_start, final T_start=T_start_1, final h_start=h_start_1,
    final X_start=X_start_1, final m_flow_start=m_flow_start_1, final perimeter=perimeter_1,
    final crossArea=crossArea_1, final p_a_start=p_a_start1, final p_b_start=p_b_start1,
    final roughness=roughness_1, redeclare final model FlowModel = FlowModel_1,
    final modelStructure=modelStructure_1) 
    annotation (Placement(transformation(extent={{-40,-80},{20,-20}})));

  Pipe.DynamicPipe pipe_2(
    redeclare final package Medium = Medium_2,
    final nNodes=nNodes, final allowFlowReversal=allowFlowReversal,
    final energyDynamics=energyDynamics, final massDynamics=massDynamics,
    final momentumDynamics=momentumDynamics, final length=length,
    final isCircular=false, final diameter=0, final use_HeatTransfer=use_HeatTransfer,
    redeclare final model HeatTransfer = HeatTransfer_2,
    final use_T_start=use_T_start, final T_start=T_start_2, final h_start=h_start_2,
    final X_start=X_start_2, final m_flow_start=m_flow_start_2, final perimeter=perimeter_2,
    final crossArea=crossArea_2, final p_a_start=p_a_start2, final p_b_start=p_b_start2,
    final roughness=roughness_2, redeclare final model FlowModel = FlowModel_2,
    final modelStructure=modelStructure_2) 
    annotation (Placement(transformation(extent={{20,88},{-40,28}})));

  Modelica.Fluid.Interfaces.FluidPort_b port_b1(redeclare final package Medium = Medium_1) annotation (Placement(transformation(extent={{100,-12},{120,8}})));
  Modelica.Fluid.Interfaces.FluidPort_a port_a1(redeclare final package Medium = Medium_1) annotation (Placement(transformation(extent={{-120,-12},{-100,8}})));
  Modelica.Fluid.Interfaces.FluidPort_b port_b2(redeclare final package Medium = Medium_2) annotation (Placement(transformation(extent={{-120,36},{-100,56}})));
  Modelica.Fluid.Interfaces.FluidPort_a port_a2(redeclare final package Medium = Medium_2) annotation (Placement(transformation(extent={{100,-56},{120,-36}})));

equation
  Q_flow_1 = sum(pipe_1.heatTransfer.Q_flows);
  Q_flow_2 = sum(pipe_2.heatTransfer.Q_flows);

  connect(pipe_2.port_b, port_b2) annotation (Line(points={{-40,58},{-76,58},{-76,46},{-110,46}}, color={0,127,255}, thickness=0.5));
  connect(pipe_1.port_b, port_b1) annotation (Line(points={{20,-50},{42,-50},{42,-2},{110,-2}}, color={0,127,255}, thickness=0.5));
  connect(pipe_1.port_a, port_a1) annotation (Line(points={{-40,-50},{-75.3,-50},{-75.3,-2},{-110,-2}}, color={0,127,255}, thickness=0.5));
  connect(pipe_2.port_a, port_a2) annotation (Line(points={{20,58},{65,58},{65,-46},{110,-46}}, color={0,127,255}, thickness=0.5));

  connect(wall.heatPort_b, pipe_1.heatPorts) annotation (Line(points={{-10,-8.5},{-10,-36.8},{-9.7,-36.8}}, color={191,0,0}));
  connect(pipe_2.heatPorts[nNodes:-1:1], wall.heatPort_a[1:nNodes]) annotation (Line(points={{-10.3,44.8},{-10.3,31.7},{-10,31.7},{-10,20.5}}, color={127,0,0}));

  annotation (Icon(coordinateSystem(preserveAspectRatio=false, extent={{-100,-100},{100,100}}), graphics={
        Rectangle(extent={{-100,-26},{100,-30}}, fillColor={95,95,95}, fillPattern=FillPattern.Forward),
        Rectangle(extent={{-100,30},{100,26}}, fillColor={95,95,95}, fillPattern=FillPattern.Forward),
        Rectangle(extent={{-100,60},{100,30}}, fillPattern=FillPattern.HorizontalCylinder, fillColor={0,63,125}),
        Rectangle(extent={{-100,-30},{100,-60}}, fillPattern=FillPattern.HorizontalCylinder, fillColor={0,63,125}),
        Rectangle(extent={{-100,26},{100,-26}}, fillPattern=FillPattern.HorizontalCylinder, fillColor={0,128,255}),
        Text(extent={{-150,110},{150,70}}, textColor={0,0,255}, textString="%name"),
        Line(points={{30,-85},{-60,-85}}, color={0,128,255}),
        Polygon(points={{20,-70},{60,-85},{20,-100},{20,-70}}, lineColor={0,128,255}, fillColor={0,128,255}, fillPattern=FillPattern.Solid),
        Line(points={{30,77},{-60,77}}, color={0,128,255}),
        Polygon(points={{-50,92},{-90,77},{-50,62},{-50,92}}, lineColor={0,128,255}, fillColor={0,128,255}, fillPattern=FillPattern.Solid)}),
    Documentation(info="<html><p>已彻底消除端部代数环的稳定版本。</p></html>"));
end BasicHX;