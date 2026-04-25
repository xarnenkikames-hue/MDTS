model MassFlowSource_T "理想质量流量源 (强加强制流量与温度，被动接受管网压力)"

  import Modelica.Media.Interfaces.Choices.IndependentVariables;
  // 继承底层流动源基类
  extends Sources.BaseClasses.PartialFlowSource;

  // =======================================================================
  // 1. 外部控制信号使能开关 (条件引脚魔法)
  // =======================================================================
  parameter Boolean use_m_flow_in = false
    "= true 时，激活质量流量输入引脚 (允许由外部信号动态控制流量，例如模拟变频泵)" 
    annotation(Evaluate=true, HideResult=true, choices(checkBox=true));

  parameter Boolean use_T_in= false
    "= true 时，激活温度输入引脚 (允许由外部信号动态控制排出流体的温度)" 
    annotation(Evaluate=true, HideResult=true, choices(checkBox=true));

  parameter Boolean use_X_in = false
    "= true 时，激活组分浓度输入引脚" 
    annotation(Evaluate=true, HideResult=true, choices(checkBox=true));

  parameter Boolean use_C_in = false
    "= true 时，激活痕量物质输入引脚" 
    annotation(Evaluate=true, HideResult=true, choices(checkBox=true));

  // =======================================================================
  // 2. 静态固定参数 (当不使用外部引脚时生效)
  // =======================================================================
  parameter Medium.MassFlowRate m_flow = 0
    "固定的流出质量流量 (注意：向外流出为正值！)" 
    annotation (Dialog(enable = not use_m_flow_in));

  parameter Medium.Temperature T = Medium.T_default
    "固定的流出温度值" 
    annotation (Dialog(enable = not use_T_in));

  parameter Medium.MassFraction X[Medium.nX] = Medium.X_default
    "固定的流出组分质量分数" 
    annotation (Dialog(enable = (not use_X_in) and Medium.nXi > 0));

  parameter Medium.ExtraProperty C[Medium.nC](
       quantity=Medium.extraPropertiesNames) = Medium.C_default
    "固定的流出痕量物质值" 
    annotation (Dialog(enable = (not use_C_in) and Medium.nC > 0));

  // =======================================================================
  // 3. 对外暴露的真实控制引脚
  // =======================================================================
  Modelica.Blocks.Interfaces.RealInput m_flow_in(unit="kg/s") if use_m_flow_in
    "外部动态控制的质量流量信号引脚" 
    annotation (Placement(transformation(extent={{-120,60},{-80,100}}), iconTransformation(extent={{-120,60},{-80,100}})));

  Modelica.Blocks.Interfaces.RealInput T_in(unit="K") if use_T_in
    "外部动态控制的流体温度信号引脚" 
    annotation (Placement(transformation(extent={{-140,20},{-100,60}}), iconTransformation(extent={{-140,20},{-100,60}})));

  Modelica.Blocks.Interfaces.RealInput X_in[Medium.nX](each unit="1") if use_X_in
    "外部动态控制的组分信号引脚" 
    annotation (Placement(transformation(extent={{-140,-60},{-100,-20}})));

  Modelica.Blocks.Interfaces.RealInput C_in[Medium.nC] if use_C_in
    "外部动态控制的痕量物质信号引脚" 
    annotation (Placement(transformation(extent={{-120,-100},{-80,-60}})));

protected
  // =======================================================================
  // 4. 内部数据中转站
  // =======================================================================
  Modelica.Blocks.Interfaces.RealInput m_flow_in_internal(unit="kg/s") "条件端口内部连接中转站";
  Modelica.Blocks.Interfaces.RealInput T_in_internal(unit="K") "条件端口内部连接中转站";
  Modelica.Blocks.Interfaces.RealInput X_in_internal[Medium.nX](each unit="1") "条件端口内部连接中转站";
  Modelica.Blocks.Interfaces.RealInput C_in_internal[Medium.nC] "条件端口内部连接中转站";

