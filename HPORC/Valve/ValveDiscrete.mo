model ValveDiscrete "用于水/蒸汽流动的纯线性离散开关阀 (电磁阀/启停逻辑阀)"
  extends Modelica.Fluid.Interfaces.PartialTwoPortTransport;
  import SI = Modelica.SIunits;
  import Types = Modelica.Fluid.Types;


  // =====================================================================
  // 1. 标称工作点与线性流导参数
  // =====================================================================
  parameter SI.AbsolutePressure dp_nominal
    "全开状态(=1)下的额定压降" 
    annotation(Dialog(group="Nominal operating point"));

  parameter Medium.MassFlowRate m_flow_nominal
    "全开状态(=1)下的额定质量流量";

  // 直接算出绝对线性流导 k
  final parameter Types.HydraulicConductance k = m_flow_nominal/dp_nominal
    "全开状态(=1)下的绝对水力流导";

  // =====================================================================
  // 2. 离散布尔信号输入 (这是与 Continuous 阀门的本质区别)
  // =====================================================================
  Modelica.Blocks.Interfaces.BooleanInput open
  "接受 True(开) 或 False(关) 的纯数字信号" 
  annotation (Placement(transformation(
        origin={0,80},
        extent={{-20,-20},{20,20}},
        rotation=270)));

  // 【架构师批注：微小泄漏流防爆设计】
  // 在流体网络中，如果一条管路被“绝对关死”(流量绝对为 0)，其内部的压力计算往往会失去约束（产生奇异矩阵）。
  // 官方在这里留了一个极其聪明的后门：即使关死，也允许有万分之一的微小泄漏。
  parameter Real opening_min(min=0)=0
    "关闭状态下的残余等效开度，用于产生微小的泄漏流量以维持数值稳定";

// =====================================================================
// 3. 极简离散流体方程
// =====================================================================
equation
  // 【阶跃逻辑】：如果收到 True 信号，直接全量导通 (1*k*dp)；否则切换到微小泄漏模式 (opening_min*k*dp)
  m_flow = if open then 1*k*dp else opening_min*k*dp;

  // 绝对等焓状态变换 (无能量存储，与外界绝热且无能量损失)
  port_a.h_outflow = inStream(port_b.h_outflow);
  port_b.h_outflow = inStream(port_a.h_outflow);

// =====================================================================
// 4. 专属动态图标与官方文档 (中英双语)
// =====================================================================
annotation (
  Icon(coordinateSystem(
        preserveAspectRatio=false,
        extent={{-100,-100},{100,100}}), graphics={
        Line(points={{0,50},{0,0}}),
        Rectangle(
          extent={{-20,60},{20,50}},
          fillPattern=FillPattern.Solid),
        // 【动态UI魔法】：当 open 信号为 True 时，阀门实体会瞬间变成绿色！
        Polygon(
          points={{-100,50},{100,-50},{100,50},{0,0},{-100,-50},{-100,50}},
          fillColor=DynamicSelect({255,255,255}, if open then {0,255,0} else {255,255,255}),
          fillPattern=FillPattern.Solid)}),
  Documentation(info="<html>
<p>
这个极简模型提供了一个（微小的）压降，如果布尔输入信号 <code>open</code> 为 <strong>true</strong>，则压降与流量成正比。否则，质量流量为零。如果 <code>opening_min > 0</code>，当阀门关闭（open = <strong>false</strong>）时，会产生一股微小的泄漏质量流量以保证系统求解的鲁棒性。
</p>
<p>
当你在进行系统级仿真时，如果阀门开启时的精确压力损失并不是研究重点，此模型可用于对<b>开关阀 (on-off valves)</b> 进行极度简化的建模。尽管该模型并没有利用介质模型(Medium model)的物性来计算压损，但依然必须指定介质模型，以便流体端口能与其他组件匹配连接。
</p>
<p>本模型是绝热的（不会向环境散失热量），并且忽略了流体从入口到出口的动能变化。</p>
<p>
在图形化仿真动画中，当阀门处于开启状态时，会显示为“绿色”。
</p>
</html>",
    revisions="<html>
<ul>
<li><em>2005年11月</em>
    由 Katja Poschlad 编写 (基于 ValveLinear 修改)。</li>
</ul>
</html>"));
end ValveDiscrete;