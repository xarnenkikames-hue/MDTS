model ValveDiscreteRamp "带有离散开度信号与斜坡开启特性的水/蒸汽线性压降阀 (防水击神器)"
  extends Modelica.Fluid.Interfaces.PartialTwoPortTransport;
  import SI = Modelica.SIunits;
  import Types = Modelica.Fluid.Types;
  // =====================================================================
  // 1. 标称工作点与线性流导参数
  // =====================================================================
  parameter SI.AbsolutePressure dp_nominal
    "全开状态下的额定压降" 
    annotation(Dialog(group="Nominal operating point"));

  parameter Medium.MassFlowRate m_flow_nominal
    "全开状态下的额定质量流量";

  parameter Real opening_min(min=0)=0
    "关闭状态下的残余等效开度，用于产生微小的泄漏流量以防止数值计算死机";

  final parameter Types.HydraulicConductance k = m_flow_nominal/dp_nominal
    "全开状态下的绝对水力流导";

  // =====================================================================
  // 2. 机械动作延时参数 (核心防爆机制)
  // =====================================================================
  parameter SI.Time Topen "阀门从完全关闭到完全开启所需的斜坡时间";
  parameter SI.Time Tclose = Topen "阀门从完全开启到完全关闭所需的斜坡时间 (默认与开启时间相同)";

  // 接收纯布尔开关信号
  Modelica.Blocks.Interfaces.BooleanInput open 
  annotation (Placement(transformation(
        origin={0,80},
        extent={{-20,-20},{20,20}},
        rotation=270)));

  // =====================================================================
  // 3. 梯形波发生器 (机械阻尼模拟器)
  // =====================================================================
  // 它的作用是拦截离散的 open 信号，把它转换成一个在 opening_min 到 1 之间平滑过渡的连续值 y。
  Modelica.Blocks.Logical.TriggeredTrapezoid openingGenerator(
    amplitude=1 - opening_min,
    rising=Topen,
    falling=Tclose,
    offset=opening_min) 
                annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=-90,
        origin={0,30})));

equation
  // =====================================================================
  // 4. 流体方程与信号连线
  // =====================================================================
  // 质量流量 = 梯形波发生器输出的平滑开度 * 流导 * 压差
  m_flow = openingGenerator.y*k*dp;

  // 绝对等焓状态变换 (无能量存储，与外界绝热且无能量损失)
  port_a.h_outflow = inStream(port_b.h_outflow);
  port_b.h_outflow = inStream(port_a.h_outflow);

  // 在代码底层将布尔输入信号 open 连接到梯形波发生器的触发引脚 u 上
  connect(open, openingGenerator.u) annotation (Line(points={{0,80},{0,42},{2.22045e-15,
          42}}, color={255,0,255}));

  // =====================================================================
  // 5. 专属动态图标与官方文档 (中英双语)
  // =====================================================================
  annotation (
  Icon(coordinateSystem(
        preserveAspectRatio=false,
        extent={{-100,-100},{100,100}}), graphics={
        Line(points={{0,50},{0,0}}),
        Rectangle(
          extent={{-20,60},{20,50}},
          fillPattern=FillPattern.Solid),
        Polygon(
          points={{-100,50},{100,-50},{100,50},{0,0},{-100,-50},{-100,50}},
          fillColor=DynamicSelect({255,255,255}, if open then {0,255,0} else {255,255,255}),
          fillPattern=FillPattern.Solid)}),
  Documentation(info="<html>
<p>
本模型与 <a href=\"modelica://Modelica.Fluid.Valves.ValveDiscrete\">ValveDiscrete</a>（离散开关阀）高度相似，唯一的、也是最关键的区别在于：本阀门不会在瞬间完成启闭，而是按照 <code>Topen</code> 时间参数平滑地渐进开启，并按照 <code>Tclose</code> 时间参数平滑地渐进关闭。
</p>
<p>
<b>【工业应用价值】</b>：在仿真系统中使用具有极低压缩性的高精度流体介质模型（例如高压液态水或冷媒）时，如果阀门瞬间关死，极易引发违背物理常理的数值振荡（如瞬间流向反转或无限大的压力尖峰）。引入渐进的机械启闭时间可以完美规避这些非现实的数值灾难。
</p>
</html>",
    revisions="<html>
<ul>
<li><em>2020年3月</em>
    由 Francesco Casella 教授编写 (基于 ValveLinear 和 ValveDiscrete 深度优化)。</li>
</ul>
</html>"));
end ValveDiscreteRamp;