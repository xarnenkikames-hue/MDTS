partial model PartialLumpedVessel
  "带有流体端口阵列和可替换传热模型的集总容积基类 (Lumped volume with a vector of fluid ports and replaceable heat transfer model)"
  // 继承最底层的纯数学微积分容积基类
  import SI = Modelica.SIunits;
  import Utilities = Modelica.Fluid.Utilities;
  extends PartialLumpedVolume;

  // =======================================================================
  // 1. 端口定义 (Port definitions)
  // =======================================================================
  parameter Integer nPorts=0 "连接外围管网的端口总数量" 
    annotation(Evaluate=true, Dialog(connectorSizing=true, tab="General",group="Ports"));

  // 动态生成指定数量的流体交互端口
  VesselFluidPorts_b ports[nPorts](redeclare each package Medium = Medium)
  "流体入口与出口阵列" 
    annotation (Placement(transformation(extent={{-40,-10},{40,10}},
      origin={0,-100})));

  // =======================================================================
  // 2. 端口物理属性与局部阻力计算开关 (Port properties)
  // =======================================================================
  parameter Boolean use_portsData=true
  "= false 时，强行忽略所有端口的局部压降和流体动能（适合极度简化的理想防爆模型）" 
    annotation(Evaluate=true, Dialog(tab="General",group="Ports"));

  // 核心阻力数据包：包含每个端口的直径、安装高度、流入/流出阻力系数(zeta)
  parameter VesselPortsData[if use_portsData then nPorts else 0] 
  portsData "进/出口端口的具体几何与水力阻力数据" 
    annotation(Dialog(tab="General",group="Ports",enable= use_portsData));

  // 流量正则化参数（用于消除流量过零时，由于摩擦力导数无穷大导致的雅可比矩阵奇异崩溃）
  parameter Medium.MassFlowRate m_flow_nominal = if system.use_eps_Re then system.m_flow_nominal else 1e2*system.m_flow_small
  "各端口的额定质量流量参考值" 
    annotation(Dialog(tab="Advanced", group="Port properties"));

  parameter SI.MassFlowRate m_flow_small(min=0) = if system.use_eps_Re then system.eps_m_flow*m_flow_nominal else system.m_flow_small
  "零流量附近的正则化平滑区间（防止除零崩溃）" 
    annotation(Dialog(tab="Advanced", group="Port properties"));

  parameter Boolean use_Re = system.use_eps_Re
  "= true 时，基于雷诺数定义湍流临界区；否则基于绝对微小流量 m_flow_small" 
    annotation(Dialog(tab="Advanced", group="Port properties"), Evaluate=true);

  // =======================================================================
  // 3. 物质与能量的边界流量阵列
  // =======================================================================
  Medium.EnthalpyFlowRate ports_H_flow[nPorts];
  Medium.MassFlowRate ports_mXi_flow[nPorts,Medium.nXi];
  Medium.MassFlowRate[Medium.nXi] sum_ports_mXi_flow
  "穿过所有端口的各组分质量流量之和";
  Medium.ExtraPropertyFlowRate ports_mC_flow[nPorts,Medium.nC];
  Medium.ExtraPropertyFlowRate[Medium.nC] sum_ports_mC_flow
  "穿过所有端口的痕量物质质量流量之和";

  // =======================================================================
  // 4. 边界传热模型 (可热插拔替换)
  // =======================================================================
  parameter Boolean use_HeatTransfer = false
  "= true 启用容器壁面传热模型" 
      annotation (Dialog(tab="Assumptions", group="Heat transfer"));

  replaceable model HeatTransfer =
      Modelica.Fluid.Vessels.BaseClasses.HeatTransfer.IdealHeatTransfer 
    constrainedby 
  Modelica.Fluid.Vessels.BaseClasses.HeatTransfer.PartialVesselHeatTransfer
  "壁面传热代理模型" 
      annotation (Dialog(tab="Assumptions", group="Heat transfer",enable=use_HeatTransfer),choicesAllMatching=true);

  HeatTransfer heatTransfer(
    redeclare final package Medium = Medium,
    final n=1,
    final states = {medium.state},
    final use_k = use_HeatTransfer) 
      annotation (Placement(transformation(
        extent={{-10,-10},{30,30}},
        rotation=90,
        origin={-50,-10})));

  Modelica.Thermal.HeatTransfer.Interfaces.HeatPort_a heatPort if use_HeatTransfer 
    annotation (Placement(transformation(extent={{-110,-10},{-90,10}})));

  // =======================================================================
  // 5. 动能与势能守恒 (Conservation of kinetic energy)
  // =======================================================================
  Medium.Density[nPorts] portInDensities
  "设备边界（端口处）的流体实际密度";
  SI.Velocity[nPorts] portVelocities
  "设备边界（端口处）的流体流速";
  SI.EnergyFlowRate[nPorts] ports_E_flow
  "穿过设备边界的动能与重力势能流（极其严谨的能量守恒补丁）";

  // =======================================================================
  // 6. 液位与端口防穿透逻辑 (核心防爆机制)
  // =======================================================================
  // 注意：计算逻辑应使用 fluidLevel_start - portsData.height
  Real[nPorts] s(each start = fluidLevel_max)
  "曲线参数，用于处理端口流量与端口压力的关系（利用同伦平滑逻辑处理极值）；详见官方教程：理想开关设备";
  Real[nPorts] ports_penetration
  "流体对端口的浸没程度（介于0到1之间），取决于当前液位和端口直径的相对关系";

  // =======================================================================
  // 7. 端口局部压降处理
  // =======================================================================
  SI.Area[nPorts] portAreas = {Modelica.Constants.pi/4*portsData_diameter[i]^2 for i in 1:nPorts};
  Medium.AbsolutePressure[nPorts] vessel_ps_static
  "在各个端口对应的物理高度上，容器内部的静态压力（假设流速为零时的静压，考虑了重力液柱压降）";

  // 确定湍流区阈值
  constant SI.ReynoldsNumber Re_turbulent = 100 "参考突然扩径的阻力特性";
  SI.MassFlowRate[nPorts] m_flow_turbulent;

