connector FluidPorts_b "标准流体出口阵列接口 (专门用于定义端口向量/多端口)"

  // 物理上完全等价于基础插头，不增加任何新方程
  extends FluidPort;

  // =======================================================================
  // 图形 UI：专为“数组/向量”设计的长条形外观
  // =======================================================================
  annotation (
    // 拖拽到画板上时的默认名称 (带了 s)
    defaultComponentName="ports_b",

    // 内部结构视图 (Diagram) 中的样子
    Diagram(coordinateSystem(
        preserveAspectRatio=false,
        extent={{-50,-200},{50,200}}, // 极度拉长的坐标系 (高度 400，宽度 100)
        initialScale=0.2), graphics={
        Text(extent={{-75,130},{75,100}}, textString="%name"),
        // 画一个长方形外框，代表“联箱/集管”
        Rectangle(
          extent={{-25,100},{25,-100}}),
        // 画顶部的空心圆 (实心蓝底 + 白面)
        Ellipse(extent={{-25,90},{25,40}}, fillColor={0,127,255}, fillPattern=FillPattern.Solid),
        Ellipse(extent={{-15,50},{15,80}}, lineColor={0,127,255}, fillColor={255,255,255}, fillPattern=FillPattern.Solid),
        // 画中间的空心圆
        Ellipse(extent={{-25,25},{25,-25}}, fillColor={0,127,255}, fillPattern=FillPattern.Solid),
        Ellipse(extent={{-15,15},{15,-15}}, lineColor={0,127,255}, fillColor={255,255,255}, fillPattern=FillPattern.Solid),
        // 画底部的空心圆
        Ellipse(extent={{-25,-40},{25,-90}}, fillColor={0,127,255}, fillPattern=FillPattern.Solid),
        Ellipse(extent={{-15,-50},{15,-80}}, lineColor={0,127,255}, fillColor={255,255,255}, fillPattern=FillPattern.Solid)}),

    // 外部图标视图 (Icon) 中的样子 (与内部视图逻辑相同，只是尺寸更大)
    Icon(coordinateSystem(
        preserveAspectRatio=false,
        extent={{-50,-200},{50,200}},
        initialScale=0.2), graphics={
        // 长方形白底蓝框
        Rectangle(
          extent={{-50,200},{50,-200}},
          lineColor={0,127,255},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid),
        // 顶部空心圆 (因为是出口 port_b，所以维持白心)
        Ellipse(extent={{-50,180},{50,80}}, fillColor={0,127,255}, fillPattern=FillPattern.Solid),
        Ellipse(extent={{-30,100},{30,160}}, lineColor={0,127,255}, fillColor={255,255,255}, fillPattern=FillPattern.Solid),
        // 中间空心圆
        Ellipse(extent={{-50,50},{50,-50}}, fillColor={0,127,255}, fillPattern=FillPattern.Solid),
        Ellipse(extent={{-30,30},{30,-30}}, lineColor={0,127,255}, fillColor={255,255,255}, fillPattern=FillPattern.Solid),
        // 底部空心圆
        Ellipse(extent={{-50,-80},{50,-180}}, fillColor={0,127,255}, fillPattern=FillPattern.Solid),
        Ellipse(extent={{-30,-100},{30,-160}}, lineColor={0,127,255}, fillColor={255,255,255}, fillPattern=FillPattern.Solid)}));

end FluidPorts_b;