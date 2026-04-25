model R134a_ORC_Step04_D0_LoadFromC1_NoAnchor
  "D0：基于最终C1母版的透平加负荷基准模型（移除 expansionTank-expPipe 压力锚定支路）"

  import SI = Modelica.SIunits;

  annotation(
    __MWORKS(version="26.1.3"),
    Diagram(coordinateSystem(extent={{-100,-100},{100,100}}, grid={2,2})),
    experiment(
      Algorithm=Dassl,
      StartTime=0,
      StopTime=20,
      Tolerance=0.0001,
      InlineIntegrator=false,
      InlineStepSize=false,
      NumberOfIntervals=2000,
      StoreEventValue=0));

  // ======================================================================
  // A. 冷态初始化（沿用成功 C1 母版）
  // ======================================================================
  parameter SI.AbsolutePressure p_init = 6e5
    "R134a 全局冷态初始压力";
  parameter SI.SpecificEnthalpy h_init = 227000
    "R134a 全局冷态初始比焓";
  parameter SI.SpecificEnthalpy h_water_init = 84000
    "水侧冷态初始比焓（约20°C）";

  // ======================================================================
  // B. 冻结：成功热态母版参数
  // ======================================================================
  parameter Real valve_k = 0.5
    "主阀固定开度";
  parameter Real areaScale = 0.10
    "HX换热面积缩放";
  parameter Real wallScale = 0.50
    "HX壁厚/热容缩放";
  parameter Real dT_hx = 15
    "HX dT 参数";

  parameter Real pumpOffset = 50
    "泵初始转速";
  parameter Real pumpHeight = 450
    "泵增量";
  parameter Real pumpDuration = 20
    "泵加速时长";

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
    "热源升温增量（到 303.15 K）";
  parameter Real hotTDuration = 150
    "热源升温时长";

  // ======================================================================
  // C. D0 新增：机械负荷参数
  // ======================================================================
  parameter Real turbineValveStart = 500
    "透平入口阀开始开启时刻";
  parameter Real turbineValveDuration = 50
    "透平入口阀开启历时";
  parameter Real turbineValveFinal = 0.5
    "透平入口阀最终开度";

  parameter Real loadStart = 800
    "外部负荷开始接入时刻";
  parameter Real loadDuration = 80
    "外部负荷爬升时间";
  parameter SI.Torque loadTorqueFinal = -0.02
    "最终负荷扭矩（负值表示吸收功）";

  // ======================================================================
  // 1. 系统、容器、泵
  // ======================================================================
  inner HPORC.System system(
    p_start = p_init,
    use_eps_Re = true);

  HPORC.Vessels.CylindricalClosedVolume receiver(
    nPorts = 2,
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V = 10,
    use_portsData = false,
    p_start = p_init,
    use_T_start = false,
    h_start = h_init);

  HPORC.Pump.PrescribedPump pump(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    redeclare function flowCharacteristic =
      HPORC.Pump.BaseClasses.PumpCharacteristics.linearFlow,
    N_nominal = 1500,
    use_N_in = true);

  // ======================================================================
  // 2. 换热器（完全沿用成功母版）
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
    h_start_2 = h_water_init);

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
    h_start_2 = h_init);

  HPORC.Pipe.StaticPipe pipeR134a(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    length = 1,
    diameter = 0.1);

  // ======================================================================
  // 3. 保底主阀（原成功母版）
  // ======================================================================
  Modelica.Fluid.Valves.ValveLinear mainValve(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    dp_nominal = 1e5,
    m_flow_nominal = 5.0,
    allowFlowReversal = true);

  // ======================================================================
  // 4. 在线透平接入拓扑（沿用成功母版）
  // ======================================================================
  HPORC.Pipe.StaticPipe hpBranchPipe(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    length = 0.2,
    diameter = 0.02);

  HPORC.Vessels.CylindricalClosedVolume hpHeader(
    nPorts = 3,
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V = 0.001,
    use_portsData = false,
    p_start = p_init,
    use_T_start = false,
    h_start = h_init);

  Modelica.Fluid.Valves.ValveLinear turbineInValve(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    dp_nominal = 1e5,
    m_flow_nominal = 1.0,
    allowFlowReversal = false);

  HPORC.Vessels.CylindricalClosedVolume turbineInletPlenum(
    nPorts = 2,
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V = 0.001,
    use_portsData = false,
    p_start = p_init,
    use_T_start = false,
    h_start = h_init);

  c.CustomVolumetricExpander_C0 turbine(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V_s = 300e-6,
    epsilon_v_nom = 0.95,
    eta_is_nom = 0.80,
    eta_mech = 0.90,
    C_leak = 1e-7,
    dp_eps = 1000.0,
    N_wake = 0.05);

  HPORC.Vessels.CylindricalClosedVolume lpHeader(
    nPorts = 3,
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V = 0.001,
    use_portsData = false,
    p_start = p_init,
    use_T_start = false,
    h_start = h_init);

  HPORC.Pipe.StaticPipe lpReturnPipe(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    length = 0.2,
    diameter = 0.02);

  // ======================================================================
  // 5. 机械链 + D0 新增外部负荷
  // ======================================================================
  Modelica.Mechanics.Rotational.Components.Inertia shaftInertia(J = 1.0);
  Modelica.Mechanics.Rotational.Components.Damper shaftDamper(d = 0.05);
  Modelica.Mechanics.Rotational.Components.Fixed fixed;

  Modelica.Mechanics.Rotational.Sources.Torque loadTorque(
    useSupport = false);

  // ======================================================================
  // 6. 水侧边界（完全沿用成功母版）
  // ======================================================================
  HPORC.Pipe.StaticPipe pipeHotWater(
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater,
    length = 1,
    diameter = 0.1);

  HPORC.Pipe.StaticPipe pipeColdWater(
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater,
    length = 1,
    diameter = 0.1);

  HPORC.Sources.MassFlowSource_T hotSource(
    nPorts = 1,
    use_m_flow_in = true,
    use_T_in = true,
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater);

  HPORC.Sources.Boundary_pT hotSink(
    nPorts = 1,
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater,
    p = 10e5,
    T = 293.15);

  HPORC.Sources.MassFlowSource_T coldSource(
    nPorts = 1,
    use_m_flow_in = true,
    use_T_in = false,
    T = 293.15,
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater);

  HPORC.Sources.Boundary_pT coldSink(
    nPorts = 1,
    redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater,
    p = 1e5,
    T = 293.15);

  // ======================================================================
  // 7. 启动时序：主系统不动；先透平上线，再加机械负荷
  // ======================================================================
  Modelica.Blocks.Sources.Ramp pumpRamp(
    startTime = 0,
    duration = pumpDuration,
    offset = pumpOffset,
    height = pumpHeight);

  Modelica.Blocks.Sources.Ramp coldM_ramp(
    startTime = 0,
    duration = coldFlowDuration,
    offset = coldFlowOffset,
    height = coldFlowHeight);

  Modelica.Blocks.Sources.Ramp hotM_ramp(
    startTime = hotFlowStart,
    duration = hotFlowDuration,
    offset = hotFlowOffset,
    height = hotFlowHeight);

  Modelica.Blocks.Sources.Ramp hotT_ramp(
    startTime = hotTStart,
    duration = hotTDuration,
    offset = hotTOffset,
    height = hotTHeight);

  Modelica.Blocks.Sources.Constant mainValveCmd(
    k = valve_k);

  Modelica.Blocks.Sources.Ramp turbineInValveRamp(
    startTime = turbineValveStart,
    duration = turbineValveDuration,
    offset = 0.0,
    height = turbineValveFinal);

  Modelica.Blocks.Sources.Ramp loadTorqueRamp(
    startTime = loadStart,
    duration = loadDuration,
    offset = 0.0,
    height = loadTorqueFinal);

