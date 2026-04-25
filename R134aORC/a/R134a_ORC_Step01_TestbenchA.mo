model R134a_ORC_Step01_TestbenchA "常物性水"

  import SI = Modelica.SIunits;

  annotation(
    __MWORKS(version="26.1.3"),
    Diagram(coordinateSystem(extent={{-100,-100},{100,100}}, grid={2,2})),
    experiment(Algorithm=Dassl, StartTime=0, StopTime=50, Tolerance=1e-4));

  // ======================================================================
  // A. 全局初始化参数（R134a 继续坚持 p,h）
  // ======================================================================
  parameter SI.AbsolutePressure p_init = 6e5 "R134a 全局冷态初始压力";
  parameter SI.SpecificEnthalpy h_init = 227000 "R134a 全局冷态初始比焓";
  parameter SI.SpecificEnthalpy h_water_init = 84000 "水侧冷态初始比焓（约20°C）";

  // ======================================================================
  // B. 诊断开关参数（改这里即可形成不同测例）
  // ======================================================================
  parameter Real valve_k = 0.9 "主阀固定开度";
  parameter Real areaScale = 0.10 "HX换热面积缩放";
  parameter Real wallScale = 0.50 "HX壁厚/热容缩放";
  parameter Real dT_hx = 15 "HX dT 参数";
  parameter Real pumpOffset = 50 "泵初始转速";
  parameter Real pumpHeight = 450 "泵增量";
  parameter Real pumpDuration = 20 "泵加速时长";

  parameter Real coldFlowOffset = 1.0 "冷源初始流量";
  parameter Real coldFlowHeight = 4.0 "冷源增量";
  parameter Real coldFlowDuration = 10 "冷源爬升时长";

  parameter Real hotFlowStart = 1000 "热源流量启动时间（>StopTime 表示禁用）";
  parameter Real hotFlowOffset = 0.0 "热源初始流量";
  parameter Real hotFlowHeight = 0.5 "热源增量";
  parameter Real hotFlowDuration = 60 "热源流量爬升时长";

  parameter Real hotTStart = 1000 "热源温度启动时间（>StopTime 表示禁用）";
  parameter Real hotTOffset = 293.15 "热源初始温度";
  parameter Real hotTHeight = 60.0 "热源升温增量";
  parameter Real hotTDuration = 100 "热源升温时长";

  // ======================================================================
  // 1. 系统、容器、泵
  // ======================================================================
  inner HPORC.System system(
    p_start = p_init,
    use_eps_Re = true) 
    annotation (Placement(transformation(origin={-10,70}, extent={{-10,-10},{10,10}})));

  HPORC.Vessels.CylindricalClosedVolume receiver(
    nPorts = 3,
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V = 2,
    use_portsData = false,
    p_start = p_init,
    use_T_start = false,
    h_start = h_init) 
    annotation (Placement(transformation(origin={-89,34}, extent={{-10,-10},{10,10}})));

  HPORC.Sources.Boundary_ph expansionTank(
    nPorts = 1,
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    p = p_init,
    h = h_init) 
    annotation (Placement(transformation(origin={-130,50}, extent={{-10,-10},{10,10}})));

  HPORC.Pipe.StaticPipe expPipe(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    length = 0.5,
    diameter = 0.05) 
    annotation (Placement(transformation(origin={-110,42}, extent={{-10,-10},{10,10}})));

  HPORC.Pump.PrescribedPump pump(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    redeclare function flowCharacteristic = HPORC.Pump.BaseClasses.PumpCharacteristics.linearFlow,
    N_nominal = 1500,
    use_N_in = true) 
    annotation (Placement(transformation(origin={-151,-8}, extent={{10,-10},{-10,10}})));

  // ======================================================================
  // 2. 换热器（完整保留，但参数化软化）
  // ======================================================================
  HPORC.HeatExchanger.BasicHX evaporator(
    length = 2,
    nNodes = 2,
    crossArea_1 = 0.01,
    perimeter_1 = 0.3,
    area_h_1 = 1.5*areaScale,
    crossArea_2 = 0.01,
    perimeter_2 = 0.3,
    area_h_2 = 1.5*areaScale,
    s_wall = 0.001*wallScale,
    k_wall = 15,
    c_wall = 200,
    rho_wall = 3000,
    dT = dT_hx,
    Twall_start = 293.15,
    redeclare package Medium_1 = Modelica.Media.R134a.R134a_ph,
    redeclare package Medium_2 = Modelica.Media.Water.ConstantPropertyLiquidWater,
    use_T_start = false,
    p_a_start1 = p_init,
    p_b_start1 = p_init,
    h_start_1 = h_init,
    p_a_start2 = 10e5,
    p_b_start2 = 10e5,
    h_start_2 = h_water_init) 
    annotation (Placement(transformation(origin={-158,100}, extent={{-10,-10},{10,10}})));

  HPORC.HeatExchanger.BasicHX condenser(
    length = 2,
    nNodes = 2,
    crossArea_1 = 0.01,
    perimeter_1 = 0.3,
    area_h_1 = 1.5*areaScale,
    crossArea_2 = 0.01,
    perimeter_2 = 0.3,
    area_h_2 = 1.5*areaScale,
    c_wall = 200,
    k_wall = 15,
    rho_wall = 3000,
    s_wall = 0.001*wallScale,
    dT = dT_hx,
    Twall_start = 293.15,
    redeclare package Medium_1 = Modelica.Media.Water.ConstantPropertyLiquidWater,
    redeclare package Medium_2 = Modelica.Media.R134a.R134a_ph,
    use_T_start = false,
    p_a_start1 = 1e5,
    p_b_start1 = 1e5,
    h_start_1 = h_water_init,
    p_a_start2 = p_init,
    p_b_start2 = p_init,
    h_start_2 = h_init) 
    annotation (Placement(transformation(origin={-34,15.4}, extent={{-10,-10},{10,10}})));

  // ======================================================================
  // 3. 主阀与 R134a 管道
  // ======================================================================
  Modelica.Fluid.Valves.ValveLinear mainValve(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    dp_nominal = 1e5,
    m_flow_nominal = 5.0) 
    annotation (Placement(transformation(origin={-100,100}, extent={{-10,-10},{10,10}})));

  HPORC.Pipe.StaticPipe pipeR134a(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    length = 1,
    diameter = 0.1) 
    annotation (Placement(transformation(origin={-66,15.4}, extent={{10,-10},{-10,10}})));

  // ======================================================================
  // 4. 水侧管道与边界
  // ======================================================================
  HPORC.Pipe.StaticPipe pipeHotWater(
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater,
    length = 1,
    diameter = 0.1) 
    annotation (Placement(transformation(origin={-190,130}, extent={{10,-10},{-10,10}})));

  HPORC.Pipe.StaticPipe pipeColdWater(
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater,
    length = 1,
    diameter = 0.1) 
    annotation (Placement(transformation(origin={-2,24}, extent={{-10,-10},{10,10}})));

  HPORC.Sources.MassFlowSource_T hotSource(
    nPorts = 1,
    use_m_flow_in = true,
    use_T_in = true,
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater) 
    annotation (Placement(transformation(origin={-106,124}, extent={{10,-10},{-10,10}})));

  HPORC.Sources.Boundary_pT hotSink(
    nPorts = 1,
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater,
    p = 10e5,
    T = 293.15) 
    annotation (Placement(transformation(origin={-218,130}, extent={{-10,-10},{10,10}})));

  HPORC.Sources.MassFlowSource_T coldSource(
    nPorts = 1,
    use_m_flow_in = true,
    use_T_in = false,
    T = 293.15,
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater) 
    annotation (Placement(transformation(origin={-94,-24}, extent={{-10,-10},{10,10}})));

  HPORC.Sources.Boundary_pT coldSink(
    nPorts = 1,
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater,
    p = 1e5,
    T = 293.15) 
    annotation (Placement(transformation(origin={56,24}, extent={{10,-10},{-10,10}})));

  // ======================================================================
  // 5. 启动时序
  // ======================================================================
  Modelica.Blocks.Sources.Ramp pumpRamp(
    startTime = 0,
    duration = pumpDuration,
    offset = pumpOffset,
    height = pumpHeight) 
    annotation (Placement(transformation(origin={-151,30}, extent={{-10,-10},{10,10}})));

  Modelica.Blocks.Sources.Ramp coldM_ramp(
    startTime = 0,
    duration = coldFlowDuration,
    offset = coldFlowOffset,
    height = coldFlowHeight) 
    annotation (Placement(transformation(origin={-94,-44}, extent={{-10,-10},{10,10}})));

  Modelica.Blocks.Sources.Ramp hotM_ramp(
    startTime = hotFlowStart,
    duration = hotFlowDuration,
    offset = hotFlowOffset,
    height = hotFlowHeight) 
    annotation (Placement(transformation(origin={-106,150}, extent={{-10,-10},{10,10}})));

  Modelica.Blocks.Sources.Ramp hotT_ramp(
    startTime = hotTStart,
    duration = hotTDuration,
    offset = hotTOffset,
    height = hotTHeight) 
    annotation (Placement(transformation(origin={-80,124}, extent={{-10,-10},{10,10}})));

  Modelica.Blocks.Sources.Constant valveOpenCmd(k = valve_k) 
    annotation (Placement(transformation(origin={-120,80}, extent={{-10,-10},{10,10}})));

