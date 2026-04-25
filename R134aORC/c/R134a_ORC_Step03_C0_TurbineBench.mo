model R134a_ORC_Step03_C0_TurbineBench
  "C轮C0：透平单机空载台架验证"

  import SI = Modelica.SIunits;

  annotation(
    __MWORKS(version="26.1.3"),
    experiment(Algorithm=Dassl, StartTime=0, StopTime=300, Tolerance=1e-4));

  replaceable package Medium = Modelica.Media.R134a.R134a_ph;

  parameter SI.AbsolutePressure p_in_nom  = 6.38e5
    "入口代表压力";
  parameter SI.SpecificEnthalpy h_in_nom  = 2.58e5
    "入口代表焓";
  parameter SI.AbsolutePressure p_out_nom = 6.00e5
    "出口代表压力";
  parameter SI.SpecificEnthalpy h_out_nom = 2.32e5
    "出口代表焓";

  HPORC.Sources.Boundary_ph sourceIn(
    nPorts = 1,
    redeclare package Medium = Medium,
    p = p_in_nom,
    h = h_in_nom);

  HPORC.Sources.Boundary_ph sinkOut(
    nPorts = 1,
    redeclare package Medium = Medium,
    p = p_out_nom,
    h = h_out_nom);

  Modelica.Fluid.Valves.ValveLinear inletValve(
    redeclare package Medium = Medium,
    dp_nominal = 5e4,
    m_flow_nominal = 1.0,
    allowFlowReversal = false);

  HPORC.Vessels.CylindricalClosedVolume inletPlenum(
    nPorts = 2,
    redeclare package Medium = Medium,
    V = 0.001,
    use_portsData = false,
    p_start = p_in_nom,
    use_T_start = false,
    h_start = h_in_nom);

  CustomVolumetricExpander_C0 turbine(
    redeclare package Medium = Medium,
    V_s = 300e-6,
    epsilon_v_nom = 0.95,
    eta_is_nom = 0.80,
    eta_mech = 0.90,
    C_leak = 1e-7,
    dp_eps = 1000,
    N_wake = 0.05);

  Modelica.Mechanics.Rotational.Components.Inertia shaftInertia(J = 1.0);
  Modelica.Mechanics.Rotational.Components.Damper shaftDamper(d = 0.05);
  Modelica.Mechanics.Rotational.Components.Fixed fixed;

  // 先从 0 开到 0.10，台架验证不需要更大
  Modelica.Blocks.Sources.Ramp valveRamp(
    startTime = 20,
    duration = 80,
    offset = 0.0,
    height = 0.10);

equation
  connect(sourceIn.ports[1], inletValve.port_a);
  connect(inletValve.port_b, inletPlenum.ports[1]);
  connect(inletPlenum.ports[2], turbine.port_in);
  connect(turbine.port_out, sinkOut.ports[1]);

  connect(turbine.flange_shaft, shaftInertia.flange_a);
  connect(shaftInertia.flange_b, shaftDamper.flange_a);
  connect(shaftDamper.flange_b, fixed.flange);

  connect(valveRamp.y, inletValve.opening);

end R134a_ORC_Step03_C0_TurbineBench;