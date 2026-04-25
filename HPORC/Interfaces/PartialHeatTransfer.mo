partial model PartialHeatTransfer "所有传热模型的通用底层接口 (Common interface for heat transfer models)"
  import SI = Modelica.SIunits;
  // =======================================================================
  // 1. 核心参数与介质包
  // =======================================================================
  replaceable package Medium=Modelica.Media.Interfaces.PartialMedium
    "组件内部流体介质包 (Medium in the component)" 
    annotation(Dialog(tab="Internal Interface",enable=false));

  parameter Integer n=1 "传热切片/容积节点的数量 (Number of heat transfer segments)" 
    // 对于集总容器 (Vessel) 通常 n=1；对于动态管或换热器 (DynamicPipe) 通常 n>1
    annotation(Dialog(tab="Internal Interface",enable=false), Evaluate=true);

  // =======================================================================
  // 2. 传热模型接收的“内部流体输入” (Inputs)
  // =======================================================================
  input Medium.ThermodynamicState[n] states
    "流动切片节点内的实时热力学状态 (包含温度、压力、密度等所有物性)";

  input SI.Area[n] surfaceAreas "各个节点的有效传热面积 (Heat transfer areas)";

  // =======================================================================
  // 3. 传热模型向流体微积分方程输出的“结果” (Outputs)
  // =======================================================================
  output SI.HeatFlowRate[n] Q_flows "计算得出的最终热流率 (Heat flow rates)，将直接注入流体的 dU/dt 能量守恒方程中";

  // =======================================================================
  // 4. 环境热散失参数 (用于模拟保温层漏热)
  // =======================================================================
  parameter Boolean use_k = false
    "= true 时，启用漏热系数 k，用于模拟系统与环境之间的保温隔热层热损失" 
    annotation(Dialog(tab="Internal Interface",enable=false));

  parameter SI.CoefficientOfHeatTransfer k = 0
    "向周围环境漏热的传热系数 (Heat transfer coefficient to ambient)" 
    annotation(Dialog(group="Ambient"),Evaluate=true);

  parameter SI.Temperature T_ambient = system.T_ambient
    "外部环境温度 (默认继承全局系统的环境温度)" 
    annotation(Dialog(group="Ambient"));

  // 获取全局系统环境指针
  outer System system "系统全局物理属性 (System wide properties)";

  // =======================================================================
  // 5. 外部热端口法兰 (连接固体金属壁面)
  // =======================================================================
  Interfaces.HeatPorts_a[n] heatPorts
    "连接到组件外部金属边界的热端口阵列 (Heat port to component boundary)" 
    annotation (Placement(transformation(extent={{-10,60},{10,80}}), iconTransformation(extent={{-20,60},{20,80}})));

  // =======================================================================
  // 6. 提取流体温度
  // =======================================================================
  SI.Temperature[n] Ts = Medium.temperature(states)
    "通过底层物性包，从流体状态中实时提取出的流体内部温度 (Temperatures defined by fluid states)";

equation
  // =======================================================================
  // 核心能量汇总方程
  // =======================================================================
  if use_k then
    // 如果启用了漏热：注入流体的总热量 = 外部金属热端口传进来的热量 + (环境温度 - 金属壁面温度) * 漏热系数 * 面积
    Q_flows = heatPorts.Q_flow + {k*surfaceAreas[i]*(T_ambient - heatPorts[i].T) for i in 1:n};
  else
    // 如果完美保温：注入流体的总热量 严格等于 外部金属热端口传进来的热量
    Q_flows = heatPorts.Q_flow;
  end if;

  // =======================================================================
  // 官方说明文档 (全面汉化)
  // =======================================================================
  annotation (Documentation(info="<html>
<p>
本组件是所有传热模型的通用底层接口。<br>
穿过 n 个流动切片边界的热流率 <code>Q_flows[n]</code>，本质上是以下变量的函数：特定流体介质 <code>Medium</code> 在该切片内的热力学状态 <code>states</code>、传热面积 <code>surfaceAreas[n]</code> 以及金属边界温度 <code>heatPorts[n].T</code>。
</p>
<p>
你可以使用热损失系数 <code>k</code> 来对边界温度 <code>heatPorts.T</code> 与环境温度 <code>T_ambient</code> 之间的隔热/保温层进行建模。
</p>
<p>
<b>开发者须知：</b><br>
任何继承并实现此接口的子模型（比如你之前重构的恒定换热系数模型，或者两相沸腾模型），<b>都必须且只需补充一个方程</b>：即定义流体温度 <code>Ts[n]</code>、边界金属温度 <code>heatPorts[n].T</code> 以及热流率 <code>Q_flows[n]</code> 这三者之间的物理关系（例如牛顿冷却定律）。
</p>
</html>"));
end PartialHeatTransfer;