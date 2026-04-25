partial model PartialPump "离心泵的抽象基类 (掌管真实的特性曲线、能耗效率与相似定律折算)"
    import Modelica.Units.NonSI;
    import Modelica.Constants;
    import Types = Modelica.Fluid.Types;
    import SI = Modelica.SIunits;

  // =======================================================================
  // 1. 继承双端口模型 (配置流向与极值)
  // =======================================================================
  extends HPORC.BaseClasses.PartialTwoPort(
    port_b_exposesState = energyDynamics<>Types.Dynamics.SteadyState or massDynamics<>Types.Dynamics.SteadyState,
    port_a(
      p(start=p_a_start),
      m_flow(start = m_flow_start,
             min = if allowFlowReversal and not checkValve then -Constants.inf else 0)),
    port_b(
      p(start=p_b_start),
      m_flow(start = -m_flow_start,
             max = if allowFlowReversal and not checkValve then +Constants.inf else 0)));

  // =======================================================================
  // 2. 初始化猜测值与同伦简化方程的起点
  // =======================================================================
  parameter Medium.AbsolutePressure p_a_start=system.p_start
      "入口压力初始猜测值" 
    annotation(Dialog(tab="初始化"));
  parameter Medium.AbsolutePressure p_b_start=p_a_start
      "出口压力初始猜测值" 
    annotation(Dialog(tab="初始化"));
  parameter Medium.MassFlowRate m_flow_start = system.m_flow_start
      "流量初始猜测值 (m_flow = port_a.m_flow)" 
    annotation(Dialog(tab = "初始化"));
  parameter Types.CheckValveHomotopyType checkValveHomotopy = Types.CheckValveHomotopyType.NoHomotopy
      "= 初始化时内置单向阀的状态 (关闭/开启/未知)" 
    annotation(Dialog(tab = "初始化"));

  // 【同伦初始化专用】：用于构建初始化简易直线的基准点
  final parameter SI.VolumeFlowRate V_flow_single_init = m_flow_start/rho_nominal/nParallel
      "用于简化初始化模型的单泵初始体积流量估算值";
  final parameter SI.Position delta_head_init = flowCharacteristic(V_flow_single_init*1.1)-flowCharacteristic(V_flow_single_init)
      "在初始化点流量增加 10% 时的扬程变化量 (用于求切线斜率)";

  // =======================================================================
  // 3. 水泵核心特性曲线 (厂家数据输入插槽)
  // =======================================================================
  parameter Integer nParallel(min=1) = 1 "并联的水泵数量" 
    annotation(Dialog(group="水泵特性"));

  replaceable function flowCharacteristic =
      PumpCharacteristics.baseFlow
      "额定转速和额定密度下的【扬程 vs. 体积流量曲线 (H-Q)】" 
    annotation(Dialog(group="水泵特性"), choicesAllMatching=true);

  parameter NonSI.AngularVelocity_rpm N_nominal
      "特性曲线对应的额定旋转速度" 
    annotation(Dialog(group="水泵特性"));
  parameter Medium.Density rho_nominal = Medium.density_pTX(Medium.p_default, Medium.T_default, Medium.X_default)
      "特性曲线对应的额定流体密度" 
    annotation(Dialog(group="水泵特性"));

  // 能耗计算的二选一逻辑
  parameter Boolean use_powerCharacteristic = false
      "= true 时使用【功率特性曲线】(区别于使用效率曲线)" 
     annotation(Evaluate=true,Dialog(group="水泵特性"));

  replaceable function powerCharacteristic =
        PumpCharacteristics.quadraticPower (
       V_flow_nominal={0,0,0},W_nominal={0,0,0})
      "额定状态下的【功率消耗 vs. 体积流量曲线】" 
    annotation(Dialog(group="水泵特性", enable = use_powerCharacteristic),
               choicesAllMatching=true);

  replaceable function efficiencyCharacteristic =
    PumpCharacteristics.constantEfficiency(eta_nominal = 0.8) constrainedby 
      PumpCharacteristics.baseEfficiency
      "额定状态下的【效率 vs. 体积流量曲线】(默认恒定效率 80%)" 
    annotation(Dialog(group="水泵特性",enable = not use_powerCharacteristic),
               choicesAllMatching=true);

  // =======================================================================
  // 4. 模型假设 (单向阀与水泵内部容积)
  // =======================================================================
  parameter Boolean checkValve=false "= true 时开启内置单向阀，严禁水流倒灌" 
    annotation(Dialog(tab="模型假设"), Evaluate=true);

  parameter SI.Volume V = 0 "水泵内部的腔体体积" 
    annotation(Dialog(tab="模型假设"),Evaluate=true);

  // =======================================================================
  // 5. 继承集总容积能量与质量守恒 (水泵本身也是一个小水箱)
  // =======================================================================
  extends HPORC.BaseClasses.PartialLumpedVolume(
      final fluidVolume = V,
      energyDynamics = Types.Dynamics.SteadyState,
      massDynamics = Types.Dynamics.SteadyState,
      final p_start = p_b_start);

  // =======================================================================
  // 6. 泵壳壁面传热模型 (应对死区运行发热)
  // =======================================================================
  parameter Boolean use_HeatTransfer = false
      "= true 开启壁面传热模型 (例如模拟泵壳散热)" 
      annotation (Dialog(tab="模型假设",group="散热设置"));

  replaceable model HeatTransfer =
      Modelica.Fluid.Vessels.BaseClasses.HeatTransfer.IdealHeatTransfer 
    constrainedby 
      Modelica.Fluid.Vessels.BaseClasses.HeatTransfer.PartialVesselHeatTransfer
      "壁面传热模型插槽" 
      annotation (Dialog(tab="模型假设",group="散热设置",enable=use_HeatTransfer),choicesAllMatching=true);

  HeatTransfer heatTransfer(
    redeclare final package Medium = Medium,
    final n=1,
    surfaceAreas={4*Modelica.Constants.pi*(3/4*V/Modelica.Constants.pi)^(2/3)},
    final states = {medium.state},
    final use_k = use_HeatTransfer) 
      annotation (Placement(transformation(
        extent={{-10,-10},{30,30}},
        rotation=180,
        origin={50,-10})));

  Modelica.Thermal.HeatTransfer.Interfaces.HeatPort_a heatPort if use_HeatTransfer 
    annotation (Placement(transformation(extent={{30,-70},{50,-50}})));

  // =======================================================================
  // 7. 核心物理变量声明
  // =======================================================================
  final parameter SI.Acceleration g=system.g "全局重力加速度";
  Medium.Density rho = medium.d;
  SI.Pressure dp_pump = port_b.p - port_a.p "进出口实际压差";
  SI.Position head = dp_pump/(rho*g) "实际输出扬程";
  SI.MassFlowRate m_flow = port_a.m_flow "总质量流量";
  SI.MassFlowRate m_flow_single = m_flow/nParallel
      "单泵质量流量";
  SI.VolumeFlowRate V_flow "总体积流量";
  SI.VolumeFlowRate V_flow_single(start = m_flow_start/rho_nominal/nParallel)
      "单泵体积流量";
  NonSI.AngularVelocity_rpm N(start = N_nominal) "当前驱动轴转速";
  SI.Power W_single "单泵消耗的机械功率";
  SI.Power W_total = W_single*nParallel "总消耗机械功率";
  Real eta "全局等熵效率";
  final constant Medium.MassFlowRate unit_m_flow=1 annotation (HideResult=true);
  Real s(start = m_flow_start/unit_m_flow)
      "参数化形式流动曲线的曲线横坐标 (可以是质量流量或扬程，用于处理单向阀死区)";

  // =======================================================================
  // 8. 高级监控诊断 (汽蚀余量 NPSH 等)
  // =======================================================================
  replaceable model Monitoring =
    Modelica.Fluid.Machines.BaseClasses.PumpMonitoring.PumpMonitoringBase 
    constrainedby 
      Modelica.Fluid.Machines.BaseClasses.PumpMonitoring.PumpMonitoringBase
      "可选的水泵状态监控插槽" 
      annotation(Dialog(tab="高级设置", group="诊断"), choicesAllMatching=true);

  Monitoring monitoring(
          redeclare final package Medium = Medium,
          final state_in = Medium.setState_phX(port_a.p, inStream(port_a.h_outflow), inStream(port_a.Xi_outflow)),
          final state = medium.state) "监控模型实例化" 
     annotation (Placement(transformation(extent={{-64,-42},{-20,0}})));

