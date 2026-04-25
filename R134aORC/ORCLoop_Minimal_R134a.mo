model ORCLoop_Minimal_R134a
  "最小 R134a ORC 闭式回路：泵-蒸发器-透平-冷凝器-储液器"

  import SI = Modelica.SIunits;

  annotation(
    __MWORKS(version="26.1.3"),
    Diagram(coordinateSystem(extent={{-100,-100},{100,100}}, grid={2,2})),
    experiment(
      Algorithm=Dassl,
      StartTime=0,
      StopTime=500,
      Tolerance=1e-4,
      InlineIntegrator=false,
      InlineStepSize=false,
      NumberOfIntervals=500,
      StoreEventValue=0));

  // ======================================================================
  // A. 冷态初始化：优先复用已有成功案例的 R134a p-h 初值
  // ======================================================================
  parameter SI.AbsolutePressure p_init = 6e5
    "R134a 全局冷态初始压力";
  parameter SI.SpecificEnthalpy h_init = 227000
    "R134a 全局冷态初始比焓";
  parameter SI.SpecificEnthalpy h_water_init = 84000
    "水侧冷态初始比焓（约20°C）";

  // ======================================================================
  // B. 最小回路参数：尽量保守，优先 check_model
  // ======================================================================
  parameter Real areaScale = 0.10
    "换热面积缩放";
  parameter Real wallScale = 0.50
    "管壁厚度/热容缩放";
  parameter Real dT_hx = 15
    "换热器初始温差参数";

  parameter Real pumpOffset = 50
    "泵初始转速";
  parameter Real pumpHeight = 450
    "泵增量";
  parameter Real pumpDuration = 20
    "泵爬升时长";

  parameter Real coldFlowOffset = 1.0
    "冷源初始流量";
  parameter Real coldFlowHeight = 4.0
    "冷源增量";
  parameter Real coldFlowDuration = 10
    "冷源爬升时长";

  parameter Real hotFlowStart = 100
    "热源流量启动时间";
  parameter Real hotFlowOffset = 0.0
    "热源初始流量";
  parameter Real hotFlowHeight = 0.50
    "热源增量";
  parameter Real hotFlowDuration = 60
    "热源流量爬升时长";

  parameter Real hotTStart = 150
    "热源温度启动时间";
  parameter Real hotTOffset = 293.15
    "热源初始温度";
  parameter Real hotTHeight = 10.0
    "热源升温增量";
  parameter Real hotTDuration = 150
    "热源升温时长";

  parameter SI.Volume V_header = 0.001
    "高低压 header 体积";
  parameter SI.Volume V_turbinePlenum = 0.001
    "透平入口前室体积";
  parameter SI.Length d_branch = 0.02
    "高低压短管直径";

  // ======================================================================
  // 1. 系统、receiver、泵
  // ======================================================================
  inner HPORC.System system(
    p_start = p_init,
    use_eps_Re = true) annotation(Placement(transformation(extent={{-39,-280},{-9,-240}})));

  HPORC.Vessels.CylindricalClosedVolume receiver(
    nPorts = 3,
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V = 10,
    use_portsData = false,
    p_start = p_init,
    use_T_start = false,
    h_start = h_init) annotation(Placement(transformation(extent={{-39,-228},{-9,-188}})));

  HPORC.Sources.Boundary_ph expansionTank(
    nPorts = 1,
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    p = p_init,
    h = h_init) annotation(Placement(transformation(extent={{-39,32},{-9,72}})));

  HPORC.Pipe.StaticPipe expPipe(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    length = 0.5,
    diameter = 0.05) annotation(Placement(transformation(extent={{-39,84},{-9,124}})));

  HPORC.Pump.PrescribedPump pump(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    redeclare function flowCharacteristic =
      HPORC.Pump.BaseClasses.PumpCharacteristics.linearFlow,
    N_nominal = 1500,
    use_N_in = true) annotation(Placement(transformation(extent={{-39,292},{-9,332}})));

  // ======================================================================
  // 2. 蒸发器与冷凝器
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
    h_start_2 = h_water_init) annotation(Placement(transformation(extent={{9,6},{39,46}})));

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
    h_start_2 = h_init) annotation(Placement(transformation(extent={{-39,136},{-9,176}})));

  HPORC.Pipe.StaticPipe pipeR134a(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    length = 1,
    diameter = 0.1) annotation(Placement(transformation(extent={{-39,86},{-9,126}})));

  // ======================================================================
  // 3. 最小透平支路：无旁通，只保留入口阀 + 前室 + 透平 + 低压回流
  // ======================================================================
  HPORC.Pipe.StaticPipe hpBranchPipe(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    length = 0.2,
    diameter = d_branch) annotation(Placement(transformation(extent={{9,-44},{39,-4}})));

  HPORC.Vessels.CylindricalClosedVolume hpHeader(
    nPorts = 2,
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V = V_header,
    use_portsData = false,
    p_start = p_init,
    use_T_start = false,
    h_start = h_init) annotation(Placement(transformation(extent={{-39,-124},{-9,-84}})));

  Modelica.Fluid.Valves.ValveLinear turbineInValve(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    dp_nominal = 1e5,
    m_flow_nominal = 1.0,
    allowFlowReversal = false) annotation(Placement(transformation(extent={{-15,-50},{15,-10}})));

  HPORC.Vessels.CylindricalClosedVolume turbineInletPlenum(
    nPorts = 2,
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V = V_turbinePlenum,
    use_portsData = false,
    p_start = p_init,
    use_T_start = false,
    h_start = h_init) annotation(Placement(transformation(extent={{-39,-332},{-9,-292}})));

  c.CustomVolumetricExpander_C0 turbine(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V_s = 300e-6,
    epsilon_v_nom = 0.95,
    eta_is_nom = 0.80,
    eta_mech = 0.90,
    C_leak = 1e-7,
    dp_eps = 1000.0,
    N_wake = 0.05) annotation(Placement(transformation(extent={{-39,190},{-9,230}})));

  HPORC.Vessels.CylindricalClosedVolume lpHeader(
    nPorts = 2,
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V = V_header,
    use_portsData = false,
    p_start = p_init,
    use_T_start = false,
    h_start = h_init) annotation(Placement(transformation(extent={{-39,-176},{-9,-136}})));

  HPORC.Pipe.StaticPipe lpReturnPipe(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    length = 0.2,
    diameter = d_branch) annotation(Placement(transformation(extent={{-39,86},{-9,126}})));

  // ======================================================================
  // 4. 极简机械链
  // ======================================================================
  Modelica.Mechanics.Rotational.Components.Inertia shaftInertia(J = 1.0) annotation(Placement(transformation(extent={{-39,240},{-9,280}})));
  Modelica.Mechanics.Rotational.Components.Damper shaftDamper(d = 0.05) annotation(Placement(transformation(extent={{9,-46},{39,-6}})));
  Modelica.Mechanics.Rotational.Components.Fixed fixed annotation(Placement(transformation(extent={{9,-96},{39,-56}})));

  // ======================================================================
  // 5. 热源侧与冷源侧
  // ======================================================================
  HPORC.Pipe.StaticPipe pipeHotWater(
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater,
    length = 1,
    diameter = 0.1) annotation(Placement(transformation(extent={{9,-44},{39,-4}})));

  HPORC.Pipe.StaticPipe pipeColdWater(
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater,
    length = 1,
    diameter = 0.1) annotation(Placement(transformation(extent={{-39,86},{-9,126}})));

  HPORC.Sources.MassFlowSource_T hotSource(
    nPorts = 1,
    use_m_flow_in = true,
    use_T_in = true,
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater) annotation(Placement(transformation(extent={{-39,-72},{-9,-32}})));

  HPORC.Sources.Boundary_pT hotSink(
    nPorts = 1,
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater,
    p = 10e5,
    T = 293.15) annotation(Placement(transformation(extent={{-39,-20},{-9,20}})));

  HPORC.Sources.MassFlowSource_T coldSource(
    nPorts = 1,
    use_m_flow_in = true,
    use_T_in = false,
    T = 293.15,
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater) annotation(Placement(transformation(extent={{-15,-50},{15,-10}})));

  HPORC.Sources.Boundary_pT coldSink(
    nPorts = 1,
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater,
    p = 1e5,
    T = 293.15) annotation(Placement(transformation(extent={{-39,188},{-9,228}})));

  // ======================================================================
  // 6. 启动时序：先建立主回路，再让透平支路上线
  // ======================================================================
  Modelica.Blocks.Sources.Ramp pumpRamp(
    startTime = 0,
    duration = pumpDuration,
    offset = pumpOffset,
    height = pumpHeight) annotation(Placement(transformation(extent={{-39,242},{-9,282}})));

  Modelica.Blocks.Sources.Ramp coldM_ramp(
    startTime = 0,
    duration = coldFlowDuration,
    offset = coldFlowOffset,
    height = coldFlowHeight) annotation(Placement(transformation(extent={{-15,-50},{15,-10}})));

  Modelica.Blocks.Sources.Ramp hotM_ramp(
    startTime = hotFlowStart,
    duration = hotFlowDuration,
    offset = hotFlowOffset,
    height = hotFlowHeight) annotation(Placement(transformation(extent={{-39,-122},{-9,-82}})));

  Modelica.Blocks.Sources.Ramp hotT_ramp(
    startTime = hotTStart,
    duration = hotTDuration,
    offset = hotTOffset,
    height = hotTHeight) annotation(Placement(transformation(extent={{-39,-122},{-9,-82}})));

  Modelica.Blocks.Sources.Ramp turbineInValveRamp(
    startTime = 200,
    duration = 50,
    offset = 0.0,
    height = 0.5) annotation(Placement(transformation(extent={{-15,-50},{15,-10}})));

