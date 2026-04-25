partial model PartialFlowSource "局部流量源抽象基类 (专为强制分配流量的组件设计)"

  import Modelica.Constants;
  import Types = Modelica.Fluid.Types;

  // 动态端口生成器
  parameter Integer nPorts=0 "对外接口的数量" annotation(Dialog(connectorSizing=true));

  // 强制要求子类定义流体介质
  replaceable package Medium =
      Modelica.Media.Interfaces.PartialMedium
      "流体源内部的工质模型" 
     annotation (choicesAllMatching=true);

  Medium.BaseProperties medium "流体源内部的热力学状态";

  // =======================================================================
  // 带有流向保护机制的对外接口
  // =======================================================================
  Interfaces.FluidPort_b ports[nPorts](
                     redeclare each package Medium = Medium,
                     // 锁定单向或双向的极限物理边界
                     m_flow(each max=if flowDirection==Types.PortFlowDirection.Leaving then 0 else 
                                     +Constants.inf,
                            each min=if flowDirection==Types.PortFlowDirection.Entering then 0 else 
                                     -Constants.inf)) 
    annotation (Placement(transformation(extent={{90,10},{110,-10}})));

protected
  parameter Types.PortFlowDirection flowDirection=
                   Types.PortFlowDirection.Bidirectional
      "允许的流体流动方向" annotation(Evaluate=true, Dialog(tab="高级设置"));

equation
  // =======================================================================
  // 拓扑安全检查与数学紧箍咒
  // =======================================================================

  // 【神级防呆代码 1】：绝对禁止一个流量源直接向多根存在流量的管道同时供水！
  // 逻辑：如果只有一根管子有流量，总和减去最大值必然为 0。否则说明流量产生了未定义的非法分配。
  assert(abs(sum(abs(ports.m_flow)) - max(abs(ports.m_flow))) <= Modelica.Constants.small,
         "严重物理错误：流量源 (FlowSource) 极其特殊，它仅支持连接一条具有实际流量的管路！若需分流，请在外部连接三通组件 (TeeJunction)。");

  // 【神级防呆代码 2】：严禁流量源空载闭阀运行
  assert(nPorts > 0,
         "数学奇异错误：流量源至少必须连接一个外部端口 (nPorts > 0)，否则被强制推出的流体无处可去，模型矩阵将处于奇异(崩溃)状态。");

  // 【常规防混水机制】：每个对外端口仅限连接一个外部组件
  for i in 1:nPorts loop
    assert(cardinality(ports[i]) <= 1,"
边界的每一个端口 ports[i] 最多只能连接到一个外部组件！
如果在该端口上存在两个或以上的连接，系统底层将自动触发极其危险的理想混合 (Ideal Mixing)。
请直接增加 nPorts 参数来生成新的独立端口。
");

     // 将内部状态强加给所有对外端口
     ports[i].p          = medium.p;
     ports[i].h_outflow  = medium.h;
     ports[i].Xi_outflow = medium.Xi;
  end for;

  // =======================================================================
  // 图形注解与官方说明文档
  // =======================================================================
  annotation (defaultComponentName="boundary", Documentation(info="<html>
<p>
这是一个抽象基础模型，专门用于构建<strong>流量源 (Flow Source)</strong> 组件（例如强加质量流量的理想水泵）的<strong>体积接口</strong>。它的核心特征是：
</p>
<ul>
<li> 压力被动接受：连接端口的压力 (<code>ports.p</code>) 完全取决于下游管网反馈，并反向同步给源内部。</li>
<li> 流出属性强加：端口的流出比焓率 (<code>port.h_outflow</code>) 和物质组分 (<code>port.Xi_outflow</code>) 绝对等于源内部设定的值。</li>
<li> <strong>极其严格的单路输出限制</strong>：防止数学上的欠定方程组崩溃。</li>
</ul>
</html>"));
end PartialFlowSource;