equation
  // ======================================================================
  // 8. 主回路
  // ======================================================================
  connect(pump.port_a, receiver.ports[1]);
  connect(pump.port_b, evaporator.port_a1);

  connect(evaporator.port_b1, hpBranchPipe.port_a);
  connect(hpBranchPipe.port_b, hpHeader.ports[1]);

  connect(hpHeader.ports[2], mainValve.port_a);
  connect(hpHeader.ports[3], turbineInValve.port_a);

  connect(turbineInValve.port_b, turbineInletPlenum.ports[1]);
  connect(turbineInletPlenum.ports[2], turbine.port_in);

  connect(mainValve.port_b, lpHeader.ports[1]);
  connect(turbine.port_out, lpHeader.ports[2]);

  connect(lpHeader.ports[3], lpReturnPipe.port_a);
  connect(lpReturnPipe.port_b, condenser.port_a2);

  connect(condenser.port_b2, pipeR134a.port_a);
  connect(pipeR134a.port_b, receiver.ports[2]);

  // 机械链
  connect(turbine.flange_shaft, shaftInertia.flange_a);
  connect(shaftInertia.flange_b, shaftDamper.flange_a);
  connect(shaftDamper.flange_b, fixed.flange);

  // D0 新增：外部负荷挂在同一根轴上
  connect(shaftInertia.flange_b, loadTorque.flange);

  // ======================================================================
  // 9. 水侧
  // ======================================================================
  connect(hotSource.ports[1], evaporator.port_a2);
  connect(evaporator.port_b2, pipeHotWater.port_a);
  connect(pipeHotWater.port_b, hotSink.ports[1]);

  connect(coldSource.ports[1], condenser.port_a1);
  connect(condenser.port_b1, pipeColdWater.port_a);
  connect(pipeColdWater.port_b, coldSink.ports[1]);

  // ======================================================================
  // 10. 控制信号
  // ======================================================================
  connect(pumpRamp.y, pump.N_in);
  connect(coldM_ramp.y, coldSource.m_flow_in);
  connect(hotM_ramp.y, hotSource.m_flow_in);
  connect(hotT_ramp.y, hotSource.T_in);

  connect(mainValveCmd.y, mainValve.opening);
  connect(turbineInValveRamp.y, turbineInValve.opening);

  connect(loadTorqueRamp.y, loadTorque.tau);

end R134a_ORC_Step04_D0_LoadFromC1_NoAnchor;