equation
  // ======================================================================
  // 7. R134a 主回路
  // ======================================================================
  connect(pump.port_a, receiver.ports[1]);
  connect(pump.port_b, evaporator.port_a1) annotation(Line(points={{-9,312},{0,312},{0,26},{9,26}}, color={0,127,255}));

  connect(evaporator.port_b1, hpBranchPipe.port_a) annotation(Line(points={{39,26},{39,-8},{24,-8},{24,-4}}, color={0,127,255}));
  connect(hpBranchPipe.port_b, hpHeader.ports[1]);
  connect(hpHeader.ports[2], turbineInValve.port_a);

  connect(turbineInValve.port_b, turbineInletPlenum.ports[1]);
  connect(turbineInletPlenum.ports[2], turbine.port_in);

  connect(turbine.port_out, lpHeader.ports[1]);
  connect(lpHeader.ports[2], lpReturnPipe.port_a);
  connect(lpReturnPipe.port_b, condenser.port_a2) annotation(Line(points={{-24,126},{-24,156},{-39,156}}, color={0,127,255}));

  connect(condenser.port_b2, pipeR134a.port_a) annotation(Line(points={{-9,156},{-9,122},{-24,122},{-24,126}}, color={0,127,255}));
  connect(pipeR134a.port_b, receiver.ports[3]);

  // 低压锚定
  connect(expansionTank.ports[1], expPipe.port_a);
  connect(expPipe.port_b, receiver.ports[2]);

  // 机械链
  connect(turbine.flange_shaft, shaftInertia.flange_a) annotation(Line(points={{-24,230},{-24,260},{-39,260}}, color={0,0,0}));
  connect(shaftInertia.flange_b, shaftDamper.flange_a) annotation(Line(points={{-9,260},{0,260},{0,-26},{9,-26}}, color={0,0,0}));
  connect(shaftDamper.flange_b, fixed.flange) annotation(Line(points={{39,-26},{39,-60},{24,-60},{24,-56}}, color={0,0,0}));

  // ======================================================================
  // 8. 热源/冷源侧
  // ======================================================================
  connect(hotSource.ports[1], evaporator.port_a2);
  connect(evaporator.port_b2, pipeHotWater.port_a) annotation(Line(points={{39,26},{39,-8},{24,-8},{24,-4}}, color={0,127,255}));
  connect(pipeHotWater.port_b, hotSink.ports[1]);

  connect(coldSource.ports[1], condenser.port_a1);
  connect(condenser.port_b1, pipeColdWater.port_a) annotation(Line(points={{-9,156},{-9,122},{-24,122},{-24,126}}, color={0,127,255}));
  connect(pipeColdWater.port_b, coldSink.ports[1]);

  // ======================================================================
  // 9. 控制信号
  // ======================================================================
  connect(pumpRamp.y, pump.N_in) annotation(Line(points={{-24,282},{-24,312},{-39,312}}, color={0,0,127}));
  connect(coldM_ramp.y, coldSource.m_flow_in) annotation(Line(points={{0,-10},{0,-10},{0,-10}}, color={0,0,127}));
  connect(hotM_ramp.y, hotSource.m_flow_in) annotation(Line(points={{-24,-82},{-24,-52},{-39,-52}}, color={0,0,127}));
  connect(hotT_ramp.y, hotSource.T_in) annotation(Line(points={{-24,-82},{-24,-52},{-39,-52}}, color={0,0,127}));
  connect(turbineInValveRamp.y, turbineInValve.opening) annotation(Line(points={{0,-10},{0,-10},{0,-10}}, color={0,0,127}));

end ORCLoop_Minimal_R134a;
