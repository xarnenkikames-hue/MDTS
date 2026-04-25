model Boundary_pT "带信号输入接口的压力温度流体边界 (无限大环境)"

  import Modelica.Media.Interfaces.Choices.IndependentVariables;

  // 继承底层纯流体源基类
  extends Sources.BaseClasses.PartialSource;

  // =======================================================================
  // 1. 外部控制信号使能开关 (条件引脚魔法)
  // =======================================================================
  parameter Boolean use_p_in = false
    "= true 时，在图标左侧激活压力输入引脚 (允许由外部信号动态控制压力)" 
    annotation(Evaluate=true, HideResult=true, choices(checkBox=true));

  parameter Boolean use_T_in= false
    "= true 时，在图标左侧激活温度输入引脚 (允许由外部信号动态控制温度)" 
    annotation(Evaluate=true, HideResult=true, choices(checkBox=true));

  parameter Boolean use_X_in = false
    "= true 时，在图标左侧激活组分浓度输入引脚" 
    annotation(Evaluate=true, HideResult=true, choices(checkBox=true));

  parameter Boolean use_C_in = false
    "= true 时，在图标左侧激活痕量物质输入引脚" 
    annotation(Evaluate=true, HideResult=true, choices(checkBox=true));

  // =======================================================================
  // 2. 静态固定参数 (当不使用外部引脚时生效)
  // =======================================================================
  parameter Medium.AbsolutePressure p = Medium.p_default
    "固定的边界压力值 (仅当 use_p_in = false 时有效)" 
    annotation (Dialog(enable = not use_p_in));

  parameter Medium.Temperature T = Medium.T_default
    "固定的边界温度值 (仅当 use_T_in = false 时有效)" 
    annotation (Dialog(enable = not use_T_in));

  parameter Medium.MassFraction X[Medium.nX] = Medium.X_default
    "固定的边界组分质量分数" 
    annotation (Dialog(enable = (not use_X_in) and Medium.nXi > 0));

  parameter Medium.ExtraProperty C[Medium.nC](
       quantity=Medium.extraPropertiesNames) = Medium.C_default
    "固定的边界痕量物质值" 
    annotation (Dialog(enable = (not use_C_in) and Medium.nC > 0));

  // =======================================================================
  // 3. 对外暴露的真实控制引脚 (根据使能开关动态生成)
  // =======================================================================
  Modelica.Blocks.Interfaces.RealInput p_in(unit="Pa") if use_p_in
    "外部动态控制的边界压力信号引脚" 
    annotation (Placement(transformation(extent={{-140,60},{-100,100}})));

  Modelica.Blocks.Interfaces.RealInput T_in(unit="K") if use_T_in
    "外部动态控制的边界温度信号引脚" 
    annotation (Placement(transformation(extent={{-140,20},{-100,60}})));

  Modelica.Blocks.Interfaces.RealInput X_in[Medium.nX](each unit="1") if use_X_in
    "外部动态控制的边界组分信号引脚" 
    annotation (Placement(transformation(extent={{-140,-60},{-100,-20}})));

  Modelica.Blocks.Interfaces.RealInput C_in[Medium.nC] if use_C_in
    "外部动态控制的边界痕量物质信号引脚" 
    annotation (Placement(transformation(extent={{-140,-100},{-100,-60}})));

  // =======================================================================
  // 4. 内部数据中转站 (用于合并静态参数与外部信号)
  // =======================================================================
protected
  Modelica.Blocks.Interfaces.RealInput p_in_internal(unit="Pa") "条件端口内部连接中转站";
  Modelica.Blocks.Interfaces.RealInput T_in_internal(unit="K") "条件端口内部连接中转站";
  Modelica.Blocks.Interfaces.RealInput X_in_internal[Medium.nX](each unit="1") "条件端口内部连接中转站";
  Modelica.Blocks.Interfaces.RealInput C_in_internal[Medium.nC] "条件端口内部连接中转站";

equation
  Modelica.Fluid.Utilities.checkBoundary(Medium.mediumName, Medium.substanceNames, Medium.singleState, true, X_in_internal, "Boundary_pT");

  // 尝试连接外部信号 (如果没有信号引脚，这些连接在底层会自动忽略)
  connect(p_in, p_in_internal);
  connect(T_in, T_in_internal);
  connect(X_in, X_in_internal);
  connect(C_in, C_in_internal);

  // 如果没开外部引脚，强行赋予固定参数值
  if not use_p_in then
    p_in_internal = p;
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
  // 5. 将混合后的数值注入到底层基类的热力学状态中
  // =======================================================================
  medium.p = p_in_internal;

  if Medium.ThermoStates == IndependentVariables.ph or 
     Medium.ThermoStates == IndependentVariables.phX then
     // 【相变/制冷剂工质核心】：利用 p, T 倒推算出比焓 h 注入内部状态
     medium.h = Medium.specificEnthalpy(Medium.setState_pTX(p_in_internal, T_in_internal, X_in_internal));
  else
     medium.T = T_in_internal;
  end if;

  medium.Xi = X_in_internal[1:Medium.nXi];
  ports.C_outflow = fill(C_in_internal, nPorts);

  // =======================================================================
  // 图形注解与官方汉化说明文档
  // =======================================================================
  annotation (defaultComponentName="boundary",
    Icon(coordinateSystem(preserveAspectRatio=false, extent={{-100,-100},{100,100}}), graphics={
        Ellipse(extent={{-100,100},{100,-100}}, fillPattern=FillPattern.Sphere, fillColor={0,127,255}),
        Text(extent={{-150,120},{150,160}}, textString="%name", textColor={0,0,255}),
        // 动态绘制信号引脚连接线
        Line(visible=use_p_in, points={{-100,80},{-58,80}}, color={0,0,255}),
        Line(visible=use_T_in, points={{-100,40},{-92,40}}, color={0,0,255}),
        Line(visible=use_X_in, points={{-100,-40},{-92,-40}}, color={0,0,255}),
        Line(visible=use_C_in, points={{-100,-80},{-60,-80}}, color={0,0,255}),
        // 动态绘制引脚标签文字
        Text(visible=use_p_in, extent={{-152,134},{-68,94}}, textString="p"),
        Text(visible=use_X_in, extent={{-164,4},{-62,-36}}, textString="X"),
        Text(visible=use_C_in, extent={{-164,-90},{-62,-130}}, textString="C"),
        Text(visible=use_T_in, extent={{-162,34},{-60,-6}}, textString="T")}),
    Documentation(info="<html>
<p>
本组件用于定义流体网络中强制指定的边界条件：
</p>
<ul>
<li> 指定边界压力。</li>
<li> 指定边界温度。</li>
<li> 指定边界组分 (仅限多组分或痕量物质流体)。</li>
</ul>
<p>如果你在参数界面不勾选 <code>use_p_in</code> (默认)，模型将使用参数 <code>p</code> 作为固定边界压力；一旦你勾选了 <code>use_p_in</code>，模型将无视固定的 <code>p</code> 值，并在图标左侧长出一个蓝色的信号引脚，你可以连接任何动态信号来实时控制该边界的压力！</p>
<p>温度、组分等变量的控制逻辑与压力完全一致。</p>
<p>
<strong>⚠️ 再次警告 (流束方向性)：</strong><br>
你在此模型中设置的 <strong>温度和组分等属性</strong>，<strong>仅仅</strong> 在流体从该边界 <strong>流入</strong> 系统时才起作用。<br>
如果系统发生倒流，除了<strong>边界压力</strong>依然保持强加恒定外，其它热力学设定值将被求解器忽略。
</p>
</html>"));
end Boundary_pT;