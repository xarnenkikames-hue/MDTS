model HeatExchangerSimulation "Simulation for the heat exchanger model"

extends Modelica.Icons.Example;

//replaceable package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater;
replaceable package Medium = Modelica.Media.Water.StandardWaterOnePhase;
//package Medium = Modelica.Media.Incompressible.Examples.Essotherm650;
  .HPORC.HeatExchanger.BasicHX HEX(
    c_wall=500,
    use_T_start=true,
    nNodes=20,
    m_flow_start_1=0.2,
    m_flow_start_2=0.2,
    k_wall=100,
    s_wall=0.005,
    crossArea_1=4.5e-4,
    crossArea_2=4.5e-4,
    perimeter_1=0.075,
    perimeter_2=0.075,
    rho_wall=900,
        pipe_1(mediums(p(each start = 1e5), T(each start = 288.15))),
    pipe_2(mediums(p(each start = 1e5), T(each start = 288.15))),
    redeclare package Medium_1 =
        Medium,
    redeclare package Medium_2 =
        Medium,
    modelStructure_1=Modelica.Fluid.Types.ModelStructure.av_b,
    modelStructure_2=Modelica.Fluid.Types.ModelStructure.a_vb,
    redeclare model HeatTransfer_1 =
        Modelica.Fluid.Pipes.BaseClasses.HeatTransfer.LocalPipeFlowHeatTransfer
        (alpha0=1000),
    length=20,
    area_h_1=0.075*20,
    area_h_2=0.075*20,
    redeclare model HeatTransfer_2 =
        Modelica.Fluid.Pipes.BaseClasses.HeatTransfer.ConstantFlowHeatTransfer
        (alpha0=2000),
    Twall_start=300,
    dT=10,
    T_start_1=304,
    T_start_2=300) annotation (Placement(transformation(extent={{
            -26,-14},{34,46}})));

  Sources.Boundary_pT ambient2(nPorts=1,
    p=1e5,
    T=280,
    redeclare package Medium = Medium) annotation (Placement(
        transformation(extent={{82,-28},{62,-8}})));
  Sources.Boundary_pT ambient1(nPorts=1,
    p=1e5,
    T=300,
    redeclare package Medium = Medium) annotation (Placement(
        transformation(extent={{82,24},{62,44}})));
  Sources.MassFlowSource_T massFlowRate2(nPorts=1,
    m_flow=0.2,
    T=360,
    redeclare package Medium = Medium,
    use_m_flow_in=true,
    use_T_in=false,
    use_X_in=false) 
                annotation (Placement(transformation(extent={{-66,24},{-46,44}})));
  Sources.MassFlowSource_T massFlowRate1(nPorts=1,
    redeclare package Medium = Medium,
    m_flow=0.2,
    T=300) annotation (Placement(transformation(extent={{-66,-10},{-46,10}})));
  Modelica.Blocks.Sources.Ramp Ramp1(
    startTime=50,
    duration=5,
    height=0.4,
    offset=-0.2) annotation (Placement(transformation(extent={{-98,24},{-78,
            44}})));
  inner Modelica.Fluid.System system(energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyStateInitial,
      use_eps_Re=true) annotation (Placement(transformation(extent=
            {{60,70},{80,90}})));
equation
  connect(massFlowRate1.ports[1], HEX.port_a1) annotation (Line(points={
          {-46,0},{-40,0},{-40,15.4},{-29,15.4}}, color={0,127,255}));
  connect(HEX.port_b1, ambient1.ports[1]) annotation (Line(points={{37,
          15.4},{48.5,15.4},{48.5,34},{62,34}}, color={0,127,255}));
  connect(Ramp1.y, massFlowRate2.m_flow_in) annotation (Line(points={{-77,34},
          {-74,34},{-74,42},{-66,42}}, color={0,0,127}));
  connect(massFlowRate2.ports[1], HEX.port_b2) 
                                           annotation (Line(
      points={{-46,34},{-40,34},{-40,29.8},{-29,29.8}}, color={0,127,255}));
  connect(HEX.port_a2, ambient2.ports[1]) 
                                      annotation (Line(
      points={{37,2.2},{42,2},{50,2},{50,-18},{62,-18}}, color={0,127,255}));
  annotation (experiment(StopTime=200, Tolerance=
          1e-005),
    Documentation(info="<html>
<p>The simulation start in steady state with counterflow operation. At time t = 50, the mass flow rate on the secondary circuit is changed to a negative value in 5 seconds. After a transient, the heat exchanger operates in co-current flow.</p>
<div><img src=\"modelica://Modelica/Resources/Images/Fluid/Examples/HeatExchanger/HeatExchanger.png\" alt=\"HeatExchanger.png\"/></div>
</html>"));
end HeatExchangerSimulation;