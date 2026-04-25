package HPORC_ValveTests
  "电子膨胀阀 (EEV) 准静态气动特性与真实容积闪蒸动态全套验证包"
  extends Modelica.Icons.Package;
  import SI = Modelica.Units.SI;

  // ============================================================
  // 测例 1：未壅塞基准测试 (单相/常规压降)
  // 目标：确认阀门在不发生汽化壅塞时，流量随压差按平方根规律正常变化。
  // ============================================================
  model Test_01_ValveNoChokeReference
    extends Modelica.Icons.Example;

    inner Modelica.Fluid.System system(
      p_start=1e6,
      allowFlowReversal=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      massDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      momentumDynamics=Modelica.Fluid.Types.Dynamics.SteadyState);

    Modelica.Fluid.Sources.Boundary_pT source(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      nPorts=1, p=1e6, T=445) "轻度过冷液体入口";

    Modelica.Fluid.Sources.Boundary_pT sink(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      nPorts=1, use_p_in=true, p=9.5e5, T=445);

    Modelica.Blocks.Sources.Ramp sinkPressureRamp(
      height=-5e4, duration=20, offset=9.5e5, startTime=2)
      "背压仅降到 0.90 MPa，绝不跨越闪蒸临界点";

    Modelica.Blocks.Sources.Constant valveOpen(k=1.0);

    Modelica.Fluid.Valves.ValveVaporizing valve(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      CvData=Modelica.Fluid.Types.CvTypes.Kv,
      Kv=38, // 修正后的合理通流尺度
      Fl_nominal=0.9,
      dp_nominal=1e5,
      m_flow_nominal=10);

  equation
    connect(source.ports[1], valve.port_a);
    connect(valve.port_b, sink.ports[1]);
    connect(sinkPressureRamp.y, sink.p_in);
    connect(valveOpen.y, valve.opening);

    annotation (experiment(StartTime=0, StopTime=25, Tolerance=1e-6, Interval=0.05),
      Documentation(info="<html><p><b>预期：</b>流量平滑单调上升，无截断平台。</p></html>"));
  end Test_01_ValveNoChokeReference;

  // ============================================================
  // 测例 2：壅塞穿越主测试 (准静态两相锁定)
  // 目标：验证背压跌破饱和蒸汽压时的流量截断逻辑。
  // ============================================================
  model Test_02_ValveChokeCrossing
    extends Modelica.Icons.Example;

    inner Modelica.Fluid.System system(
      p_start=1e6,
      allowFlowReversal=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      massDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      momentumDynamics=Modelica.Fluid.Types.Dynamics.SteadyState);

    Modelica.Fluid.Sources.Boundary_pT source(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      nPorts=1, p=1e6, T=445);

    Modelica.Fluid.Sources.Boundary_pT sink(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      nPorts=1, use_p_in=true, p=9.5e5, T=445);

    Modelica.Blocks.Sources.Ramp sinkPressureRamp(
      height=-8.5e5, duration=20, offset=9.5e5, startTime=2)
      "背压狂跌至 0.1 MPa，暴力跨越临界点";

    Modelica.Blocks.Sources.Constant valveOpen(k=1.0);

    Modelica.Fluid.Valves.ValveVaporizing valve(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      CvData=Modelica.Fluid.Types.CvTypes.Kv,
      Kv=38,
      Fl_nominal=0.9,
      dp_nominal=1e5,
      m_flow_nominal=10);

  equation
    connect(source.ports[1], valve.port_a);
    connect(valve.port_b, sink.ports[1]);
    connect(sinkPressureRamp.y, sink.p_in);
    connect(valveOpen.y, valve.opening);

    annotation (experiment(StartTime=0, StopTime=25, Tolerance=1e-6, Interval=0.05),
      Documentation(info="<html><p><b>预期：</b>流量先上升，跨过临界背压后瞬间被锁死成水平直线。</p></html>"));
  end Test_02_ValveChokeCrossing;

  // ============================================================
  // 测例 3：深度壅塞下的开度扫描测试
  // 目标：验证在壅塞状态下，流量仅受阀门开度控制，不再受背压影响。
  // ============================================================
  model Test_03_ValveOpeningUnderChoke
    extends Modelica.Icons.Example;

    inner Modelica.Fluid.System system(
      p_start=1e6,
      allowFlowReversal=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      massDynamics=Modelica.Fluid.Types.Dynamics.SteadyState,
      momentumDynamics=Modelica.Fluid.Types.Dynamics.SteadyState);

    Sources.Boundary_pT source(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      nPorts=1, p=1e6, T=445);

    Modelica.Fluid.Sources.Boundary_pT sink(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      nPorts=1, p=1.5e5, T=445) "固定在一个极低的深度壅塞背压处";

    Modelica.Blocks.Sources.Ramp valveOpen(
      height=0.8, duration=20, offset=0.2, startTime=2)
      "开度从 20% 匀速拉升至 100%";

    Modelica.Fluid.Valves.ValveVaporizing valve(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      CvData=Modelica.Fluid.Types.CvTypes.Kv,
      Kv=38,
      Fl_nominal=0.9,
      dp_nominal=1e5,
      m_flow_nominal=10);

  equation
    connect(source.ports[1], valve.port_a);
    connect(valve.port_b, sink.ports[1]);
    connect(valveOpen.y, valve.opening);

    annotation (experiment(StartTime=0, StopTime=25, Tolerance=1e-6, Interval=0.05),
      Documentation(info="<html><p><b>预期：</b>流量完全跟随开度曲线爬升，证明壅塞阀变成了纯粹的流量调节器。</p></html>"));
  end Test_03_ValveOpeningUnderChoke;

  // ============================================================
  // 测例 4：下游容积真实闪蒸动态演化测试 (顶级硬核)
  // 目标：激活质量与能量微积分方程，观察气液两相在容器内的真实滞后与压力累积。
  // ============================================================
  model Test_04_DynamicFlashingVolume
    extends Modelica.Icons.Example;

    // 【核心解封 1】：允许系统在瞬态冲击下自由发生压力倒挂与流向反转！
    inner Modelica.Fluid.System system(
      p_start=1e5,
      allowFlowReversal=true,
      energyDynamics=Modelica.Fluid.Types.Dynamics.FixedInitial,
      massDynamics=Modelica.Fluid.Types.Dynamics.FixedInitial,
      momentumDynamics=Modelica.Fluid.Types.Dynamics.SteadyState);

    Modelica.Fluid.Sources.Boundary_pT source(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      nPorts=1, p=1e6, T=445) "上游高压近饱和液体";

    Modelica.Blocks.Sources.Ramp valveOpen(
      height=0.5, duration=0.5, offset=0.0, startTime=2)
      "第 2 秒开始，用 0.5 秒时间平滑开启至 50%";

    Modelica.Blocks.Sources.Constant exhaustOpen(k=1.0)
      "排气阀全开信号";

    Modelica.Fluid.Valves.ValveVaporizing EEV(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      CvData=Modelica.Fluid.Types.CvTypes.Kv,
      Kv=38,
      Fl_nominal=0.9,
      dp_nominal=1e5,
      m_flow_nominal=10) "主电子膨胀阀 (诱发闪蒸的源头)";

    Modelica.Fluid.Vessels.ClosedVolume bufferVolume(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      V=0.5,
      use_portsData=false,
      nPorts=2,
      p_start=1e5,
      T_start=380) "动态缓冲容积 (初始充入 380K 过热蒸汽，提供气垫)";

    Modelica.Fluid.Valves.ValveLinear exhaustValve(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      dp_nominal=1e5,
      m_flow_nominal=5) "排气阻力阀";

    // 【核心解封 2】：将边界环境设为 380K 蒸汽。
    // 这样在冷激真空引发短时倒流时，吸入的是柔和的蒸汽，而非冰冷的液态水！
    Modelica.Fluid.Sources.Boundary_pT sink(
      redeclare package Medium = Modelica.Media.Water.StandardWater,
      nPorts=1, p=1e5, T=380) "外部边界";

  equation
    connect(source.ports[1], EEV.port_a);
    connect(valveOpen.y, EEV.opening);
    connect(EEV.port_b, bufferVolume.ports[1]);
    connect(exhaustOpen.y, exhaustValve.opening);
    connect(bufferVolume.ports[2], exhaustValve.port_a);
    connect(exhaustValve.port_b, sink.ports[1]);

    annotation (experiment(StartTime=0, StopTime=30, Tolerance=1e-6, Interval=0.05),
      Documentation(info="<html>
      <p><b>用途：</b>验证系统在节流阀、动态缓冲容积与排气阀耦合作用下的宏观热力学响应。</p>
      </html>"));
  end Test_04_DynamicFlashingVolume;

end HPORC_ValveTests;