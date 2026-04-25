model MassFlowSource_h "理想质量流量源_h (强加流量与比焓，相变区专用推进器)"

  import Modelica.Media.Interfaces.Choices.IndependentVariables;
  // 继承底层流动源基类
  extends Sources.BaseClasses.PartialFlowSource;

  // =======================================================================
  // 1. 外部控制信号使能开关 (条件引脚魔法)
  // =======================================================================
  parameter Boolean use_m_flow_in = false
    "= true 时，激活质量流量输入引脚 (允许外部动态信号控制)" 
    annotation(Evaluate=true, HideResult=true, choices(checkBox=true));

  parameter Boolean use_h_in= false
    "= true 时，激活比焓输入引脚 (极其适合动态改变流体干度或能量输入)" 
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
    "固定的流出质量流量 (向外流出为正)" 
    annotation (Dialog(enable = not use_m_flow_in));

  parameter Medium.SpecificEnthalpy h = Medium.h_default
    "固定的流出比热力学焓" 
    annotation (Dialog(enable = not use_h_in));

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
    annotation (Placement(transformation(extent={{-120,60},{-80,100}})));

  Modelica.Blocks.Interfaces.RealInput h_in(unit="J/kg") if use_h_in
    "外部动态控制的比焓信号引脚" 
    annotation (Placement(transformation(extent={{-140,20},{-100,60}}), iconTransformation(extent={{-140,20},{-100,60}})));

  Modelica.Blocks.Interfaces.RealInput X_in[Medium.nX](each unit="1") if use_X_in
    "外部动态控制的组分信号引脚" 
    annotation (Placement(transformation(extent={{-140,-60},{-100,-20}})));

  Modelica.Blocks.Interfaces.RealInput C_in[Medium.nC] if use_C_in
    "外部动态控制的痕量物质信号引脚" 
    annotation (Placement(transformation(extent={{-120,-100},{-80,-60}}), iconTransformation(extent={{-120,-100},{-80,-60}})));

protected
  // =======================================================================
  // 4. 内部数据中转站
  // =======================================================================
  Modelica.Blocks.Interfaces.RealInput m_flow_in_internal(unit="kg/s") "条件端口内部连接中转站";
  Modelica.Blocks.Interfaces.RealInput h_in_internal(unit="J/kg") "条件端口内部连接中转站";
  Modelica.Blocks.Interfaces.RealInput X_in_internal[Medium.nX](each unit="1") "条件端口内部连接中转站";
  Modelica.Blocks.Interfaces.RealInput C_in_internal[Medium.nC] "条件端口内部连接中转站";

equation
  .Modelica.Fluid.Utilities.checkBoundary(Medium.mediumName, Medium.substanceNames, Medium.singleState, true, X_in_internal, "MassFlowSource_h");

  connect(m_flow_in, m_flow_in_internal);
  connect(h_in, h_in_internal);
  connect(X_in, X_in_internal);
  connect(C_in, C_in_internal);

  if not use_m_flow_in then
    m_flow_in_internal = m_flow;
  end if;
  if not use_h_in then
    h_in_internal = h;
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
     // 【相变提速逻辑】：如果是 ph 独立变量库，直接赋予比焓，完全跳过由 T 反算 h 的耗时迭代！
     medium.h = h_in_internal;
  else
     // 读取下游管网的真实背压 medium.p，结合比焓反算温度
     medium.T = Medium.temperature(Medium.setState_phX(medium.p, h_in_internal, X_in_internal));
  end if;

  // 强加总质量流量
  sum(ports.m_flow) = -m_flow_in_internal;

  medium.Xi = X_in_internal[1:Medium.nXi];
  ports.C_outflow = fill(C_in_internal, nPorts);

  // =======================================================================
  // 图形注解与官方说明文档 (修复了官方文档笔误)
  // =======================================================================
  annotation (defaultComponentName="boundary",
    Icon(coordinateSystem(preserveAspectRatio=false, extent={{-100,-100},{100,100}}), graphics={
        Rectangle(extent={{36,45},{100,-45}}, fillPattern=FillPattern.HorizontalCylinder, fillColor={0,127,255}),
        Ellipse(extent={{-100,80},{60,-80}}, lineColor={0,0,255}, fillColor={255,255,255}, fillPattern=FillPattern.Solid),
        Polygon(points={{-60,70},{60,0},{-60,-68},{-60,70}}, lineColor={0,0,255}, fillColor={0,0,255}, fillPattern=FillPattern.Solid),
        Text(extent={{-54,32},{16,-30}}, textColor={255,0,0}, textString="m"),
        Ellipse(extent={{-26,30},{-18,22}}, lineColor={255,0,0}, fillColor={255,0,0}, fillPattern=FillPattern.Solid),
        Text(visible=use_m_flow_in, extent={{-185,132},{-45,100}}, textString="m_flow"),
        Text(visible=use_h_in, extent={{-113,72},{-73,38}}, textString="h"),
        Text(visible=use_X_in, extent={{-153,-44},{-33,-72}}, textString="X"),
        Text(visible=use_X_in, extent={{-155,-98},{-35,-126}}, textString="C"),
        Text(extent={{-150,110},{150,150}}, textString="%name", textColor={0,0,255})}),
    Documentation(info="<html>
<p>
本组件模拟了一个<strong>理想的质量流量源</strong>，专门针对<strong>两相区相变</strong>或能量精准控制场景。它可以向系统输出强制指定的：
</p>
<ul>
<li> 强加质量流量。</li>
<li> <strong>强加排出流体比焓。</strong> (用比焓代替温度，精准控制气液两相混合物的能量状态)</li>
<li> 强加排出组分。</li>
</ul>
<p>如果 <code>use_m_flow_in</code> 为 false（默认选项），参数 <code>m_flow</code> 将被用作固定的流出量；如果激活该参数，将无视固定值，转而使用外部引脚输入的实时信号。</p>
<p>比焓、组分等变量的控制逻辑与流量完全一致。</p>
<p>
<strong>⚠️ 核心注意点：</strong><br>
你设定的 <strong>比焓和组分</strong> 等属性，<strong>仅仅</strong> 在流体从该流量源 <strong>推入</strong> 你的系统时才起作用。如果系统发生倒流，除了设定的流量值依然生效外（变成抽水机），其排出的温度/比焓设定将被忽略，转为接受管网温度。
</p>
</html>"));
end MassFlowSource_h;