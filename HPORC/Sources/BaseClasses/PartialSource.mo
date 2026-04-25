partial model PartialSource "流体源/边界的抽象基类 (自带动态单流体接口)"
  import Types = Modelica.Fluid.Types;
  import Modelica.Constants;

  // =======================================================================
  // 1. 动态端口阵列设置
  // =======================================================================
  // connectorSizing=true 允许在图形界面连线时自动增加端口数量
  parameter Integer nPorts=0 "对外暴露的流体端口数量" annotation(Dialog(connectorSizing=true));

  // 强制要求子类定义流体介质
  replaceable package Medium =
      Modelica.Media.Interfaces.PartialMedium
      "流体源内部的工质模型" 
     annotation (choicesAllMatching=true);

  // 声明内部流体介质的基础属性 (压力、比焓等都在这里面)
  Medium.BaseProperties medium "流体源内部的热力学状态";

  // =======================================================================
  // 2. 带有流向保护机制的对外接口
  // =======================================================================
  Interfaces.FluidPorts_b ports[nPorts](
                     redeclare each package Medium = Medium,
                     // 极其严密的流向物理边界保护：
                     // 如果设定了只能“流出(Leaving)”，则最大流量被死死锁在 0 (不能倒流吸水)
                     m_flow(each max=if flowDirection==Types.PortFlowDirection.Leaving then 0 else 
                                     +Constants.inf,
                            // 如果设定了只能“流入(Entering)”，则最小流量被死死锁在 0 (不能向外排水)
                            each min=if flowDirection==Types.PortFlowDirection.Entering then 0 else 
                                     -Constants.inf)) 
    annotation (Placement(transformation(extent={{90,40},{110,-40}})));

protected
  // 默认允许流体双向流动 (Bidirectional)，也可在子类的高级选项中锁死单向
  parameter Types.PortFlowDirection flowDirection=
                   Types.PortFlowDirection.Bidirectional
      "允许的流体流动方向" annotation(Evaluate=true, Dialog(tab="高级设置"));

equation
  // =======================================================================
  // 3. 拓扑安全检查与物理状态映射
  // =======================================================================
  for i in 1:nPorts loop

    // 【核心防呆机制】：严禁单个端口被多次连接，以防止产生意料之外的流体理想混合
    assert(cardinality(ports[i]) <= 1,"
严重拓扑错误：边界的每一个端口 ports[i] 最多只能连接到一个外部组件！
如果在此端口上存在两个或更多的连接，系统底层将自动在这些连接之间发生理想混合 (Ideal Mixing)，
这通常绝对不是建模者的本意。
修复方案：如果你需要连接多根管道，请直接增加该边界组件的 nPorts (端口数量) 参数！
");

     // 【绝对的物理统治力】：将内部的热力学状态强加给所有对外端口
     ports[i].p          = medium.p;
     ports[i].h_outflow  = medium.h;
     ports[i].Xi_outflow = medium.Xi;
  end for;

  // =======================================================================
  // 图形注解与官方汉化说明文档
  // =======================================================================
  annotation (defaultComponentName="boundary", Documentation(info="<html>
<p>
这是一个抽象基础模型，用于构建<strong>流体源 (Source)</strong> 组件（如质量流量源、压力边界等）的<strong>体积接口</strong>。它的核心物理特征包括：
</p>
<ul>
<li> 强加压力：连接端口的压力 (<code>ports.p</code>) 绝对等于流体源内部定义的压力。</li>
<li> 强加流出属性：端口的流出比焓率 (<code>port.h_outflow</code>) 以及物质的组分浓度 (<code>port.Xi_outflow</code>) 绝对等于源内部的对应设定值。</li>
</ul>
</html>"));
end PartialSource;