protected
  input SI.Height fluidLevel = 0
  "容器内当前的流体液位高度（用于判断哪些端口被液体淹没，哪些暴露在气体中）";
  parameter SI.Height fluidLevel_max = 1
  "容器内允许的最大液位高度（触顶防爆限制）";
  parameter SI.Area vesselArea = Modelica.Constants.inf
  "容器自身的横截面积（用于与端口截面积计算面积比，推导截面突变的动压损失）";

  // =======================================================================
  // 内部防错机制：处理 use_portsData=false 时的矩阵降维灾难
  // 如果关闭了阻力计算，强制赋予所有端口几何参数为 0，防止求解器在调用无维度矩阵时崩溃。
  // =======================================================================
  Modelica.Blocks.Interfaces.RealInput[nPorts] 
  portsData_diameter_internal = portsData.diameter if use_portsData and nPorts > 0;
  Modelica.Blocks.Interfaces.RealInput[nPorts] portsData_height_internal = portsData.height if use_portsData and nPorts > 0;
  Modelica.Blocks.Interfaces.RealInput[nPorts] portsData_zeta_in_internal = portsData.zeta_in if use_portsData and nPorts > 0;
  Modelica.Blocks.Interfaces.RealInput[nPorts] portsData_zeta_out_internal = portsData.zeta_out if use_portsData and nPorts > 0;

  Modelica.Blocks.Interfaces.RealInput[nPorts] portsData_diameter;
  Modelica.Blocks.Interfaces.RealInput[nPorts] portsData_height;
  Modelica.Blocks.Interfaces.RealInput[nPorts] portsData_zeta_in;
  Modelica.Blocks.Interfaces.RealInput[nPorts] portsData_zeta_out;

  // 逻辑控制探头
  Modelica.Blocks.Interfaces.BooleanInput[nPorts] regularFlow(each start=true);
  Modelica.Blocks.Interfaces.BooleanInput[nPorts] inFlow(each start=false);

