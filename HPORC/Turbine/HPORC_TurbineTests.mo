package HPORC_TurbineTests
  "针对高保真映射透平 (MappedEfficiencyTurbine) 的四维回归测试包 (极致除错版)"
  extends Modelica.Icons.Package;
  import SI = Modelica.Units.SI;

  // ============================================================
  // 辅助组件 1：纯正的粘性阻尼负载 (防爆修复版)
  // ============================================================
  model ViscousLoad
    import SI = Modelica.Units.SI;
    Modelica.Mechanics.Rotational.Interfaces.Flange_a flange;
    parameter Real B(unit="N.m.s/rad", min=0) = 3 "粘性阻尼系数";
  equation
    flange.tau = B*der(flange.phi);
  end ViscousLoad;

  // ============================================================
  // 辅助组件 2：平滑阶跃恒扭矩负载 (防爆修复版)
  // ============================================================
  model SmoothStepTorqueLoad
    import SI = Modelica.Units.SI;
    Modelica.Mechanics.Rotational.Interfaces.Flange_a flange;
    parameter SI.Torque tau_initial = 100 "初始吸收扭矩";
    parameter SI.Torque tau_step = 500 "附加阶跃吸收扭矩";
    parameter SI.Time startTime = 5 "阶跃开始时间";
    parameter SI.Time riseTime(min=1e-4) = 0.2 "tanh 平滑时间尺度";
  protected
    Real s;
    SI.Torque tau_cmd;
  equation
    s = 0.5 + 0.5*Modelica.Math.tanh((time - startTime)/riseTime);
    tau_cmd = tau_initial + tau_step*s;
    flange.tau = tau_cmd;
  end SmoothStepTorqueLoad;

  // ============================================================
  // 测例 1：零速启动与限扭稳定测试 (采用官方 Damper)
  // ============================================================
  model Test_01_Startup
    extends Modelica.Icons.Example;

    inner Modelica.Fluid.System system(
      p_start=1e6,
      m_flow_start=1,
      allowFlowReversal=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      massDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      momentumDynamics=Modelica.Fluid.Types.Dynamics.SteadyState);

    parameter SI.Pressure p_source = 1e6;
    parameter SI.Pressure p_sink   = 2e5;
    parameter SI.Temperature T_source = 673.15;

    Modelica.Fluid.Sources.Boundary_pT source(redeclare package Medium = Modelica.Media.Water.StandardWater, nPorts=1, p=p_source, T=T_source);
    Modelica.Fluid.Sources.Boundary_pT sink(redeclare package Medium = Modelica.Media.Water.StandardWater, nPorts=1, p=p_sink, T=T_source);

    // 【修复 1】：强制显式声明实例介质为 StandardWater
    MappedEfficiencyTurbine turbine(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      p_a_start=p_source,
      PR_start=5.0,
      m_flow_start=1,
      w_start=0,
      PR_nominal=5,
      eta_is_nominal=0.85,
      K_flow=3e-7,
      PR_choke=0.55,
      J=0.05,
      w_nominal=314.159,
      dh_is_nominal=1e5,
      stallTorqueFactor=2.0);

    Modelica.Mechanics.Rotational.Components.Damper load(d=3.0);
    Modelica.Mechanics.Rotational.Components.Fixed ground;

  equation
    connect(source.ports[1], turbine.port_a);
    connect(turbine.port_b, sink.ports[1]);
    connect(turbine.shaft, load.flange_a);
    connect(load.flange_b, ground.flange);

    annotation (experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01));
  end Test_01_Startup;

  // ============================================================
  // 测例 2：机械负载阶跃测试 (验证热-机正向耦合)
  // ============================================================
  model Test_02_LoadStep
    extends Modelica.Icons.Example;

    inner Modelica.Fluid.System system(
      p_start=1e6,
      m_flow_start=1,
      allowFlowReversal=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      massDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      momentumDynamics=Modelica.Fluid.Types.Dynamics.SteadyState);

    parameter SI.Pressure p_source = 1e6;
    parameter SI.Pressure p_sink   = 2e5;
    parameter SI.Temperature T_source = 673.15;

    Modelica.Fluid.Sources.Boundary_pT source(redeclare package Medium = Modelica.Media.Water.StandardWater, nPorts=1, p=p_source, T=T_source);
    Modelica.Fluid.Sources.Boundary_pT sink(redeclare package Medium = Modelica.Media.Water.StandardWater, nPorts=1, p=p_sink, T=T_source);

    // 【修复 1】：强制显式声明实例介质为 StandardWater
    MappedEfficiencyTurbine turbine(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      p_a_start=p_source,
      PR_start=5.0,
      m_flow_start=1,
      w_start=314.159,
      PR_nominal=5,
      eta_is_nominal=0.85,
      K_flow=3e-7,
      PR_choke=0.55,
      J=0.05,
      w_nominal=314.159,
      dh_is_nominal=1e5);

    ViscousLoad baseLoad(B=2.5);
    SmoothStepTorqueLoad stepLoad(tau_initial=100, tau_step=600, startTime=5, riseTime=0.2);

  equation
    connect(source.ports[1], turbine.port_a);
    connect(turbine.port_b, sink.ports[1]);
    connect(turbine.shaft, baseLoad.flange);
    connect(turbine.shaft, stepLoad.flange);

    annotation (experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=0.01));
  end Test_02_LoadStep;

  // ============================================================
  // 测例 3：跨壅塞阈值背压阶跃测试 (验证机-热逆向耦合与流量折点)
  // ============================================================
  model Test_03_BackPressureStep
    extends Modelica.Icons.Example;

    inner Modelica.Fluid.System system(
      p_start=1e6,
      m_flow_start=1,
      allowFlowReversal=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      massDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      momentumDynamics=Modelica.Fluid.Types.Dynamics.SteadyState);

    parameter SI.Pressure p_source = 1e6;
    parameter SI.Temperature T_source = 673.15;

    Modelica.Fluid.Sources.Boundary_pT source(redeclare package Medium = Modelica.Media.Water.StandardWater, nPorts=1, p=p_source, T=T_source);

    // 【精准制导 1】：基础背压定在 0.25M (PR=4)，阶跃下降到 0.18M (PR=5.5)
    Modelica.Fluid.Sources.Boundary_pT sink(redeclare package Medium = Modelica.Media.Water.StandardWater, nPorts=1, use_p_in=true, p=2.5e5, T=T_source);
    Modelica.Blocks.Sources.Step sinkPressureStep(height=-0.7e5, offset=2.5e5, startTime=5);

    MappedEfficiencyTurbine turbine(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      p_a_start=p_source,
      PR_start=4.0,
      m_flow_start=1,
      w_start=300, // 初始猜测转速靠近设计点
      PR_nominal=5,
      eta_is_nominal=0.85,
      decay_PR_low=0.15,
      decay_PR_high=0.02,
      decay_speed=0.5,
      K_flow=3e-7,
      PR_choke=0.55,
      J=0.05,
      w_nominal=314.159,
      dh_is_nominal=1e5);

    // 【精准制导 2】：大幅减轻负载，让转速回归高位
    ViscousLoad load(B=1.0);

  equation
    connect(source.ports[1], turbine.port_a);
    connect(turbine.port_b, sink.ports[1]);
    connect(sinkPressureStep.y, sink.p_in);
    connect(turbine.shaft, load.flange);

    annotation (experiment(StartTime=0, StopTime=15, Tolerance=1e-6, Interval=0.01),
      Documentation(info="<html>
      <p><b>用途：</b>在设计点附近触发压比阶跃，完美激发非对称二维气动图谱的动态响应。</p>
      </html>"  ));
  end Test_03_BackPressureStep;

  // ============================================================
  // 测例 4：壅塞与超高压比非对称图谱验证测试
  // ============================================================
  model Test_04_ChokeValidation
    extends Modelica.Icons.Example;

    inner Modelica.Fluid.System system(
      p_start=1e6,
      m_flow_start=0.8,
      allowFlowReversal=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      massDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      momentumDynamics=Modelica.Fluid.Types.Dynamics.SteadyState);

    parameter SI.Pressure p_source = 1e6;
    parameter SI.Temperature T_source = 673.15;

    Modelica.Fluid.Sources.Boundary_pT source(redeclare package Medium = Modelica.Media.Water.StandardWater, nPorts=1, p=p_source, T=T_source);
    Modelica.Fluid.Sources.Boundary_pT sink(redeclare package Medium = Modelica.Media.Water.StandardWater, nPorts=1, use_p_in=true, p=7e5, T=T_source);
    Modelica.Blocks.Sources.Ramp sinkPressureRamp(height=-6.5e5, duration=25, offset=7e5, startTime=2);

    // 【修复 1 & 2】：统一包路径，并强制显式声明实例介质为 StandardWater
    MappedEfficiencyTurbine turbine(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      p_a_start=p_source,
      PR_start=1.42,
      m_flow_start=0.8,
      w_start=250,
      PR_nominal=5,
      eta_is_nominal=0.85,
      decay_PR_low=0.15,
      decay_PR_high=0.02,
      decay_speed=0.5,
      K_flow=3e-7,
      PR_choke=0.55,
      J=0.05,
      w_nominal=314.159,
      dh_is_nominal=1e5);

    ViscousLoad load(B=3.0);

  equation
    connect(source.ports[1], turbine.port_a);
    connect(turbine.port_b, sink.ports[1]);
    connect(sinkPressureRamp.y, sink.p_in);
    connect(turbine.shaft, load.flange);

    annotation (experiment(StartTime=0, StopTime=30, Tolerance=1e-6, Interval=0.02));
  end Test_04_ChokeValidation;
  model Test_04B_ChokeHighPower
    extends Modelica.Icons.Example;

    inner Modelica.Fluid.System system(
      p_start=1e6,
      m_flow_start=0.8,
      allowFlowReversal=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      massDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      momentumDynamics=Modelica.Fluid.Types.Dynamics.SteadyState);

    parameter SI.Pressure p_source = 1e6;
    parameter SI.Temperature T_source = 673.15;

    Modelica.Fluid.Sources.Boundary_pT source(redeclare package Medium = Modelica.Media.Water.StandardWater, nPorts=1, p=p_source, T=T_source);
    Modelica.Fluid.Sources.Boundary_pT sink(redeclare package Medium = Modelica.Media.Water.StandardWater, nPorts=1, use_p_in=true, p=7e5, T=T_source);
    Modelica.Blocks.Sources.Ramp sinkPressureRamp(height=-6.5e5, duration=25, offset=7e5, startTime=2);
    MappedEfficiencyTurbine turbine(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      p_a_start=p_source,
      PR_start=1.42,
      m_flow_start=0.8,
      // 【改动 1】：初始转速直接给到 314，彻底消灭零速启动时由于 w 极小导致的扭矩和功率尖峰！
      w_start=314.159,
      PR_nominal=5,
      eta_is_nominal=0.85,
      decay_PR_low=0.15,
      decay_PR_high=0.02,
      decay_speed=0.5,
      K_flow=3e-7,
      PR_choke=0.55,
      J=0.05,
      w_nominal=314.159,
      dh_is_nominal=1e5);

    // 【改动 2】：阻尼从 3.0 大幅削减至 0.8！释放转子，让它在高压比区能狂飙到 200 rad/s 以上！
    ViscousLoad load(B=0.8);

  equation
    connect(source.ports[1], turbine.port_a);
    connect(turbine.port_b, sink.ports[1]);
    connect(sinkPressureRamp.y, sink.p_in);
    connect(turbine.shaft, load.flange);

    annotation (experiment(StartTime=0, StopTime=30, Tolerance=1e-6, Interval=0.02),
      Documentation(info="<html>
      <p><b>用途：</b>轻载高转速版的壅塞与图谱验证测试。消除了巨大的启动尖峰，并使透平在高压比区能维持较高转速，从而激发明显的轴功率(W_out)二次隆起。</p>
      </html>"  ));
  end Test_04B_ChokeHighPower;

end HPORC_TurbineTests;