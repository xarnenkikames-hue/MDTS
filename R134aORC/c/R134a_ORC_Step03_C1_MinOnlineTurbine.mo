model R134a_ORC_Step03_C1_MinOnlineTurbine
  "C1：消灭 F-F/V-V 违规的极简在线透平接入"

  import SI = Modelica.SIunits;

  annotation(
    __MWORKS(version="26.1.3"),
    Diagram(coordinateSystem(extent={{-100,-100},{100,100}}, grid={2,2})),
    experiment(Algorithm=Dassl, StartTime=0, StopTime=700, Tolerance=1e-4));

  // ======================================================================
  // 冻结：成功热态母版参数 (与您完全一致)
  // ======================================================================
  parameter SI.AbsolutePressure p_init = 6e5;
  parameter SI.SpecificEnthalpy h_init = 227000;
  parameter SI.SpecificEnthalpy h_water_init = 84000;

  parameter Real valve_k = 0.9;
  parameter Real areaScale = 0.10;
  parameter Real wallScale = 0.50;
  parameter Real dT_hx = 15;

  parameter Real pumpOffset = 50;
  parameter Real pumpHeight = 450;
  parameter Real pumpDuration = 20;

  parameter Real coldFlowOffset = 1.0;
  parameter Real coldFlowHeight = 4.0;
  parameter Real coldFlowDuration = 10;

  parameter Real hotFlowStart = 100;
  parameter Real hotFlowOffset = 0.0;
  parameter Real hotFlowHeight = 0.50;
  parameter Real hotFlowDuration = 60;

  parameter Real hotTStart = 150;
  parameter Real hotTOffset = 293.15;
  parameter Real hotTHeight = 10.0;
  parameter Real hotTDuration = 150;

  parameter SI.AbsolutePressure p_hp_branch = p_init;
  parameter SI.SpecificEnthalpy h_hp_branch = h_init;

  // ======================================================================
  // 1. 系统、容器、泵
  // ======================================================================
  inner HPORC.System system(p_start = p_init, use_eps_Re = true);

  HPORC.Vessels.CylindricalClosedVolume receiver(nPorts = 3, redeclare package Medium = Modelica.Media.R134a.R134a_ph, V = 10, use_portsData = false, p_start = p_init, use_T_start = false, h_start = h_init);
  HPORC.Sources.Boundary_ph expansionTank(nPorts = 1, redeclare package Medium = Modelica.Media.R134a.R134a_ph, p = p_init, h = h_init);
  HPORC.Pipe.StaticPipe expPipe(redeclare package Medium = Modelica.Media.R134a.R134a_ph, length = 0.5, diameter = 0.05);
  HPORC.Pump.PrescribedPump pump(redeclare package Medium = Modelica.Media.R134a.R134a_ph, redeclare function flowCharacteristic = HPORC.Pump.BaseClasses.PumpCharacteristics.linearFlow, N_nominal = 1500, use_N_in = true);

  // ======================================================================
  // 2. 换热器
  // ======================================================================
  HPORC.HeatExchanger.BasicHX evaporator(length = 2, nNodes = 2, crossArea_1 = 0.01, perimeter_1 = 0.3, area_h_1 = 1.5*areaScale, crossArea_2 = 0.01, perimeter_2 = 0.3, area_h_2 = 1.5*areaScale, s_wall = 0.001*wallScale, k_wall = 15, c_wall = 200, rho_wall = 3000, dT = dT_hx, Twall_start = 293.15, redeclare package Medium_1 = Modelica.Media.R134a.R134a_ph, redeclare package Medium_2 = Modelica.Media.Water.ConstantPropertyLiquidWater, use_T_start = false, p_a_start1 = p_init, p_b_start1 = p_init, h_start_1 = h_init, p_a_start2 = 10e5, p_b_start2 = 10e5, h_start_2 = h_water_init);
  HPORC.HeatExchanger.BasicHX condenser(length = 2, nNodes = 2, crossArea_1 = 0.01, perimeter_1 = 0.3, area_h_1 = 1.5*areaScale, crossArea_2 = 0.01, perimeter_2 = 0.3, area_h_2 = 1.5*areaScale, c_wall = 200, k_wall = 15, rho_wall = 3000, s_wall = 0.001*wallScale, dT = dT_hx, Twall_start = 293.15, redeclare package Medium_1 = Modelica.Media.Water.ConstantPropertyLiquidWater, redeclare package Medium_2 = Modelica.Media.R134a.R134a_ph, use_T_start = false, p_a_start1 = 1e5, p_b_start1 = 1e5, h_start_1 = h_water_init, p_a_start2 = p_init, p_b_start2 = p_init, h_start_2 = h_init);
  HPORC.Pipe.StaticPipe pipeR134a(redeclare package Medium = Modelica.Media.R134a.R134a_ph, length = 1, diameter = 0.1);

  // ======================================================================
  // 3. 成功母版原旁路：保持不动（拆除错误的防倒流限制！）
  // ======================================================================
  Modelica.Fluid.Valves.ValveLinear mainValve(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    dp_nominal = 1e5,
    m_flow_nominal = 5.0); // 【修复1】：绝不能加 allowFlowReversal = false，允许初始化的数值微小振荡

  // ======================================================================
  // 4. C1：极简透平接入
  // ======================================================================
  Modelica.Fluid.Valves.ValveLinear turbineInValve(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    dp_nominal = 1e5,
    m_flow_nominal = 5.0, // 【修复2】：恢复到 5.0，对齐成功母版的矩阵缩放
    allowFlowReversal = false); // 透平支路加这个没问题，因为初始它是关死的

  HPORC.Vessels.CylindricalClosedVolume turbineInletPlenum(
    nPorts = 2,
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V = 0.01,
    use_portsData = false,
    p_start = p_hp_branch,
    use_T_start = false,
    h_start = h_hp_branch);

  CustomVolumetricExpander_C0 turbine(
    redeclare package Medium = Modelica.Media.R134a.R134a_ph,
    V_s = 300e-6,
    epsilon_v_nom = 0.95,
    eta_is_nom = 0.80,
    eta_mech = 0.90,
    C_leak = 1e-7,
    dp_eps = 1000.0,
    N_wake = 0.05);
  // ======================================================================
  // 5. 极简机械链
  // ======================================================================
  Modelica.Mechanics.Rotational.Components.Inertia shaftInertia(J = 1.0);
  Modelica.Mechanics.Rotational.Components.Damper shaftDamper(d = 0.05);
  Modelica.Mechanics.Rotational.Components.Fixed fixed;

  // ======================================================================
  // 6. 水侧边界
  // ======================================================================
  HPORC.Pipe.StaticPipe pipeHotWater(redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater, length = 1, diameter = 0.1);
  HPORC.Pipe.StaticPipe pipeColdWater(redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater, length = 1, diameter = 0.1);
  HPORC.Sources.MassFlowSource_T hotSource(nPorts = 1, use_m_flow_in = true, use_T_in = true, redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater);
  HPORC.Sources.Boundary_pT hotSink(nPorts = 1, redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater, p = 10e5, T = 293.15);
  HPORC.Sources.MassFlowSource_T coldSource(nPorts = 1, use_m_flow_in = true, use_T_in = false, T = 293.15, redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater);
  HPORC.Sources.Boundary_pT coldSink(nPorts = 1, redeclare package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater, p = 1e5, T = 293.15);

  // ======================================================================
  // 7. 启动时序
  // ======================================================================
  Modelica.Blocks.Sources.Ramp pumpRamp(startTime = 0, duration = pumpDuration, offset = pumpOffset, height = pumpHeight);
  Modelica.Blocks.Sources.Ramp coldM_ramp(startTime = 0, duration = coldFlowDuration, offset = coldFlowOffset, height = coldFlowHeight);
  Modelica.Blocks.Sources.Ramp hotM_ramp(startTime = hotFlowStart, duration = hotFlowDuration, offset = hotFlowOffset, height = hotFlowHeight);
  Modelica.Blocks.Sources.Ramp hotT_ramp(startTime = hotTStart, duration = hotTDuration, offset = hotTOffset, height = hotTHeight);

  Modelica.Blocks.Sources.Constant mainValveCmd(k = valve_k);

  // 透平入口缓开试探（废除出口阀后，只留这个即可）
  Modelica.Blocks.Sources.Ramp turbineInValveRamp(startTime = 0, duration = 100, offset = 1e-4, height = 0.0099);