equation
  // 将底层的常微分变量与当前的端口阵列进行绑定
  mb_flow = sum(ports.m_flow);
  mbXi_flow = sum_ports_mXi_flow;
  mbC_flow  = sum_ports_mC_flow;
  // 【能量守恒核心】：总能量变化 = 纯热力学焓流 + 动能与重力势能流
  Hb_flow = sum(ports_H_flow) + sum(ports_E_flow);
  Qb_flow = heatTransfer.Q_flows[1];

  // 严禁一个流体端口连接多个外部管道（防止非预期的理想流体混合）
  for i in 1:nPorts loop
    assert(cardinality(ports[i]) <= 1,"
每个容器的端口 ports[i] 最多只能连接一个外部组件。
如果存在两个或多个连接，求解器将在该节点强制发生理想混合，
这通常违背了建模者的物理意图。请增加 nPorts 的参数值来添加新的独立端口。
");
  end for;

  // 安全断言：求解有效性检查
  assert(fluidLevel <= fluidLevel_max, "容器已溢出/爆满 (fluidLevel > fluidLevel_max = " + String(fluidLevel) + ")");
  assert(fluidLevel > -1e-6*fluidLevel_max, "流体液位 (= " + String(fluidLevel) + ") 低于零，意味着偏微分方程求解彻底失败。");

  // =======================================================================
  // 边界条件处理 (Boundary conditions)
  // =======================================================================

  // 阻力数据探头的动态连线
  connect(portsData_diameter, portsData_diameter_internal);
  connect(portsData_height, portsData_height_internal);
  connect(portsData_zeta_in, portsData_zeta_in_internal);
  connect(portsData_zeta_out, portsData_zeta_out_internal);

  if not use_portsData then
    // 如果关闭阻力计算，强制数组归零洗白
    portsData_diameter = zeros(nPorts);
    portsData_height = zeros(nPorts);
    portsData_zeta_in = zeros(nPorts);
    portsData_zeta_out = zeros(nPorts);
  end if;

  // =======================================================================
  // 端口状态与偏微分方程的实体化装配
  // =======================================================================
  for i in 1:nPorts loop
    // 基于迎风格式（inStream）计算端口处流体的真实密度
    portInDensities[i] = Medium.density(Medium.setState_phX(vessel_ps_static[i], inStream(ports[i].h_outflow), inStream(ports[i].Xi_outflow)));

    if use_portsData then
      // 动压计算：dp = 0.5 * zeta * density * v * |v|
      // 注意：为了避免端口压力（ports.p）产生代数环死锁，这里强制使用容器内静压（vessel_ps_static）来计算流速
      portVelocities[i] = smooth(0, ports[i].m_flow/portAreas[i]/Medium.density(Medium.setState_phX(vessel_ps_static[i], actualStream(ports[i].h_outflow), actualStream(ports[i].Xi_outflow))));

      // 【绝对连续性数学黑魔法】：利用 regStep 将液位的淹没过程平滑化。即使容器快空了，浸没度也不会直接变成绝对的0，防止除零。
      ports_penetration[i] = Utilities.regStep(fluidLevel - portsData_height[i] - 0.1*portsData_diameter[i], 1, 1e-3, 0.1*portsData_diameter[i]);

      m_flow_turbulent[i]=if not use_Re then m_flow_small else 
        max(m_flow_small, (Modelica.Constants.pi/8)*portsData_diameter[i]
                           *(Medium.dynamicViscosity(Medium.setState_phX(vessel_ps_static[i], inStream(ports[i].h_outflow), inStream(ports[i].Xi_outflow)))
                             + Medium.dynamicViscosity(medium.state))*Re_turbulent);
    else
      // 如果忽略阻力，假定端口直径无限大，流速绝对为0，永远处于100%淹没状态
      portVelocities[i] = 0;
      ports_penetration[i] = 1;
      m_flow_turbulent[i] = Modelica.Constants.inf;
    end if;

    // =======================================================================
    // 穿过端口的流体动力学判别：
    // 极其复杂的逻辑树，用于模拟单向阀效应。比如液位低于端口时，不允许液体流出，但允许外部向内喷射。
    // =======================================================================
    regularFlow[i] = fluidLevel >= portsData_height[i];
    inFlow[i]      = not regularFlow[i] and (s[i] > 0 or portsData_height[i] >= fluidLevel_max);

    if regularFlow[i] then
      // 【常规工况】：当前液位高于该端口位置（端口被液体淹没）
      if use_portsData then
        // 【核心压降方程】：利用高阶函数 Utilities.regSquare2 计算带正则化平滑的二次方阻力。
        // 内部综合考虑了流入阻力 (zeta_in)、流出阻力 (zeta_out)、容器与管道的截面突变面积比 (portAreas/vesselArea) 以及端口浸没度。
        ports[i].p = vessel_ps_static[i] + (0.5/portAreas[i]^2*Utilities.regSquare2(ports[i].m_flow, m_flow_turbulent[i],
                          (portsData_zeta_in[i] - 1 + portAreas[i]^2/vesselArea^2)/portInDensities[i]*ports_penetration[i],
                          (portsData_zeta_out[i] + 1 - portAreas[i]^2/vesselArea^2)/medium.d/ports_penetration[i]));
      else
        // 忽略阻力时，外部法兰压力直接等于内部静压
        ports[i].p = vessel_ps_static[i];
      end if;
      s[i] = fluidLevel - portsData_height[i];

    elseif inFlow[i] then
      // 【喷射工况】：端口高于液位，但外部压力大，流体像瀑布一样喷入容器
      ports[i].p = vessel_ps_static[i];
      s[i] = ports[i].m_flow;

    else
      // 【抽空截断工况】：端口高于液位，且内部试图向外流出。强制截断流量！充当绝对的单向阀！
      ports[i].m_flow = 0;
      s[i] = (ports[i].p - vessel_ps_static[i])/Medium.p_default*(portsData_height[i] - fluidLevel);
    end if;

    // =======================================================================
    // 流出属性赋值与能量追踪
    // =======================================================================
    ports[i].h_outflow  = medium.h;
    ports[i].Xi_outflow = medium.Xi;
    ports[i].C_outflow  = C;

    ports_H_flow[i] = ports[i].m_flow * actualStream(ports[i].h_outflow)
    "绝对焓流";

    // 【动能与势能方程】：质量流量 * ( 0.5 * V^2 + mgh )
    ports_E_flow[i] = ports[i].m_flow*(0.5*portVelocities[i]*portVelocities[i] + system.g*portsData_height[i])
    "流入/流出的动能与重力势能总和";

    ports_mXi_flow[i,:] = ports[i].m_flow * actualStream(ports[i].Xi_outflow)
    "组分质量流";
    ports_mC_flow[i,:]  = ports[i].m_flow * actualStream(ports[i].C_outflow)
    "痕量物质质量流";
  end for;

  // 数组求和处理
  for i in 1:Medium.nXi loop
    sum_ports_mXi_flow[i] = sum(ports_mXi_flow[:,i]);
  end for;

  for i in 1:Medium.nC loop
    sum_ports_mC_flow[i]  = sum(ports_mC_flow[:,i]);
  end for;

  // 热传导法兰连线
  connect(heatPort, heatTransfer.heatPorts[1]) annotation (Line(
      points={{-100,0},{-87,0},{-87,0},{-74,0}}, color={191,0,0}));

  // =======================================================================
  // 官方说明文档 (全面汉化)
  // =======================================================================
  annotation (
   Documentation(info="<html>
<p>
本基类在 <code>PartialLumpedVolume</code> 的基础上，扩展了一个流体交互端口阵列（Vector of fluid ports）以及一个可替换的壁面传热代理模型。
</p>
<p>
基于以下工程假设进行建模：</p>
<ul>
<li>内部介质完全均匀混合（即：默认不考虑空间上的气液相分离），</li>
<li>流体在容器主体内不携带动能，所有射入的动能都会彻底耗散转化为内部热能（内能），</li>
<li>在计算各个端口的局部压降时，强制将其假设为不可压缩流体（简化密度动态变化），</li>
<li>每个端口都自带极其严苛的<b>单向阀防漏逻辑</b>：不允许环境介质反向抽出。<br>
    如果 <code>当前液位 (fluidlevel) &lt; 端口高度 (portsData_height[i])</code> 并且 <code>外部背压 (ports[i].p) &lt; 容器内静压 (vessel_ps_static[i])</code>，模型将强行把该端口的质量流量截断至 0（防止气抽空或液漏光）。</li>
</ul>
<p>
你可以通过配置 <strong><code>portsData</code></strong> 数据包，为每一个端口单独设定水力学直径（Hydraulic diameter）和距离容器底部的相对安装高度。<br>
如果在方案设计的初期，你可以直接设置 <code>use_portsData=false</code> 来忽略这些繁琐的几何影响。这在数学等效上，意味着假设容器底部开了一个无限大的洞口。此时，动能、势能、湍流压降等一切非线性耗散项都将被关闭。
</p>
<p>
继承此基类的上层子类（如储液罐/气液分离器），必须自行定义以下物理量：
</p>
<ul>
<li><code>input fluidVolume</code>, 当前容器内流体实际占据的体积，</li>
<li><code>vessel_ps_static[nPorts]</code>, 针对每一个安装高度，容器内部流速为0时的真实绝对静压（通常要加上 $\rho g h$ 的液柱压力修正），以及</li>
<li><code>Wb_flow</code>, 能量守恒方程中的机械做功项，例如如果是活塞压缩机则是 p*der(V)，如果是带搅拌器的反应釜则是搅拌轴功率。</li>
</ul>
<p>
强烈建议上层子类定义以下几何基准：
</p>
<ul>
<li><code>parameter vesselArea</code>（默认无限大），容器自身的横截面积。它将被用来和各个端口的截面积做比对，利用伯努利方程推算流体喷射时的突扩/突缩动压损失。</li>
</ul>
<p>
如果你需要在此模型基础上开发带真实液位波动的设备（如带有 Sight Glass 的高压储液罐），还必须定义：
</p>
<ul>
<li><code>input fluidLevel</code>（默认 0m），当前流体的真实物理液位高度，</li>
<li><code>parameter fluidLevel_max</code>（默认 1m），物理允许的极限最高液位（用于防止数值爆炸的顶板）。</li>
</ul>
<p>
<strong>防爆开发警告：</strong><br>
派生模型绝不能直接调用 UI 界面里输入的 <code>portsData</code> 记录。因为一旦用户在界面上关闭了阻力计算（<code>use_portsData=false</code>）或者连接端口数为零（<code>nPorts=0</code>），直接调用这个空数据结构将导致编译器引发维度崩溃。<br>
正确的做法是，在你的代码中一律使用本基类保护作用域（protected）下预先过滤好的安全变量，例如：
<code>portsData_diameter[nPorts]</code> 等。
</p>
</html>",       revisions="<html>
<ul>
<li><em>2009年1月</em> 由 R&uuml;diger Franke 编写: 扩展了 portsData 记录并引入了端口安装高度逻辑，将进出口流体的动能和势能严谨地编织进了总能量守恒方程中。</li>
<li><em>2008年12月</em> 由 R&uuml;diger Franke 编写: 基于 OpenTank 衍生而来，实现了管径阻力自适应。</li>
</ul>
</html>"),Icon(coordinateSystem(preserveAspectRatio=true,  extent={{-100,-100},
          {100,100}}), graphics={Text(
        extent={{-150,110},{150,150}},
        textString="%name",
        textColor={0,0,255})}));
end PartialLumpedVessel;