equation
  .Modelica.Fluid.Utilities.checkBoundary(Medium.mediumName, Medium.substanceNames, Medium.singleState, true, X_in_internal, "MassFlowSource_T");

  // 信号连接
  connect(m_flow_in, m_flow_in_internal);
  connect(T_in, T_in_internal);
  connect(X_in, X_in_internal);
  connect(C_in, C_in_internal);

  if not use_m_flow_in then
    m_flow_in_internal = m_flow;
  end if;
  if not use_T_in then
    T_in_internal = T;
  end if;
  if not use_X_in then
    X_in_internal = X;
  end if;
  if not use_C_in then
    C_in_internal = C;
  end if;

  // =======================================================================
  // 5. 核心热力学推导与强制流量输出
  // =======================================================================
  if Medium.ThermoStates == IndependentVariables.ph or 
     Medium.ThermoStates == IndependentVariables.phX then
     // 【极其关键】：这里读取的 medium.p 是从下游管网反馈回来的真实背压，然后结合我设定的 T 算出排气比焓
     medium.h = Medium.specificEnthalpy(Medium.setState_pTX(medium.p, T_in_internal, X_in_internal));
  else
     medium.T = T_in_internal;
  end if;

  // 【流量推土机方程】：强制要求从本组件向外排出的总质量流量等于设定的内部值
  sum(ports.m_flow) = -m_flow_in_internal;

  medium.Xi = X_in_internal[1:Medium.nXi];
  ports.C_outflow = fill(C_in_internal, nPorts);

  // =======================================================================
  // 图形注解与官方汉化说明文档
  // =======================================================================
  annotation (defaultComponentName="boundary",
    Icon(coordinateSystem(preserveAspectRatio=true, extent={{-100,-100},{100,100}}), graphics={
        // 图标：带有流向箭头的气缸/水泵形状
        Rectangle(extent={{35,45},{100,-45}}, fillPattern=FillPattern.HorizontalCylinder, fillColor={0,127,255}),
        Ellipse(extent={{-100,80},{60,-80}}, lineColor={0,0,255}, fillColor={255,255,255}, fillPattern=FillPattern.Solid),
        Polygon(points={{-60,70},{60,0},{-60,-68},{-60,70}}, lineColor={0,0,255}, fillColor={0,0,255}, fillPattern=FillPattern.Solid),
        Text(extent={{-54,32},{16,-30}}, textColor={255,0,0}, textString="m"),
        Text(extent={{-150,130},{150,170}}, textString="%name", textColor={0,0,255}),
        Ellipse(extent={{-26,30},{-18,22}}, lineColor={255,0,0}, fillColor={255,0,0}, fillPattern=FillPattern.Solid),
        // 动态引脚标签
        Text(visible=use_m_flow_in, extent={{-185,132},{-45,100}}, textString="m_flow"),
        Text(visible=use_T_in, extent={{-111,71},{-71,37}}, textString="T"),
        Text(visible=use_X_in, extent={{-153,-44},{-33,-72}}, textString="X"),
        Text(visible=use_C_in, extent={{-155,-98},{-35,-126}}, textString="C")}),
    Documentation(info="<html>
<p>
本组件模拟了一个<strong>理想的质量流量源</strong>（你可以把它理解为一个不会受背压影响的理想水泵或压缩机），它可以向系统输出强制指定的：
</p>
<ul>
<li> 强加质量流量 (Mass flow rate)。</li>
<li> 强加排出流体温度。</li>
<li> 强加排出组分。</li>
</ul>
<p>如果 <code>use_m_flow_in</code> 为 false（默认），将使用参数 <code>m_flow</code> 作为恒定输出流量；若为 true，则激活图标左侧的蓝色输入引脚，你可以连接任何动态信号（如正弦波）来实施控制。</p>
<p>温度、组分等变量的控制逻辑与流量完全一致。</p>
<p>
<strong>⚠️ 核心注意点 (压力被动性与流束方向)：</strong><br>
本组件<strong>不强加任何压力</strong>。它所在节点的实际压力完全由下游管网的阻抗决定！<br>
此外，你设定的 <strong>温度和组分</strong> 等属性，<strong>仅仅</strong> 在流体从该流量源 <strong>被推入</strong> 你的系统时才起作用。如果系统压力过大导致流体被压回流量源（即流量变为负值），流量源只能作为接收端，此时设定的温度将失效。
</p>
</html>"));
end MassFlowSource_T;