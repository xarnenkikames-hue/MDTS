partial model PartialTwoPort "双端口流体组件绝对基类 (万物起源)"

  import Modelica.Constants;

  // 引入全局系统环境 (定义了重力、环境压力、默认初值等宇宙法则)
  outer System system "全局系统属性";

  // 【核心血统】：要求所有子代必须拥有一个工质插槽
  replaceable package Medium =
      Modelica.Media.Interfaces.PartialMedium "组件内部流淌的流体工质" 
      annotation (choicesAllMatching = true);

  // 【流向铁律】：是否允许流体反向流动
  parameter Boolean allowFlowReversal = system.allowFlowReversal
    "= true 时允许流体反向流动；= false 时严格限制流体只能按设计方向 (port_a -> port_b) 流动" 
    annotation(Dialog(tab="模型假设"), Evaluate=true);

  // =======================================================================
  // 流体物理接口 (严格限制了非法流量的数学边界)
  // =======================================================================
  Interfaces.FluidPort_a port_a(
                                redeclare package Medium = Medium,
                     m_flow(min=if allowFlowReversal then -Constants.inf else 0))
    "流体接口 a (设计的正向流动方向为从 port_a 流向 port_b)" 
    annotation (Placement(transformation(extent={{-110,-10},{-90,10}})));

  Interfaces.FluidPort_b port_b(
                                redeclare package Medium = Medium,
                     m_flow(max=if allowFlowReversal then +Constants.inf else 0))
    "流体接口 b (设计的正向流动方向为从 port_a 流向 port_b)" 
    annotation (Placement(transformation(extent={{110,-10},{90,10}}), iconTransformation(extent={{110,-10},{90,10}})));

protected
  // =======================================================================
  // 内部模型拓扑结构 (用于极其关键的可视化，防止 DAE 死锁)
  // =======================================================================
  parameter Boolean port_a_exposesState = false
    "= true 如果 port_a 对外暴露了一个流体体积状态 (即该端口是个水箱)";
  parameter Boolean port_b_exposesState = false
    "= true 如果 port_b.p 对外暴露了一个流体体积状态 (即该端口是个水箱)";

  parameter Boolean showDesignFlowDirection = true
    "= false 时在模型图标中隐藏表示流向的箭头";

  // =======================================================================
  // 图形 UI 与官方汉化文档
  // =======================================================================
  annotation (
    Documentation(info="<html>
<p>
本抽象基类定义了所有双端口流体组件的<strong>公共底层接口</strong>。
设计流向和流体反转行为的数学处理，均基于参数 <code><strong>allowFlowReversal</strong></code> 进行了预定义。
继承本类的组件可以传输流体，也可以为指定的流体 <code><strong>Medium</strong></code> 提供内部储存（质量与能量守恒）。
</p>
<p>
<strong>⚠️ 模型架构规范：</strong><br>
如果一个继承本类的子模型，允许外部通过 port_a 或 port_b 直接访问其内部的质量或能量储能（即体积节点/水箱），
该子模型<strong>必须</strong>适当地将保护参数 <code><strong>port_a_exposesState</strong></code> 和 <code><strong>port_b_exposesState</strong></code> 重定义为 <code>true</code>。<br>
此属性将在组件端口图标上以实心半圆的视觉形式呈现，这对于理解复杂流体网络图的拓扑结构（以及规避高指数 DAE 死锁）具有极大的帮助。
</p>
</html>"),
    Icon(coordinateSystem(
          preserveAspectRatio=true,
          extent={{-100,-100},{100,100}}), graphics={
        // 绘制代表设计流向的实心箭头
        Polygon(
          points={{20,-70},{60,-85},{20,-100},{20,-70}},
          lineColor={0,128,255},
          fillColor={0,128,255},
          fillPattern=FillPattern.Solid,
          visible=showDesignFlowDirection),
        // 如果允许反向流动，绘制代表反向的空心箭头
        Polygon(
          points={{20,-75},{50,-85},{20,-95},{20,-75}},
          lineColor={255,255,255},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid,
          visible=allowFlowReversal),
        Line(
          points={{55,-85},{-60,-85}},
          color={0,128,255},
          visible=showDesignFlowDirection),
        Text(
          extent={{-149,-114},{151,-154}},
          textColor={0,0,255},
          textString="%name"),
        // DAE 死锁预警 UI：当暴露体积状态时，在端口画一个实心半圆
        Ellipse(
          extent={{-110,26},{-90,-24}},
          fillPattern=FillPattern.Solid,
          visible=port_a_exposesState),
        Ellipse(
          extent={{90,25},{110,-25}},
          fillPattern=FillPattern.Solid,
          visible=port_b_exposesState)}));
end PartialTwoPort;