equation
  // ======================================================================
  // 6. R134a 主回路
  // ======================================================================
  connect(pump.port_a, receiver.ports[1]) annotation(Line(points={{-141,-8},{-115,-8},{-115,-16},{0.5,-16},{0.5,13},{26,13},{26,16}}, color={0,127,255}));
  connect(pump.port_b, evaporator.port_a1) annotation(Line(points={{-161,-8},{-170,-8},{-170,95},{-168,95}}, color={0,127,255}));
  connect(evaporator.port_b1, mainValve.port_a) annotation(Line(points={{-148,95},{-130,95},{-130,100},{-110,100}}, color={0,127,255}));
  connect(mainValve.port_b, condenser.port_a2) annotation(Line(points={{-90,100},{-34,100},{-34,25.4}}, color={0,127,255}));
  connect(condenser.port_b2, pipeR134a.port_a) annotation(Line(points={{-44,15.4},{-56,15.4}}, color={0,127,255}));
  connect(pipeR134a.port_b, receiver.ports[3]) annotation(Line(points={{-76,15.4},{-82,15.4},{-82,24},{-89,24}}, color={0,127,255}));
  connect(expansionTank.ports[1], expPipe.port_a) annotation(Line(points={{-120,50},{-120,42}}, color={0,127,255}));
  connect(expPipe.port_b, receiver.ports[2]) annotation(Line(points={{-100,42},{-89,44}}, color={0,127,255}));

  // ======================================================================
  // 7. 热源水侧
  // ======================================================================
  connect(hotSource.ports[1], evaporator.port_a2) annotation(Line(points={{-116,124},{-158,124},{-158,110}}, color={0,127,255}));
  connect(evaporator.port_b2, pipeHotWater.port_a) annotation(Line(points={{-168,105},{-176,105},{-176,130},{-180,130}}, color={0,127,255}));
  connect(pipeHotWater.port_b, hotSink.ports[1]) annotation(Line(points={{-200,130},{-208,130}}, color={0,127,255}));

  // ======================================================================
  // 8. 冷源水侧
  // ======================================================================
  connect(coldSource.ports[1], condenser.port_a1) annotation(Line(points={{-84,-24},{-34,-24},{-34,-4.6}}, color={0,127,255}));
  connect(condenser.port_b1, pipeColdWater.port_a) annotation(Line(points={{-24,5.4},{-12,5.4},{-12,24},{-8,24}}, color={0,127,255}));
  connect(pipeColdWater.port_b, coldSink.ports[1]) annotation(Line(points={{4,24},{46,24}}, color={0,127,255}));

  // ======================================================================
  // 9. 信号连接
  // ======================================================================
  connect(pumpRamp.y, pump.N_in) annotation(Line(points={{-140,30},{-161,30},{-161,-2}}, color={0,0,127}));
  connect(coldM_ramp.y, coldSource.m_flow_in) annotation(Line(points={{-83,-44},{-94,-44},{-94,-32}}, color={0,0,127}));
  connect(hotM_ramp.y, hotSource.m_flow_in) annotation(Line(points={{-95,150},{-106,150},{-106,132}}, color={0,0,127}));
  connect(hotT_ramp.y, hotSource.T_in) annotation(Line(points={{-91,124},{-96,124}}, color={0,0,127}));
  connect(valveOpenCmd.y, mainValve.opening) annotation(Line(points={{-109,80},{-100,80},{-100,90}}, color={0,0,127}));

end R134a_ORC_Step01_TestbenchA;