protected
  constant SI.Position unitHead = 1;
  constant SI.MassFlowRate unitMassFlowRate = 1;

equation
  // =======================================================================
  // 9. 核心水力学流动方程组 (含同伦初始化与相似定律折算)
  // =======================================================================
   V_flow = homotopy(m_flow/rho,
                     m_flow/rho_nominal);
   V_flow_single = V_flow/nParallel;

  if not checkValve then
    // 【无单向阀时的常规特性曲线】
    // 简化模型(用于初始化)在初始化点使用了扬程曲线切线的近似值
    head = homotopy((N/N_nominal)^2*flowCharacteristic(V_flow_single*N_nominal/N),
                     N/N_nominal*(flowCharacteristic(V_flow_single_init)+(V_flow_single-V_flow_single_init)*noEvent(if abs(V_flow_single_init)>0 then delta_head_init/(0.1*V_flow_single_init) else 0)));
    s = 0;
  else
    // 【开启单向阀时的特性曲线处理】
    // 简化模型使用了初始化点的切线近似，或者在系统以单向阀关闭状态初始化时，使用零流量垂直轴近似
    if checkValveHomotopy == Types.CheckValveHomotopyType.NoHomotopy then
      head = if s > 0 then (N/N_nominal)^2*flowCharacteristic(V_flow_single*N_nominal/N) 
                           else (N/N_nominal)^2*flowCharacteristic(0) - s*unitHead;
      V_flow_single = if s > 0 then s*unitMassFlowRate/rho else 0;
    else
      head = homotopy(if s > 0 then (N/N_nominal)^2*flowCharacteristic(V_flow_single*N_nominal/N) 
                             else (N/N_nominal)^2*flowCharacteristic(0) - s*unitHead,
                    if checkValveHomotopy == Types.CheckValveHomotopyType.Open then 
                      N/N_nominal*(flowCharacteristic(V_flow_single_init)+(V_flow_single-V_flow_single_init)*noEvent(if abs(V_flow_single_init)>0 then delta_head_init/(0.1*V_flow_single_init) else 0)) 
                    else 
                      N/N_nominal*flowCharacteristic(0) - s*unitHead);
      V_flow_single = homotopy(if s > 0 then s*unitMassFlowRate/rho else 0,
                             if checkValveHomotopy == Types.CheckValveHomotopyType.Open then s*unitMassFlowRate/rho_nominal else 0);
    end if;
  end if;

  // =======================================================================
  // 10. 能耗与效率方程 (核心相似定律应用)
  // =======================================================================
  if use_powerCharacteristic then
    W_single = homotopy((N/N_nominal)^3*(rho/rho_nominal)*powerCharacteristic(V_flow_single*N_nominal/N),
                        N/N_nominal*V_flow_single/V_flow_single_init*powerCharacteristic(V_flow_single_init));
    eta = dp_pump*V_flow_single/W_single;
  else
    eta = homotopy(efficiencyCharacteristic(V_flow_single*(N_nominal/N)),
                   efficiencyCharacteristic(V_flow_single_init));
    W_single = homotopy(dp_pump*V_flow_single/eta,
                        dp_pump*V_flow_single_init/eta);
  end if;

  // =======================================================================
  // 11. 总能量与质量平衡 (集总容积耦合)
  // =======================================================================
  Wb_flow = W_total;
  Qb_flow = heatTransfer.Q_flows[1];
  Hb_flow = port_a.m_flow*actualStream(port_a.h_outflow) +
            port_b.m_flow*actualStream(port_b.h_outflow);

  // 端口状态透传
  port_a.h_outflow = medium.h;
  port_b.h_outflow = medium.h;
  port_b.p = medium.p
      "出口压力等于介质内部压力，该压力已经包含了机械功 Wb_flow 带来的升压效果";

  // 质量平衡
  mb_flow = port_a.m_flow + port_b.m_flow;

  mbXi_flow = port_a.m_flow*actualStream(port_a.Xi_outflow) +
              port_b.m_flow*actualStream(port_b.Xi_outflow);
  port_a.Xi_outflow = medium.Xi;
  port_b.Xi_outflow = medium.Xi;

  mbC_flow = port_a.m_flow*actualStream(port_a.C_outflow) +
             port_b.m_flow*actualStream(port_b.C_outflow);
  port_a.C_outflow = C;
  port_b.C_outflow = C;

  connect(heatTransfer.heatPorts[1], heatPort) annotation (Line(
      points={{40,-34},{40,-60}}, color={127,0,0}));

  // =======================================================================
  // 图形注解与官方说明文档
  // =======================================================================
  annotation (
    Icon(coordinateSystem(preserveAspectRatio=true,  extent={{-100,-100},{100,
              100}}), graphics={
          Rectangle(
            extent={{-100,46},{100,-46}},
            fillColor={0,127,255},
            fillPattern=FillPattern.HorizontalCylinder),
          Polygon(
            points={{-48,-60},{-72,-100},{72,-100},{48,-60},{-48,-60}},
            lineColor={0,0,255},
            pattern=LinePattern.None,
            fillPattern=FillPattern.VerticalCylinder),
          Ellipse(
            extent={{-80,80},{80,-80}},
            fillPattern=FillPattern.Sphere,
            fillColor={0,100,199}),
          Polygon(
            points={{-28,30},{-28,-30},{50,-2},{-28,30}},
            pattern=LinePattern.None,
            fillPattern=FillPattern.HorizontalCylinder,
            fillColor={255,255,255})}),
    Documentation(info="<html>
<p>这是水泵的基础模型。</p>
<p>该模型描述了一台离心泵，或者是由 <code>nParallel</code> 台相同水泵组成的并联泵组。水泵模型基于<strong>运动学相似定律 (Kinematic Similarity)</strong> 构建：用户需提供额定工况（额定转速和流体密度）下的水泵特性曲线，模型会根据相似定律方程，自动将其动态折算至当前的实际运行工况。</p>

<p><strong>水泵特性 (Pump characteristics)</strong></p>
<p> 额定的水力特性曲线（扬程 vs. 体积流量）由可替换函数 <code>flowCharacteristic</code> 提供。</p>
<p> 水泵的能量平衡有两种指定方式：</p>
<ul>
<li><code>use_powerCharacteristic = false</code> (默认选项): 使用可替换函数 <code>efficiencyCharacteristic</code>（额定工况下的 效率 vs. 体积流量）来首先确定效率，进而反算功耗。
    默认设定为恒定效率 0.8。</li>
<li><code>use_powerCharacteristic = true</code>: 使用可替换函数 <code>powerCharacteristic</code>（额定工况下的 功耗 vs. 体积流量）来首先确定功耗，进而反算效率。
    如果你需要为零流量状态指定一个非零的轴功率消耗，请使用此选项。</li>
</ul>
<p>
在 <code>PumpCharacteristics</code> 包中提供了多个内置函数，允许你通过输入几个额定工况下的工作点数据来拟合生成特性曲线。
</p>
<p>根据 <code>checkValve</code> 参数的设定，模型既可以支持系统产生倒流工况，也可以激活一个内置的防逆流单向阀。</p>
<p>你可以通过指定水泵内部体积 <code>V</code>，并选择合适的动态质量和能量平衡假设（见下文），来将流体在泵内的质量和能量储能效应考虑在内；
<strong>强烈建议</strong>在零流量工况下开启此功能，以避免计算出口比焓时出现数学奇异（发散）报错。
如果你的系统绝对不可能出现零流量，为了避免引入容易拖慢求解速度的快速状态变量，你可以将此动态效应忽略（保留默认值 <code>V = 0</code>）。
</p>

<p><strong>动力学选项 (Dynamics options)</strong></p>
<p>
默认情况下，模型采用稳态的质量和能量平衡，忽略泵内的流体滞留（Holdup）；只要流量始终为正，这种配置就能极速运行。
你可以通过设置相应的动力学参数来激活动态质量和能量平衡。为了避免在零流量或流向反转时产生奇异崩溃，推荐使用动态平衡。如果系统的初始条件隐含了非零的质量流量，可以使用 <code>SteadyStateInitial</code>（开局稳态）条件；否则，强烈建议使用 <code>FixedInitial</code>（固定初值）以避免产生不确定的初始状态。
</p>

<p><strong>热传递 (Heat transfer)</strong></p>
<p>
如果你希望考虑水泵与外界环境的热交换（例如模拟一个带泵壳的系统），可以将布尔参数 <code>use_HeatTransfer</code> 设置为 true。
如果一台在零流量下拥有真实 <code>powerCharacteristic</code>（功耗非零）的水泵正在运转，而此时其出口阀门又被死死关闭，水泵会将机械功全部转化为热量。如果不开启热传递，这些热量无处散发会导致水泵内部流体温度无限飙升，此时开启散热模型将极其必要。
</p>

<p><strong>汽蚀诊断 (Diagnostics of Cavitation)</strong></p>
<p>只要你使用的是两相介质模型（详情见高级选项卡），你就可以将可替换的 <code>Monitoring</code> 子模型配置为 <code>PumpMonitoringNPSH</code>，
系统将自动为你计算有效汽蚀余量 (Net Positive Suction Head available)，并监控是否发生破坏性的汽蚀现象。
</p>
</html>",
      revisions="<html>
<ul>
<li><em>2013年1月8日</em>
    由 R&uuml;diger Franke 修改:<br>
    将 NPSH（汽蚀余量）诊断功能从 PartialPump 中移出，封装为独立的可替换子模型 PumpMonitoring.PumpMonitoringNPSH (参见工单 #646)</li>
<li><em>2008年12月</em>
    由 R&uuml;diger Franke 修改:<br>
    <ul>
    <li>使用严格的方程组（基于 PartialLumpedVolume 基类）替换了原有的简化版质量与能量平衡。</li>
    <li>引入了可选的 HeatTransfer（热传递）模型，用于定义边界热流 Qb_flow。</li>
    <li>启用了单向阀动作时的事件触发机制 (events)，以支持在 port_a 之前开启离散阀门的操作。</li>
    </ul></li>
<li><em>2005年10月31日</em>
    由 <a href=\"mailto:francesco.casella@polimi.it\">Francesco Casella</a> 创建:<br>
       将本模型首次添加至 Fluid 官方库。</li>
</ul>
</html>"));
end PartialPump;