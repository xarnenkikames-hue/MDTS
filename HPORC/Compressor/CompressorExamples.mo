package CompressorExamples "压缩机验证与全工况测例包"

  annotation (
    Icon(coordinateSystem(preserveAspectRatio=true, extent={{-100,-100},{100,100}}), graphics={
      Polygon(points={{-36,60},{64,0},{-36,-60},{-36,60}}, lineColor={0,0,0}, fillColor={255,0,0}, fillPattern=FillPattern.Solid)}),
    Documentation(info="<html>
<p><b>压缩机验证测例包</b></p>
<p>本包包含了用于验证容积式压缩机模型在启停死区、压比塌陷、极端湿压缩以及倒流灌注工况下鲁棒性的四大标准测试矩阵。</p>
</html>"));

  // =======================================================================
  // 测例 01：启停死区与机械惯量测试
  // =======================================================================
  model Test_01_StartupAndShutdown "测例01：全启停周期与零速死区验证"
      extends Modelica.Icons.Example;
      import SI = Modelica.SIunits;

      replaceable package Medium = Modelica.Media.Water.StandardWater;
      inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial) annotation (Placement(transformation(extent={{-90,70},{-70,90}})));

      RobustCompressor compressor(
        redeclare package Medium = Medium,
        V_s = 0.001, J_rotor = 0.1, SH_min = 5.0, dSH_reg = 2.0, f_sh_min = 0.1) 
        annotation (Placement(transformation(extent={{-10,-10},{10,10}})));

      Modelica.Fluid.Sources.Boundary_pT source(redeclare package Medium = Medium, nPorts = 1, p = 1e5, T = 393.15) 
        annotation (Placement(transformation(extent={{-60,-10},{-40,10}})));
      Modelica.Fluid.Sources.Boundary_pT sink(redeclare package Medium = Medium, nPorts = 1, p = 5e5, T = 423.15) 
        annotation (Placement(transformation(extent={{40,-10},{60,10}})));

      Modelica.Mechanics.Rotational.Sources.Speed motor(useSupport = false, exact = true) 
        annotation (Placement(transformation(extent={{10,40},{30,60}})));

      // 【彻底修复】：使用全版本兼容的 TimeTable 替代 KinematicPTP
      // 动作剧本：0~2秒静止，2~7秒加速到50Hz，7~22秒保持满载，22~25秒急停回0
      Modelica.Blocks.Sources.TimeTable speed_cmd(
        table = [
          0,  0;
          2,  0;
          7,  50 * 2 * Modelica.Constants.pi;
          22, 50 * 2 * Modelica.Constants.pi;
          25, 0
        ]) 
        annotation (Placement(transformation(extent={{-30,40},{-10,60}})));

    equation
      connect(source.ports[1], compressor.port_a) annotation (Line(points={{-40,0},{-10,0}}, color={0,127,255}));
      connect(compressor.port_b, sink.ports[1]) annotation (Line(points={{10,0},{40,0}}, color={0,127,255}));
      connect(motor.flange, compressor.flange_shaft) annotation (Line(points={{30,50},{50,50},{50,8},{10,8}}, color={0,0,0}));
      connect(speed_cmd.y, motor.w_ref) annotation (Line(points={{-9,50},{10,50}}, color={0,0,127}));

      annotation (experiment(StartTime=0, StopTime=25, Tolerance=1e-6, Interval=0.05),
        Documentation(info="<html>
<p><b>测例01：启停死区与机械惯量测试</b></p>
<p>测试电机从 0 启动、满载运行、再急停回 0。重点验证除零防线、机械惯量 J 的物理平滑度，以及零转速下流体功与扭矩的完美归零。</p>
</html>"  ));
    end Test_01_StartupAndShutdown;


  // =======================================================================
  // 测例 02：低压比卸载与背压塌陷测试
  // =======================================================================
  model Test_02_PressureRatioUnload "测例02：背压塌陷与低压比卸载验证"
    extends Modelica.Icons.Example;
    import SI = Modelica.SIunits;

    replaceable package Medium = Modelica.Media.Water.StandardWater;
    inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial) annotation (Placement(transformation(extent={{-90,70},{-70,90}})));

    RobustCompressor compressor(
      redeclare package Medium = Medium,
      V_s = 0.001, J_rotor = 0.1, SH_min = 5.0, dSH_reg = 2.0, f_sh_min = 0.1) 
      annotation (Placement(transformation(extent={{-10,-10},{10,10}})));

    Modelica.Fluid.Sources.Boundary_pT source(redeclare package Medium = Medium, nPorts = 1, p = 1e5, T = 393.15) 
      annotation (Placement(transformation(extent={{-60,-10},{-40,10}})));
    Modelica.Fluid.Sources.Boundary_pT sink(redeclare package Medium = Medium, nPorts = 1, p = 5e5, T = 423.15, use_p_in = true) 
      annotation (Placement(transformation(extent={{40,-10},{60,10}})));

    Modelica.Mechanics.Rotational.Sources.Speed motor(useSupport = false, exact = true) 
      annotation (Placement(transformation(extent={{10,40},{30,60}})));

    Modelica.Blocks.Sources.Constant speed_cmd(k = 50 * 2 * Modelica.Constants.pi) 
      annotation (Placement(transformation(extent={{-30,40},{-10,60}})));

    Modelica.Blocks.Sources.Ramp p_cmd(
      offset = 5e5,
      height = -4.2e5,
      duration = 10,
      startTime = 10) 
      annotation (Placement(transformation(extent={{40,40},{60,60}})));

  equation
    connect(source.ports[1], compressor.port_a) annotation (Line(points={{-40,0},{-10,0}}, color={0,127,255}));
    connect(compressor.port_b, sink.ports[1]) annotation (Line(points={{10,0},{40,0}}, color={0,127,255}));
    connect(motor.flange, compressor.flange_shaft) annotation (Line(points={{30,50},{50,50},{50,8},{10,8}}, color={0,0,0}));
    connect(speed_cmd.y, motor.w_ref) annotation (Line(points={{-9,50},{10,50}}, color={0,0,127}));
    connect(p_cmd.y, sink.p_in) annotation (Line(points={{61,50},{80,50},{80,2},{60,2}}, color={0,0,127}));

    annotation (experiment(StartTime=0, StopTime=25, Tolerance=1e-6, Interval=0.05));
  end Test_02_PressureRatioUnload;


  // =======================================================================
  // 测例 03：深度湿压缩机理惩罚测试
  // =======================================================================
  model Test_03_WetCompression "测例03：深度湿压缩机理惩罚验证"
    extends Modelica.Icons.Example;
    import SI = Modelica.SIunits;

    replaceable package Medium = Modelica.Media.Water.StandardWater;
    inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial) annotation (Placement(transformation(extent={{-90,70},{-70,90}})));

    RobustCompressor compressor(
      redeclare package Medium = Medium,
      V_s = 0.001, J_rotor = 0.1, SH_min = 5.0, dSH_reg = 2.0, f_sh_min = 0.1) 
      annotation (Placement(transformation(extent={{-10,-10},{10,10}})));

    Modelica.Fluid.Sources.Boundary_pT source(redeclare package Medium = Medium, nPorts = 1, p = 1e5, T = 393.15, use_T_in = true) 
      annotation (Placement(transformation(extent={{-60,-10},{-40,10}})));
    Modelica.Fluid.Sources.Boundary_pT sink(redeclare package Medium = Medium, nPorts = 1, p = 5e5, T = 423.15) 
      annotation (Placement(transformation(extent={{40,-10},{60,10}})));

    Modelica.Mechanics.Rotational.Sources.Speed motor(useSupport = false, exact = true) 
      annotation (Placement(transformation(extent={{10,40},{30,60}})));

    Modelica.Blocks.Sources.Constant speed_cmd(k = 50 * 2 * Modelica.Constants.pi) 
      annotation (Placement(transformation(extent={{-30,40},{-10,60}})));

    Modelica.Blocks.Sources.Ramp temp_cmd(
      offset = 393.15,
      height = -20,
      duration = 10,
      startTime = 10) 
      annotation (Placement(transformation(extent={{-90,-40},{-70,-20}})));

  equation
    connect(source.ports[1], compressor.port_a) annotation (Line(points={{-40,0},{-10,0}}, color={0,127,255}));
    connect(compressor.port_b, sink.ports[1]) annotation (Line(points={{10,0},{40,0}}, color={0,127,255}));
    connect(motor.flange, compressor.flange_shaft) annotation (Line(points={{30,50},{50,50},{50,8},{10,8}}, color={0,0,0}));
    connect(speed_cmd.y, motor.w_ref) annotation (Line(points={{-9,50},{10,50}}, color={0,0,127}));
    connect(temp_cmd.y, source.T_in) annotation (Line(points={{-69,-30},{-50,-30},{-50,-18}}, color={0,0,127}));

    annotation (experiment(StartTime=0, StopTime=25, Tolerance=1e-6, Interval=0.05));
  end Test_03_WetCompression;


  // =======================================================================
  // 测例 04：倒流焓语义验证测例
  // =======================================================================
  model Test_04_ReverseFlowEnthalpy "测例04：检查 port_a.h_outflow = h_b 是否导致上游异常升焓"
    extends Modelica.Icons.Example;
    import SI = Modelica.SIunits;
    import Modelica.Constants.pi;

    replaceable package Medium = Modelica.Media.Water.StandardWater 
      constrainedby Modelica.Media.Interfaces.PartialTwoPhaseMedium;

    inner Modelica.Fluid.System system(
      energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
      massDynamics   = Modelica.Fluid.Types.Dynamics.FixedInitial,
      momentumDynamics = Modelica.Fluid.Types.Dynamics.SteadyState) 
      annotation (Placement(transformation(extent={{-90,70},{-70,90}})));

    RobustCompressor comp(
      redeclare package Medium = Medium,
      V_s = 100e-6,
      clearance_ratio = 0.05,
      n_poly = 1.2,
      epsilon_s_nom = 0.70,
      epsilon_v_nom = 0.90,
      J_rotor = 0.02,
      SH_min = 5.0,
      f_sh_min = 0.10,
      dp_safe = 20.0,
      p_su_start = 3e5,
      p_ex_start = 8e5,
      T_su_start = 400,
      h_su_start = Medium.specificEnthalpy_pT(3e5, 400),
      h_ex_start = Medium.specificEnthalpy_pT(8e5, 500)) 
      annotation (Placement(transformation(extent={{-10,-10},{10,10}})));

    Modelica.Fluid.Sources.Boundary_pT source(
      redeclare package Medium = Medium,
      p = 3e5,
      T = 400,
      nPorts = 1) 
      annotation (Placement(transformation(extent={{-100,-10},{-80,10}})));

    Modelica.Fluid.Vessels.ClosedVolume suctionBuffer(
      redeclare package Medium = Medium,
      V = 2e-3,
      nPorts = 2,
      p_start = 3e5,
      T_start = 400,
      use_portsData = false) 
      annotation (Placement(transformation(extent={{-60,-20},{-40,20}})));

    Modelica.Fluid.Sources.Boundary_pT sink(
      redeclare package Medium = Medium,
      use_p_in = true,
      T = 500,
      nPorts = 1) 
      annotation (Placement(transformation(extent={{80,-10},{100,10}})));

    Modelica.Blocks.Sources.TimeTable p_sink_profile(
      table = [
        0,   8e5;
        2,   8e5;
        4,   12e5;
        8,   12e5;
        12,  12e5;
        16,  8e5
      ]) 
      annotation (Placement(transformation(extent={{120,30},{140,50}})));

    Modelica.Mechanics.Rotational.Sources.Speed speedDrive(
      useSupport = false, exact = true) 
      annotation (Placement(transformation(extent={{-10,50},{10,70}})));

    Modelica.Blocks.Sources.TimeTable speed_profile(
      table = [
        0,   3000*2*pi/60;
        2,   3000*2*pi/60;
        4,   3000*2*pi/60;
        6,   200*2*pi/60;
        8,   20*2*pi/60;
        12,  0;
        16,  0
      ]) 
      annotation (Placement(transformation(extent={{-60,50},{-40,70}})));

    SI.Temperature T_buffer "上游缓冲容器温度";
    Medium.SpecificEnthalpy h_buffer "上游缓冲容器平均比焓";
    SI.MassFlowRate m_flow_a "压缩机吸气口质量流量（若<0则表示倒流）";
    SI.MassFlowRate m_flow_b "压缩机排气口质量流量";
    Medium.SpecificEnthalpy h_a_in "压缩机读取到的吸气焓";
    Medium.SpecificEnthalpy h_b_out "压缩机排气焓";

  equation
    connect(source.ports[1], suctionBuffer.ports[1]) annotation (Line(points={{-80,0},{-60,0}}, color={0,127,255}));
    connect(suctionBuffer.ports[2], comp.port_a) annotation (Line(points={{-40,0},{-10,0}}, color={0,127,255}));
    connect(comp.port_b, sink.ports[1]) annotation (Line(points={{10,0},{80,0}}, color={0,127,255}));

    connect(speedDrive.flange, comp.flange_shaft) annotation (Line(points={{10,60},{30,60},{30,8},{10,8}}, color={0,0,0}));
    connect(speed_profile.y, speedDrive.w_ref) annotation (Line(points={{-39,60},{-10,60}}, color={0,0,127}));
    connect(p_sink_profile.y, sink.p_in) annotation (Line(points={{141,40},{160,40},{160,2},{100,2}}, color={0,0,127}));

    T_buffer = suctionBuffer.medium.T;
    h_buffer = suctionBuffer.medium.h;

    m_flow_a = comp.port_a.m_flow;
    m_flow_b = comp.port_b.m_flow;
    h_a_in   = comp.h_a;
    h_b_out  = comp.h_b;

    annotation (
      experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.01),
      Documentation(info="<html>
<p><b>倒流焓语义验证测例</b></p>
<p>本测例通过“高背压 + 低转速停机”联合激励，专门测试压缩机吸气口发生倒流时，<code>port_a.h_outflow = h_b</code> 是否会导致上游缓冲容器出现异常升温或升焓。</p>
<p><b>重点观察变量：</b></p>
<ul>
<li><code>comp.port_a.m_flow</code>：若小于 0，表示吸气口发生倒流</li>
<li><code>T_buffer</code> / <code>h_buffer</code>：若短时间剧烈上冲，说明倒流焓定义较激进</li>
<li><code>comp.h_b</code> 与 <code>comp.h_a</code>：比较排气焓是否被直接反推回吸气侧</li>
</ul>
</html>"));
  end Test_04_ReverseFlowEnthalpy;

end CompressorExamples;