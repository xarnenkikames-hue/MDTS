connector FluidPort_a "标准流体入口接口 (用于设定设计的正向流入端)"

  // 继承基础流体接口的所有物理属性 (包括压力p、流量m_flow、焓流h_outflow、组分Xi等)
  extends FluidPort;

  // =======================================================================
  // 图形 UI 与默认命名规则 (已汉化)
  // =======================================================================
  annotation (
    // 当你把这个插头拖到画板上时，系统默认给它起的名字叫 port_a
    defaultComponentName="port_a",

    // 内部结构视图 (Diagram) 中的样子：一个小型的实心蓝色圆圈
    Diagram(coordinateSystem(preserveAspectRatio=false, extent={{-100,-100},{100,100}}), graphics={
        Ellipse(
          extent={{-40,40},{40,-40}},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid),
        Text(
          extent={{-150,110},{150,50}},
          textString="%name")}),

    // 外部图标视图 (Icon) 中的样子：一个大型的实心蓝色圆圈 (代表入口 Inlet)
    Icon(coordinateSystem(preserveAspectRatio=false, extent={{-100,-100},{100,100}}), graphics={
        Ellipse(
          extent={{-100,100},{100,-100}},
          lineColor={0,127,255},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{-100,100},{100,-100}},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid)}));

end FluidPort_a;