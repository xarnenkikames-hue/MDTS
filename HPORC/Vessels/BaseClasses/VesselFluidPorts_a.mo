connector VesselFluidPorts_a
  "带有实心填充、大尺寸图标的流体连接器（法兰），专门用于水平排列的流体端口阵列（在 UI 界面拖拽添加后，必须定义其阵列维度）"

  // 继承最基础的流体端口属性（包含核心热力学引脚：压力 p、质量流率 m_flow、比焓 h_outflow 等）
  extends Interfaces.FluidPort;

  // =======================================================================
  // UI 界面图层与图标绘制 (纯实心蓝色纹理，无白色掏空图层)
  // =======================================================================
  annotation (
    // 实例化时的默认名称前缀（注意：官方源码这里可能有个小笔误，默认名字居然也叫 ports_b，但这不影响物理计算）
    defaultComponentName="ports_b",

    // 1. Diagram 图层：双击进入组件内部时看到的放大版图形
    Diagram(coordinateSystem(
        preserveAspectRatio=false,
        extent={{-50,-200},{50,200}}, // 画布大小
        initialScale=0.2), graphics={
        // 端口名称文本显示
        Text(extent={{-75,130},{75,100}}, textString="%name"),
        // 法兰底座外框
        Rectangle(
          extent={{-25,100},{25,-100}}),
        // 绘制法兰内部的纯实心蓝色流体通道纹理 (相比 port_b，这里去掉了白色的遮罩层)
        Ellipse(
          extent={{-22,100},{-10,-100}},
          fillColor={0,127,255}, // 标准流体蓝色
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{-6,100},{6,-100}},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{10,100},{22,-100}},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid)}),

    // 2. Icon 图层：在顶层系统装配图中看到的外部微缩图标
    Icon(coordinateSystem(
        preserveAspectRatio=false,
        extent={{-50,-200},{50,200}},
        initialScale=0.2), graphics={
        // 外部微缩法兰白色底板边框
        Rectangle(
          extent={{-50,200},{50,-200}},
          lineColor={0,127,255},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid),
        // 外部微缩实心蓝色流体纹理
        Ellipse(
          extent={{-44,200},{-20,-200}},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{-12,200},{12,-200}},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{20,200},{44,-200}},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid)}));
end VesselFluidPorts_a;