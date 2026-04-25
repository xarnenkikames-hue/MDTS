package ExpanderExamples "ORC 膨胀机验证与全工况终极测例包"

  annotation (
    Icon(coordinateSystem(preserveAspectRatio=true, extent={{-100,-100},{100,100}}), graphics={
      Polygon(points={{-36,60},{64,0},{-36,-60},{-36,60}}, lineColor={0,0,0}, fillColor={255,0,0}, fillPattern=FillPattern.Solid)}),
    Documentation(info="<html>
<p><b>膨胀机验证测例包</b></p>
<p>本包包含了用于验证容积式膨胀机模型在自驱动建压、低压比卸载切断以及极端高背压停机工况下的三大标准测试矩阵。</p>
</html>"));

  // =======================================================================
  // 测例 01：真实物理自驱动与发电建压测试
  // =======================================================================
  model Test_01_SelfDrivenExpansion "测例01：流体自驱动与阻尼负载发电验证"
    extends Modelica.Icons.Example;
    import SI = Modelica.SIunits;

    replaceable package Medium = Modelica.Media.Water.StandardWater;
    inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial) annotation (Placement(transformation(extent={{-90,70},{-70,90}})));

    Expanders.RobustExpander expander(
      redeclare package Medium = Medium,
      V_s = 0.001, J_rotor = 0.1) 
      annotation (Placement(transformation(extent={{-10,-10},{10,10}})));

    // 高压热源：15 bar, 200°C (473.15 K)
    Modelica.Fluid.Sources.Boundary_pT source(redeclare package Medium = Medium, nPorts = 1, p = 15e5, T = 473.15) 
      annotation (Placement(transformation(extent={{-60,-10},{-40,10}})));

    // 低压冷凝器：1 bar
    Modelica.Fluid.Sources.Boundary_pT sink(redeclare package Medium = Medium, nPorts = 1, p = 1e5, T = 373.15) 
      annotation (Placement(transformation(extent={{40,-10},{60,10}})));

    // 【硬核升级】：彻底废除恒速源！改用真实的旋转惯量与阻尼器，模拟发电机负载
    Modelica.Mechanics.Rotational.Components.Inertia generator_inertia(J = 0.5) 
      annotation (Placement(transformation(extent={{30,40},{50,60}})));

    // 阻尼器充当发电机负载 (转速越快，发电阻力矩越大)
    Modelica.Mechanics.Rotational.Components.Damper generator_load(d = 0.5) 
      annotation (Placement(transformation(extent={{70,40},{90,60}})));

    Modelica.Mechanics.Rotational.Components.Fixed fixed_ground 
      annotation (Placement(transformation(extent={{110,40},{130,60}})));

  equation
    connect(source.ports[1], expander.port_in) annotation (Line(points={{-40,0},{-10,0}}, color={0,127,255}));
    connect(expander.port_out, sink.ports[1]) annotation (Line(points={{10,0},{40,0}}, color={0,127,255}));

    // 机械主轴连线：膨胀机 -> 发电机转子 -> 发电机定子负载 -> 大地
    connect(expander.flange_shaft, generator_inertia.flange_a) annotation (Line(points={{10,8},{20,8},{20,50},{30,50}}, color={0,0,0}));
    connect(generator_inertia.flange_b, generator_load.flange_a) annotation (Line(points={{50,50},{70,50}}, color={0,0,0}));
    connect(generator_load.flange_b, fixed_ground.flange) annotation (Line(points={{90,50},{110,50}}, color={0,0,0}));

    annotation (experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.05),
    Documentation(info="<html><p>本测例移除了理想速度源，完全依靠流体压差产生的扭矩驱动带有阻尼的发电机转子，验证其真实的动力学起步与稳态点自平衡能力。</p></html>"));
  end Test_01_SelfDrivenExpansion;


  // =======================================================================
  // 测例 02：低膨胀比卸载与残余流量切断验证
  // =======================================================================
  model Test_02_LowPRUnload "测例02：压比消失时的绝对归零卸载验证"
    extends Modelica.Icons.Example;
    import SI = Modelica.SIunits;

    replaceable package Medium = Modelica.Media.Water.StandardWater;
    inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial) annotation (Placement(transformation(extent={{-90,70},{-70,90}})));

    Expanders.RobustExpander expander(
      redeclare package Medium = Medium,
      V_s = 0.001, J_rotor = 0.1) 
      annotation (Placement(transformation(extent={{-10,-10},{10,10}})));

    Modelica.Fluid.Sources.Boundary_pT source(redeclare package Medium = Medium, nPorts = 1, p = 15e5, T = 473.15, use_p_in = true) 
      annotation (Placement(transformation(extent={{-60,-10},{-40,10}})));
    Modelica.Fluid.Sources.Boundary_pT sink(redeclare package Medium = Medium, nPorts = 1, p = 1e5, T = 373.15) 
      annotation (Placement(transformation(extent={{40,-10},{60,10}})));

    // 这里使用恒速源是为了强行维持转速，以便观测即便转子在狂转，流量是否也能因为 f_load 而归 0
    Modelica.Mechanics.Rotational.Sources.Speed generator(useSupport = false, exact = true) 
      annotation (Placement(transformation(extent={{10,40},{30,60}})));
    Modelica.Blocks.Sources.Constant speed_cmd(k = 50 * 2 * Modelica.Constants.pi) annotation (Placement(transformation(extent={{-30,40},{-10,60}})));

    // 进气压力从 15 bar 暴降至 1 bar，强行将膨胀比拉到 1.0
    Modelica.Blocks.Sources.Ramp p_cmd(offset = 15e5, height = -14.2e5, duration = 10, startTime = 5) 
      annotation (Placement(transformation(extent={{-80,40},{-60,60}})));

  equation
    connect(source.ports[1], expander.port_in) annotation (Line(points={{-40,0},{-10,0}}, color={0,127,255}));
    connect(expander.port_out, sink.ports[1]) annotation (Line(points={{10,0},{40,0}}, color={0,127,255}));
    connect(generator.flange, expander.flange_shaft) annotation (Line(points={{30,50},{50,50},{50,8},{10,8}}, color={0,0,0}));
    connect(speed_cmd.y, generator.w_ref) annotation (Line(points={{-9,50},{10,50}}, color={0,0,127}));
    connect(p_cmd.y, source.p_in) annotation (Line(points={{-59,50},{-50,50},{-50,2},{-50,2}}, color={0,0,127}));

    annotation (experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.05),
    Documentation(info="<html><p>本测例验证了修复后的容积效率限幅逻辑：当膨胀比崩溃、卸载因子 <code>f_load</code> 归零时，流量必须彻底归零，而不应残留由于限幅下限导致的幽灵流量。</p></html>"));
  end Test_02_LowPRUnload;


  // =======================================================================
  // 测例 03：高背压憋停与上游缓冲罐防倒灌污染验证
  // =======================================================================
  model Test_03_ReverseFlowPrevention "测例03：高背压憋停与上游绝热防污染测试"
    extends Modelica.Icons.Example;
    import SI = Modelica.SIunits;

    replaceable package Medium = Modelica.Media.Water.StandardWater 
      constrainedby Modelica.Media.Interfaces.PartialTwoPhaseMedium;
    inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial, massDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial) 
      annotation (Placement(transformation(extent={{-90,70},{-70,90}})));

    Expanders.RobustExpander expander(
      redeclare package Medium = Medium, V_s = 0.001, J_rotor = 0.1) 
      annotation (Placement(transformation(extent={{-10,-10},{10,10}})));

    // 热源边界：5 bar
    Modelica.Fluid.Sources.Boundary_pT source(redeclare package Medium = Medium, nPorts = 1, p = 5e5, T = 473.15) 
      annotation (Placement(transformation(extent={{-100,-10},{-80,10}})));

    // 【硬核升级】：加入容积为 2 升的上游缓冲罐，作为上游污染的“测谎仪”
    Modelica.Fluid.Vessels.ClosedVolume inletBuffer(
      redeclare package Medium = Medium,
      V = 2e-3, nPorts = 2, use_portsData = false, p_start = 5e5, T_start = 473.15) 
      annotation (Placement(transformation(extent={{-60,-20},{-40,20}})));

    // 冷凝侧边界：带有动态压力输入
    Modelica.Fluid.Sources.Boundary_pT sink(redeclare package Medium = Medium, nPorts = 1, p = 1e5, T = 373.15, use_p_in = true) 
      annotation (Placement(transformation(extent={{40,-10},{60,10}})));

    // 电机强制指令：第 4 秒停转
    Modelica.Mechanics.Rotational.Sources.Speed generator(useSupport = false, exact = true) annotation (Placement(transformation(extent={{10,50},{30,70}})));
    Modelica.Blocks.Sources.TimeTable speed_cmd(table=[0, 50*2*Modelica.Constants.pi; 4, 0; 10, 0]) annotation (Placement(transformation(extent={{-30,50},{-10,70}})));

    // 排气压力剧烈反超进气压力 (第 2 秒起，冷凝压力暴涨至 15 bar)
    Modelica.Blocks.Sources.Ramp p_cmd(offset = 1e5, height = 14e5, duration = 3, startTime = 2) annotation (Placement(transformation(extent={{40,40},{60,60}})));

    // 监测变量
    SI.Temperature T_buffer "上游缓冲容器温度 (如果发生倒流污染，该值将剧烈变化)";

  equation
    connect(source.ports[1], inletBuffer.ports[1]) annotation (Line(points={{-80,0},{-60,0}}, color={0,127,255}));
    connect(inletBuffer.ports[2], expander.port_in) annotation (Line(points={{-40,0},{-10,0}}, color={0,127,255}));
    connect(expander.port_out, sink.ports[1]) annotation (Line(points={{10,0},{40,0}}, color={0,127,255}));

    connect(generator.flange, expander.flange_shaft) annotation (Line(points={{30,60},{50,60},{50,8},{10,8}}, color={0,0,0}));
    connect(speed_cmd.y, generator.w_ref) annotation (Line(points={{-9,60},{10,60}}, color={0,0,127}));
    connect(p_cmd.y, sink.p_in) annotation (Line(points={{61,50},{80,50},{80,2},{60,2}}, color={0,0,127}));

    T_buffer = inletBuffer.medium.T;

    annotation (experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01),
    Documentation(info="<html><p>本测例利用上游的 ClosedVolume 验证了基类倒流焓语义的修复效果：当受到极高背压逼停时，模型不仅要在物理上切断残余逆向流量，且决不允许将低温低焓状态错误地反算回灌给上游系统。</p></html>"));
  end Test_03_ReverseFlowPrevention;

end ExpanderExamples;