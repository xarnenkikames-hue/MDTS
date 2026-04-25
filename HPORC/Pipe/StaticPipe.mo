model StaticPipe "基础静态直管模型 (无任何质量或能量的动态储能)"
  import Types = Modelica.Fluid.Types;

  // 继承直管的基础几何参数 (包含 length, crossArea, perimeter, roughness, height_ab 等)
  extends PartialStraightPipe;

  // =======================================================================
  // 1. 初始化设定 (为代数方程提供求解起点)
  // =======================================================================
  parameter Medium.AbsolutePressure p_a_start=system.p_start
    "端口 a (入口) 的压力初始猜测值" 
    annotation(Dialog(tab = "初始化"));

  parameter Medium.AbsolutePressure p_b_start=p_a_start
    "端口 b (出口) 的压力初始猜测值" 
    annotation(Dialog(tab = "初始化"));

  parameter Medium.MassFlowRate m_flow_start = system.m_flow_start
    "质量流量的初始猜测值" 
     annotation(Evaluate=true, Dialog(tab = "初始化"));

  // =======================================================================
  // 2. 动量与压降的核心计算黑盒 (FlowModel)
  // =======================================================================
  FlowModel flowModel(
          redeclare final package Medium = Medium,
          final n=2, // 定义两个热力学状态节点 (入口和出口)
          // 抓取并设定两端端口的热力学状态 (压力、比焓、组分)
          states={Medium.setState_phX(port_a.p, inStream(port_a.h_outflow), inStream(port_a.Xi_outflow)),
                  Medium.setState_phX(port_b.p, inStream(port_b.h_outflow), inStream(port_b.Xi_outflow))},
          // 根据流量和密度，计算两端的流速 v = m_flow / (rho * A)
          vs={port_a.m_flow/Medium.density(flowModel.states[1])/flowModel.crossAreas[1],
              -port_b.m_flow/Medium.density(flowModel.states[2])/flowModel.crossAreas[2]}/nParallel,
          // 强制设定动量方程为稳态 (没有流体加速带来的惯性力)
          final momentumDynamics=Types.Dynamics.SteadyState,
          final allowFlowReversal=allowFlowReversal,
          final p_a_start=p_a_start,
          final p_b_start=p_b_start,
          final m_flow_start=m_flow_start,
          final nParallel=nParallel,
          final pathLengths={length},
          final crossAreas={crossArea, crossArea},
          final dimensions={4*crossArea/perimeter, 4*crossArea/perimeter}, // 水力直径 = 4A/P
          final roughnesses={roughness, roughness},
          final dheights={height_ab},
          final g=system.g) "压降与摩擦力计算模型" 
     annotation (Placement(transformation(extent={{-38,-18},{38,18}})));

equation
  // =======================================================================
  // 3. 质量与组分平衡 (纯净的稳态传递)
  // =======================================================================
  // 内部流量模型的流量等于端口 a 的流量
  port_a.m_flow = flowModel.m_flows[1];

  // 绝对稳态质量守恒：流入 + 流出 = 0 (进去多少瞬间出来多少)
  0 = port_a.m_flow + port_b.m_flow;

  // 组分和痕量物质的迎风传递 (完全无损耗透传)
  port_a.Xi_outflow = inStream(port_b.Xi_outflow);
  port_b.Xi_outflow = inStream(port_a.Xi_outflow);
  port_a.C_outflow = inStream(port_b.C_outflow);
  port_b.C_outflow = inStream(port_a.C_outflow);

  // =======================================================================
  // 4. 能量平衡 (极其经典的推导：只考虑重力势能变化)
  // =======================================================================
  // 【官方硬核物理推导】：
  // 机械功流 Wb_flow = v * A * (流体压差 dpdx) + v * (摩擦力 F_fric)
  //          将压差展开 = m_flow/d/A * ( A*dpdx + A*pressureLoss.dp_fg - 纵向重力 F_grav )
  //          由于稳态流动中摩擦压降刚好被流体内能吸收，两者抵消，只剩下重力项！
  //          = m_flow/d/A * (-A * g * height_ab * d)
  //          = -m_flow * g * height_ab

  // 结论：出口的流体比焓，仅仅等于入口流体的比焓 减去 克服高差所做的重力势能功！
  port_b.h_outflow = inStream(port_a.h_outflow) - system.g*height_ab;
  port_a.h_outflow = inStream(port_b.h_outflow) + system.g*height_ab;

  // =======================================================================
  // 图形注解与官方汉化警告文档
  // =======================================================================
  annotation (defaultComponentName="pipe",
Documentation(info="<html>
<p>这是一个横截面积恒定的静态直管模型。它采用<strong>绝对稳态</strong>的质量、动量和能量平衡，即：<strong>该模型内部无法储存任何质量或能量。</strong>
在流体连接的两个端口分别存在一个热力学状态。该模型通过计算动量流、壁面摩擦力和重力，为这两个状态构建了稳态的动量平衡方程。
如果您使用 <code>DynamicPipe</code> 并将其所有的动态选项均设为“稳态”，将得到完全相同的结果。
本模型的预期用途是：<strong>为那些自带储能容积的设备（如水箱、换热器）提供极其简单快速的连接</strong>，具体的应用案例可参考：
</p>
<ul>
<li><a href=\"modelica://Modelica.Fluid.Examples.Tanks.EmptyTanks\">Examples.Tanks.EmptyTanks</a></li>
<li><a href=\"modelica://Modelica.Fluid.Examples.InverseParameterization\">Examples.InverseParameterization</a></li>
</ul>
<h4>⚠️ 数值计算隐患警告 (Numerical Issues)</h4>
<p>
通过 Stream (流束) 连接器，端口上的热力学状态通常是由放置在该静态管道上游和下游的“带有储能容积的模型”或“边界源”来定义的。
流道中其他没有储能的组件可能会引发状态转换。
请极其注意：<strong>如果您将多个静态管道 (StaticPipe)，或其他没有任何储能的流动模型“直接串联”在一起，这必然会导致产生极其庞大且复杂的非线性代数方程组 (Nonlinear Equation Systems)，极大概率会导致求解器迭代失败或仿真卡顿！</strong>
(永远遵循：容积—管道—容积 的拓扑连接原则)
</p>
</html>"));
end StaticPipe;