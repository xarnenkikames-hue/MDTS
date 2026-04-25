model Boundary_ph "带信号输入接口的压力与比焓流体边界 (无限大环境，两相区相变专用)"

  import Modelica.Media.Interfaces.Choices.IndependentVariables;
  // 继承底层纯流体源基类
  extends Sources.BaseClasses.PartialSource;

  // =======================================================================
  // 1. 外部控制信号使能开关 (条件引脚)
  // =======================================================================
  parameter Boolean use_p_in = false
    "= true 时，激活压力输入引脚 (允许由外部信号动态控制边界压力)" 
    annotation(Evaluate=true, HideResult=true, choices(checkBox=true));

  parameter Boolean use_h_in= false
    "= true 时，激活比焓输入引脚 (允许由外部信号动态控制边界比焓，极大方便两相区控制)" 
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
  parameter Medium.AbsolutePressure p = Medium.p_default
    "固定的边界绝对压力值 (仅当 use_p_in = false 时有效)" 
    annotation (Dialog(enable = not use_p_in));

  parameter Medium.SpecificEnthalpy h = Medium.h_default
    "固定的边界比热力学焓 (仅当 use_h_in = false 时有效)" 
    annotation (Dialog(enable = not use_h_in));

  parameter Medium.MassFraction X[Medium.nX] = Medium.X_default
    "固定的边界组分质量分数" 
    annotation (Dialog(enable = (not use_X_in) and Medium.nXi > 0));

  parameter Medium.ExtraProperty C[Medium.nC](
       quantity=Medium.extraPropertiesNames) = Medium.C_default
    "固定的边界痕量物质值" 
    annotation (Dialog(enable = (not use_C_in) and Medium.nC > 0));

  // =======================================================================
  // 3. 对外暴露的真实控制引脚
  // =======================================================================
  Modelica.Blocks.Interfaces.RealInput p_in(unit="Pa") if use_p_in
    "外部动态控制的边界压力信号引脚" 
    annotation (Placement(transformation(extent={{-140,60},{-100,100}})));

  Modelica.Blocks.Interfaces.RealInput h_in(unit="J/kg") if use_h_in
    "外部动态控制的边界比焓信号引脚 (直接控制流体能量状态)" 
    annotation (Placement(transformation(extent={{-140,20},{-100,60}})));

  Modelica.Blocks.Interfaces.RealInput X_in[Medium.nX](each unit="1") if use_X_in
    "外部动态控制的边界组分信号引脚" 
    annotation (Placement(transformation(extent={{-140,-60},{-100,-20}})));

  Modelica.Blocks.Interfaces.RealInput C_in[Medium.nC] if use_C_in
    "外部动态控制的边界痕量物质信号引脚" 
    annotation (Placement(transformation(extent={{-140,-100},{-100,-60}})));

protected
  Modelica.Blocks.Interfaces.RealInput p_in_internal(unit="Pa") "条件端口内部连接中转站";
  Modelica.Blocks.Interfaces.RealInput h_in_internal(unit="J/kg") "条件端口内部连接中转站";
  Modelica.Blocks.Interfaces.RealInput X_in_internal[Medium.nX](each unit="1") "条件端口内部连接中转站";
  Modelica.Blocks.Interfaces.RealInput C_in_internal[Medium.nC] "条件端口内部连接中转站";

equation
  Modelica.Fluid.Utilities.checkBoundary(Medium.mediumName, Medium.substanceNames, Medium.singleState, true, X_in_internal, "Boundary_ph");

  // 连接外部信号或忽略
  connect(p_in, p_in_internal);
  connect(h_in, h_in_internal);
  connect(X_in, X_in_internal);
  connect(C_in, C_in_internal);

  if not use_p_in then
    p_in_internal = p;
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
  // 4. 将混合后的数值注入到底层基类的热力学状态中 (核心相变逻辑反算)
  // =======================================================================
  medium.p = p_in_internal;

  if Medium.ThermoStates == IndependentVariables.ph or 
     Medium.ThermoStates == IndependentVariables.phX then
     // 【直接赋值】：主流的两相工质库 (水、制冷剂) 底层就是以 p, h 作为计算原点的，直接赋予比焓极其高效
     medium.h = h_in_internal;
  else
     // 【非标准库的反算】：如果库底层不是以 p, h 作为变量，必须通过倒推反算求出温度 T 来闭合方程
     medium.T = Medium.temperature(Medium.setState_phX(p_in_internal, h_in_internal, X_in_internal));
  end if;

  medium.Xi = X_in_internal[1:Medium.nXi];
  ports.C_outflow = fill(C_in_internal, nPorts);

  // =======================================================================
  // 图形注解与官方汉化说明文档
  // =======================================================================
  annotation (defaultComponentName="boundary",
    Icon(coordinateSystem(preserveAspectRatio=false, extent={{-100,-100},{100,100}}), graphics={
        Ellipse(extent={{-100,100},{100,-100}}, fillPattern=FillPattern.Sphere, fillColor={0,127,255}),
        Text(extent={{-150,110},{150,150}}, textString="%name", textColor={0,0,255}),
        Line(visible=use_p_in, points={{-100,80},{-60,80}}, color={0,0,255}),
        Line(visible=use_h_in, points={{-100,40},{-92,40}}, color={0,0,255}), // 比焓引脚
        Line(visible=use_X_in, points={{-100,-40},{-92,-40}}, color={0,0,255}),
        Line(visible=use_C_in, points={{-100,-80},{-60,-80}}, color={0,0,255}),
        Text(visible=use_p_in, extent={{-150,134},{-72,94}}, textString="p"),
        Text(visible=use_h_in, extent={{-166,34},{-64,-6}}, textString="h"), // 比焓标签
        Text(visible=use_X_in, extent={{-164,4},{-62,-36}}, textString="X"),
        Text(visible=use_C_in, extent={{-164,-90},{-62,-130}}, textString="C")}),
    Documentation(info="<html>
<p>
本组件用于定义流体网络中强制指定的边界条件 (<strong>相变循环系统极度推荐</strong>)：
</p>
<ul>
<li> 指定边界压力。</li>
<li> <strong>指定边界比热力学焓。</strong> (用比焓代替温度，在两相区可精准锚定流体干度，彻底消除 p-T 耦合导致的奇异报错)</li>
<li> 指定边界组分。</li>
</ul>
<p>如果 <code>use_p_in</code> 开关处于关闭状态(默认)，模型将使用参数 <code>p</code> 作为固定边界压力；一旦激活该开关，你可以从外部连入动态压力控制信号。</p>
<p>比焓、组分等变量的控制逻辑与压力完全一致。</p>
<p>
<strong>⚠️ 再次警告 (流束方向性)：</strong><br>
你在此模型中设置的 <strong>比焓和组分等属性</strong>，<strong>仅仅</strong> 在流体从该边界 <strong>流入</strong> 系统时才起作用。<br>
如果系统发生倒流（排出流体），边界的热力学设定（除压力外）将被忽略。
</p>
</html>"));
end Boundary_ph;