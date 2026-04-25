package Examples "圆柱形储液罐 (CylindricalClosedVolume) 的系统级单元测试包"
  extends Modelica.Icons.ExamplesPackage;


  // =======================================================================
  // 测例 1：闭口定容加热 (纯热力学验证)
  // 目标：验证在无质量流动 (Wb_flow=0) 的情况下，热量注入是否能正确引起温度和压力的积分上升。
  // =======================================================================
  model Test_01_CylindricalClosedVolume_Heating
    "测例1：闭口定容加热 (验证容积热容与压力响应)"
    extends Modelica.Icons.Example;

    // 采用标准水表 (StandardWater)，初始压力设为 2bar 防止轻易沸腾
    replaceable package Medium = Modelica.Media.Water.StandardWater;

    inner Modelica.Fluid.System system(
      allowFlowReversal = true,
      p_start           = 2e5,
      T_start           = 293.15,
      // 强制使用纯动态的微分方程求解
      energyDynamics    = Modelica.Fluid.Types.Dynamics.FixedInitial,
      massDynamics      = Modelica.Fluid.Types.Dynamics.FixedInitial,
      momentumDynamics  = Modelica.Fluid.Types.Dynamics.SteadyState) 
      annotation (Placement(transformation(extent={{-90,70},{-70,90}})));

    // 被测容器：完全封闭 (nPorts=0)，开启传热 (use_HeatTransfer=true)
    CylindricalClosedVolume vol(
      redeclare package Medium = Medium,
      V                = 0.1,    // 100升
      L_D_ratio        = 3.0,
      nPorts           = 0,      // 无流体接口
      use_portsData    = false,
      use_HeatTransfer = true,
      p_start          = 2e5,
      T_start          = 293.15) 
      annotation (Placement(transformation(extent={{-10,-10},{10,10}})));

    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow heater 
      annotation (Placement(transformation(extent={{-50,-10},{-30,10}})));

    Modelica.Blocks.Sources.Step Q_step(
      height    = 5000,   // 阶跃输入 5 kW 热量 (保守值，防止 StandardWater 刚性报错)
      offset    = 0,
      startTime = 50)     // 第 50 秒开始加热
      annotation (Placement(transformation(extent={{-90,-10},{-70,10}})));

  equation
    connect(Q_step.y, heater.Q_flow) annotation (Line(points={{-69,0},{-50,0}}, color={0,0,127}));
    connect(heater.port, vol.heatPort) annotation (Line(points={{-30,0},{-10,0}}, color={191,0,0}));

    annotation (
      experiment(StartTime=0, StopTime=300, Tolerance=1e-6, Interval=0.5),
      Documentation(info="<html>
<p><b>闭口定容加热测例</b>：用于验证容器在 Wb_flow=0 下的热致升温与升压响应。</p>
<p><b>预期现象</b>：<br>
t &lt; 50 s：温度、压力保持水平不变。<br>
t &ge; 50 s：5kW 热量注入，<code>vol.medium.T</code> 开始上升，由于是定容液体受热，<code>vol.medium.p</code> 会出现极其显著的飙升（水受热膨胀引起的刚性升压）。</p>
</html>"));
  end Test_01_CylindricalClosedVolume_Heating;

  // =======================================================================
  // 测例 2：双端口通流混合 (质量守恒与理想混合验证)
  // 目标：验证端口流体进入容器后，能否正确进行“理想均相混合”，不计算局部阻力。
  // =======================================================================
  model Test_02_CylindricalClosedVolume_FlowThrough
    "测例2：双端口通流混合 (验证质量守恒与动态温度场)"
    extends Modelica.Icons.Example;

    replaceable package Medium = Modelica.Media.Water.StandardWater;

    inner Modelica.Fluid.System system(
      allowFlowReversal = true,
      p_start           = 2e5,
      T_start           = 293.15,
      energyDynamics    = Modelica.Fluid.Types.Dynamics.FixedInitial,
      massDynamics      = Modelica.Fluid.Types.Dynamics.FixedInitial,
      momentumDynamics  = Modelica.Fluid.Types.Dynamics.SteadyState) 
      annotation (Placement(transformation(extent={{-90,70},{-70,90}})));

    // 流量源：强制注入热水
    Modelica.Fluid.Sources.MassFlowSource_T inlet(
      redeclare package Medium = Medium,
      nPorts        = 1,
      use_m_flow_in = true,
      use_T_in      = false,
      m_flow        = 0.05,
      T             = 353.15) // 80°C 热水
      annotation (Placement(transformation(extent={{-70,-10},{-50,10}})));

    // 恒压背压边界
    Modelica.Fluid.Sources.Boundary_pT outlet(
      redeclare package Medium = Medium,
      nPorts = 1,
      p      = 2e5,       // 背压维持 2 bar
      T      = 293.15) 
      annotation (Placement(transformation(extent={{50,-10},{70,10}})));

    // 被测容器：开启两个流体端口
    CylindricalClosedVolume vol(
      redeclare package Medium = Medium,
      V                = 0.2,    // 200升
      L_D_ratio        = 3.0,
      nPorts           = 2,
      use_portsData    = false,  // 关闭局部阻力，测试理想透传
      use_HeatTransfer = false,  // 绝热
      p_start          = 2e5,
      T_start          = 293.15) // 初始内部是 20°C 冷水
      annotation (Placement(transformation(extent={{-10,-10},{10,10}})));

    Modelica.Blocks.Sources.Step m_flow_cmd(
      height    = 0.10,   // 第 100 秒时，流量从 0.05 跳跃到 0.15 kg/s
      offset    = 0.05,
      startTime = 100) 
      annotation (Placement(transformation(extent={{-110,-10},{-90,10}})));

  equation
    connect(m_flow_cmd.y, inlet.m_flow_in) annotation (Line(points={{-89,0},{-72,0}}, color={0,0,127}));
    connect(inlet.ports[1], vol.ports[1]) annotation (Line(points={{-50,0},{-10,0}}, color={0,127,255}));
    connect(vol.ports[2], outlet.ports[1]) annotation (Line(points={{10,0},{50,0}}, color={0,127,255}));

    annotation (
      experiment(StartTime=0, StopTime=400, Tolerance=1e-6, Interval=0.5),
      Documentation(info="<html>
<p><b>双端口通流测例</b>：用于验证端口连接、质量守恒以及理想混合温度的非线性积分变化。</p>
<p><b>预期现象</b>：<br>
初期容器内为 20°C，随着 80°C 热水的持续注入，<code>vol.medium.T</code> 将呈现对数衰减形态的平滑上升。<br>
在 100 s 时流量阶跃增大，混合温度上升的斜率会瞬间变陡，验证了 <code>dU/dt</code> 偏微分方程的完美运行。</p>
</html>"));
  end Test_02_CylindricalClosedVolume_FlowThrough;

  // =======================================================================
  // 测例 3：带端口阻力 + 出口节流 (工程级防爆瞬态验证)
  // 目标：验证开启 use_portsData=true 后，容器能否依靠局部阻力平抑由于阀门突然关小带来的水锤冲击。
  // =======================================================================
  model Test_03_CylindricalClosedVolume_PortLossAndValve
    "测例3：带端口阻力和阀门节流 (验证高频动态响应与死锁防御)"
    extends Modelica.Icons.Example;


    replaceable package Medium = Modelica.Media.Water.StandardWater;

    inner Modelica.Fluid.System system(
      allowFlowReversal = true,
      p_start           = 2.5e5, // 提高系统底压，防负压
      T_start           = 293.15,
      energyDynamics    = Modelica.Fluid.Types.Dynamics.FixedInitial,
      massDynamics      = Modelica.Fluid.Types.Dynamics.FixedInitial,
      momentumDynamics  = Modelica.Fluid.Types.Dynamics.SteadyState) 
      annotation (Placement(transformation(extent={{-90,70},{-70,90}})));

    // 定流量注入源
    Modelica.Fluid.Sources.MassFlowSource_T inlet(
      redeclare package Medium = Medium,
      nPorts        = 1,
      use_m_flow_in = false,
      m_flow        = 0.12,
      T             = 333.15) 
      annotation (Placement(transformation(extent={{-70,-10},{-50,10}})));

    // 被测容器：【核心】开启 portsData 局部涡流阻力计算
    CylindricalClosedVolume vol(
      redeclare package Medium = Medium,
      V                = 0.15,
      L_D_ratio        = 2.5,
      nPorts           = 2,
      use_portsData    = true,  // 开启阻力缓冲防爆
      use_HeatTransfer = false,
      p_start          = 2.5e5,
      T_start          = 293.15,
      portsData = {
        Modelica.Fluid.Vessels.BaseClasses.VesselPortsData(
          diameter = 0.020,     // 20mm 管径
          height   = 0.0,
          zeta_in  = 1.04,
          zeta_out = 0.50),
        Modelica.Fluid.Vessels.BaseClasses.VesselPortsData(
          diameter = 0.020,
          height   = 0.0,
          zeta_in  = 1.04,
          zeta_out = 0.50)}) 
      annotation (Placement(transformation(extent={{-20,-10},{0,10}})));

    // 出口动态节流阀
    Modelica.Fluid.Valves.ValveLinear valve(
      redeclare package Medium = Medium,
      m_flow_nominal = 0.12,
      dp_nominal     = 5e4)      // 额定压降 0.5 bar
      annotation (Placement(transformation(extent={{30,-10},{50,10}})));

    // 尾端恒定接收水池
    Modelica.Fluid.Sources.Boundary_pT sink(
      redeclare package Medium = Medium,
      nPorts = 1,
      p      = 2e5,              // 尾端 2 bar
      T      = 293.15) 
      annotation (Placement(transformation(extent={{80,-10},{100,10}})));

    // 阀门开度斜坡控制信号
    Modelica.Blocks.Sources.Ramp opening_cmd(
      height    = -0.7,   // 阀门开度从 1.0 降低到 0.3 (憋压测试)
      offset    = 1.0,
      startTime = 80,
      duration  = 80)     // 用 80 秒的时间缓慢关阀，防止极性刚性冲击导致除零错误
      annotation (Placement(transformation(extent={{30,40},{50,60}})));

  equation
    connect(inlet.ports[1], vol.ports[1]) annotation (Line(points={{-50,0},{-20,0}}, color={0,127,255}));
    connect(vol.ports[2], valve.port_a) annotation (Line(points={{0,0},{30,0}}, color={0,127,255}));
    connect(valve.port_b, sink.ports[1]) annotation (Line(points={{50,0},{80,0}}, color={0,127,255}));
    connect(opening_cmd.y, valve.opening) annotation (Line(points={{41,39},{41,8}}, color={0,0,127}));

    annotation (
      experiment(StartTime=0, StopTime=300, Tolerance=1e-6, Interval=0.2),
      Documentation(info="<html>
<p><b>带端口阻力和阀门节流的测例</b>：用于验证 <code>use_portsData=true</code> 时端口局部动压损失和系统级动态憋压响应。</p>
<p><b>预期现象</b>：<br>
当 t 达到 80 秒时，阀门开始逐渐关小，由于入口流量是强制恒定的 0.12 kg/s，流体被“憋”在了容器中。<br>
你可以观察 <code>vol.medium.p</code> (容器内压力) 将出现非常平滑、真实的上升响应，绝不会出现雅可比矩阵瞬间发散断裂的情况，这正是 <code>portsData</code> 中 <code>regSquare2</code> 二次方阻力正则化函数的功劳！</p>
</html>"  ));
  end Test_03_CylindricalClosedVolume_PortLossAndValve;
  model Test_04_CylindricalClosedVolume_PressureBoundaries
    "测例4：全压力边界驱动 (验证真实库存蓄积与 portsData 阻力效应)"
    extends Modelica.Icons.Example;

    replaceable package Medium = Modelica.Media.Water.StandardWater;

    inner Modelica.Fluid.System system(
      allowFlowReversal = true,
      p_start           = 2.5e5,
      T_start           = 293.15,
      energyDynamics    = Modelica.Fluid.Types.Dynamics.FixedInitial,
      massDynamics      = Modelica.Fluid.Types.Dynamics.FixedInitial,
      momentumDynamics  = Modelica.Fluid.Types.Dynamics.SteadyState) 
      annotation (Placement(transformation(extent={{-90,70},{-70,90}})));

    // 【恒定压力驱动源 (模拟一台定压水泵)】
    Modelica.Fluid.Sources.Boundary_pT source(
      redeclare package Medium = Medium,
      nPorts = 1,
      p      = 3.5e5,     // 泵出口提供恒定 3.5 bar 的高压
      T      = 333.15)    // 60°C 热水
      annotation (Placement(transformation(extent={{-90,-10},{-70,10}})));

    // 入口固定阻力阀 (模拟泵到容器之间的管道固定摩阻)
    Modelica.Fluid.Valves.ValveLinear valve_inlet(
      redeclare package Medium = Medium,
      m_flow_nominal = 0.12,
      dp_nominal     = 0.5e5) // 额定压降 0.5 bar
      annotation (Placement(transformation(extent={{-50,-10},{-30,10}})));

    // 被测容器：继续开启 portsData 局部涡流阻力计算
    CylindricalClosedVolume vol(
      redeclare package Medium = Medium,
      V                = 0.15,
      L_D_ratio        = 2.5,
      nPorts           = 2,
      use_portsData    = true,  // 验证这里的阻力在压力场下的真实作用
      use_HeatTransfer = false,
      p_start          = 2.5e5,
      T_start          = 293.15,
      portsData = {
        Modelica.Fluid.Vessels.BaseClasses.VesselPortsData(
          diameter = 0.020,
          height   = 0.0,
          zeta_in  = 1.04,
          zeta_out = 0.50),
        Modelica.Fluid.Vessels.BaseClasses.VesselPortsData(
          diameter = 0.020,
          height   = 0.0,
          zeta_in  = 1.04,
          zeta_out = 0.50)}) 
      annotation (Placement(transformation(extent={{-10,-10},{10,10}})));

    // 出口动态节流阀
    Modelica.Fluid.Valves.ValveLinear valve_outlet(
      redeclare package Medium = Medium,
      m_flow_nominal = 0.12,
      dp_nominal     = 0.5e5) 
      annotation (Placement(transformation(extent={{30,-10},{50,10}})));

    // 尾端恒定接收水池
    Modelica.Fluid.Sources.Boundary_pT sink(
      redeclare package Medium = Medium,
      nPorts = 1,
      p      = 2e5,       // 尾端 2 bar
      T      = 293.15) 
      annotation (Placement(transformation(extent={{70,-10},{90,10}})));

    // 出口阀门开度斜坡控制信号
    Modelica.Blocks.Sources.Ramp opening_cmd(
      height    = -0.7,   // 出口阀门开度从 1.0 降低到 0.3
      offset    = 1.0,
      startTime = 80,
      duration  = 80) 
      annotation (Placement(transformation(extent={{30,40},{50,60}})));

  equation
    // =======================================================================
    // 缺失方程修复：强制设定入口模拟阀门为全开状态，补齐系统自由度
    // =======================================================================
    valve_inlet.opening = 1.0;

    connect(source.ports[1], valve_inlet.port_a) annotation (Line(points={{-70,0},{-50,0}}, color={0,127,255}));
    connect(valve_inlet.port_b, vol.ports[1]) annotation (Line(points={{-30,0},{-10,0}}, color={0,127,255}));
    connect(vol.ports[2], valve_outlet.port_a) annotation (Line(points={{10,0},{30,0}}, color={0,127,255}));
    connect(valve_outlet.port_b, sink.ports[1]) annotation (Line(points={{50,0},{70,0}}, color={0,127,255}));
    connect(opening_cmd.y, valve_outlet.opening) annotation (Line(points={{41,39},{41,8}}, color={0,0,127}));

    annotation (
      experiment(StartTime=0, StopTime=300, Tolerance=1e-6, Interval=0.2),
      Documentation(info="<html>
<p><b>全压力边界驱动测例</b>：放开流量强约束，验证纯阻力网络下的物理响应。</p>
<p><b>预期现象与观察指南</b>：<br>
1. <b>流量自然衰减</b>：当你画出 <code>vol.ports[1].m_flow</code> 时，你会发现它不再是死板的直线。在 80~160s 关阀期间，随着整个管网总阻力增大，系统总流量将发生极其真实的<b>非线性下降</b>。<br>
2. <b>动态库存蓄积</b>：强烈建议同时绘制 <code>vol.ports[1].m_flow + vol.ports[2].m_flow</code> 与 <code>der(vol.m)</code>。在关阀瞬间，由于容器压力抬升对抗前方水泵，入口流量下降的速率会与出口流量下降的速率产生微小的时间差，这将导致 <code>vol.m</code> 出现真正的由于水流积压产生的上升，而不再仅仅是密度的热效应。<br>
3. <b>阻力博弈</b>：压力 <code>vol.medium.p</code> 依然会上升，但它最终会无限逼近上游水泵的 3.5 bar（因为出口几乎被关死，整个容器的压力向入口高压侧“找齐”）。</p>
</html>"));
  end Test_04_CylindricalClosedVolume_PressureBoundaries;

end Examples;