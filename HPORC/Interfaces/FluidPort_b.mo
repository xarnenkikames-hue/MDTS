connector FluidPort_b "标准流体出口接口 (用于设定设计的正向流出端)"

  // 继承基础流体接口的所有物理属性 (与 port_a 的物理法则完全等价)
  extends FluidPort;

  // =======================================================================
  // 图形 UI 与默认命名规则 (空心白圆视觉设计)
  // =======================================================================
  annotation (
    // 拖入画板时的默认实例名
    defaultComponentName="port_b",

    // 内部结构视图 (Diagram) 中的样子：小型空心圆
    Diagram(coordinateSystem(preserveAspectRatio=false, extent={{-100,-100},{100,100}}), graphics={
        // 蓝底
        Ellipse(
          extent={{-40,40},{40,-40}},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid),
        // 白面覆盖 (RGB: 255,255,255)
        Ellipse(
          extent={{-30,30},{30,-30}},
          lineColor={0,127,255},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid),
        Text(
          extent={{-150,110},{150,50}},
          textString="%name")}),

    // 外部图标视图 (Icon) 中的样子：大型空心圆 (代表出口 Outlet)
    Icon(coordinateSystem(preserveAspectRatio=false, extent={{-100,-100},{100,100}}), graphics={
        // 第一层：外围边界
        Ellipse(
          extent={{-100,100},{100,-100}},
          lineColor={0,127,255},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid),
        // 第二层：实心蓝底
        Ellipse(
          extent={{-100,100},{100,-100}},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid),
        // 第三层：白面覆盖，制造“空心环”效果
        Ellipse(
          extent={{-80,80},{80,-80}},
          lineColor={0,127,255},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid)}));

end FluidPort_b;