equation
  // ======================================================================
  // 8. 主回路：Modelica 完美 V-F-V 自然分流/汇流
  // ======================================================================

  // 泵 -> 蒸发器
  connect(pump.port_a, receiver.ports[1]);
  connect(pump.port_b, evaporator.port_a1);

  // 【核心瘦身】：直接利用容积端口实现分流，杜绝 V-V 冲突！
  connect(evaporator.port_b1, mainValve.port_a);
  connect(evaporator.port_b1, turbineInValve.port_a);

  // 透平支路 (严格遵守 V-F-V 链条)
  connect(turbineInValve.port_b, turbineInletPlenum.ports[1]);
  connect(turbineInletPlenum.ports[2], turbine.port_in);

  // 【核心瘦身】：透平(Flow)直接连回冷凝器(Volume)，杜绝 F-F 死锁！
  connect(turbine.port_out, condenser.port_a2);
  connect(mainValve.port_b, condenser.port_a2);

  // 冷凝器 -> receiver
  connect(condenser.port_b2, pipeR134a.port_a);
  connect(pipeR134a.port_b, receiver.ports[3]);

  // 低压锚定
  connect(expansionTank.ports[1], expPipe.port_a);
  connect(expPipe.port_b, receiver.ports[2]);

  // 机械链
  connect(turbine.flange_shaft, shaftInertia.flange_a);
  connect(shaftInertia.flange_b, shaftDamper.flange_a);
  connect(shaftDamper.flange_b, fixed.flange);

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

end R134a_ORC_Step03_C1_MinOnlineTurbine;