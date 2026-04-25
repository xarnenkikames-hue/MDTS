partial connector HeatPort "一维传热的热端口基类 (Thermal port for 1-dim. heat transfer)"
  import SI = Modelica.SIunits;
  // 1. 跨越变量 (Across Variable / 势变量)
  // 在热力学中，温度差是驱动热量流动的“势能”。当多个 HeatPort 连接在一起时，
  // 求解器会自动强加等式：T1 = T2 = T3... (即所有连接在一起的节点，温度瞬间拉平相等)
  SI.Temperature T "端口处的绝对温度 (Port temperature)";

  // 2. 穿越变量 (Through Variable / 流变量)
  // 关键字 'flow' 是 Modelica 物理守恒的灵魂！它告诉求解器，这是一个守恒量。
  // 当多个 HeatPort 连接在一个拓扑节点上时，求解器会自动列出基尔霍夫定律方程（能量守恒）：
  // 节点总热流求和为零 (sum(Q_flow) = 0)。
  flow SI.HeatFlowRate Q_flow
    "热流率：规定如果热量从外部流入当前组件，则该数值为正 (Heat flow rate (positive if flowing from outside into the component))";

  // =======================================================================
  // 官方说明文档 (已全面汉化补充)
  // =======================================================================
  annotation (Documentation(info="<html>
<p>
<b>一维热传导端口基类。</b>
</p>
<p>
本接口定义了热力学网络中最基本的两个共轭物理量：
<ul>
<li><b>温度 T (势)</b>：负责在节点连接处建立等势场。</li>
<li><b>热流率 Q_flow (流)</b>：负责在节点连接处执行基尔霍夫能量守恒定律 (Kirchhoff's Current Law for Heat)。</li>
</ul>
</p>
<p>
<b>符号约定 (Sign Convention)：</b><br>
Modelica 全局采用“流入为正”的物理法则。当 <code>Q_flow &gt; 0</code> 时，代表外部的热量正在通过这个端口注入到当前组件的内部微积分方程（dU/dt）中。
</p>
</html>"));
end HeatPort;