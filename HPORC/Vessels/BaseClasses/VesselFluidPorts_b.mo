connector VesselFluidPorts_b
  "流体连接器（法兰）：带有一个带有轮廓的大尺寸图标，专门用于水平排列的流体端口阵列（在 UI 界面拖拽添加后，必须定义其阵列维度）"

  // 继承最基础的流体端口属性（包含压力 p、质量流率 m_flow、比焓 h_outflow 等热力学引脚）
  extends Interfaces.FluidPort;

  // =======================================================================
  // UI 界面图层与图标绘制 (包含所有底层几何图形的绝对坐标)
  // 这部分代码极其繁琐，但它是 Modelica 图形化拖拽的灵魂
  // =======================================================================
  annotation (
    // 实例化时的默认名称前缀
    defaultComponentName="ports_b",

    // 1. Diagram 图层：双击进入组件内部时看到的放大版图形
    Diagram(coordinateSystem(
        preserveAspectRatio=false,
        extent={{-50,-200},{50,200}}, // 定义画布大小
        initialScale=0.2), graphics={
        // 端口名称文本显示
        Text(extent={{-75,130},{75,100}}, textString="%name"),
        // 法兰底座外框
        Rectangle(
          extent={{-25,100},{25,-100}}),
        // 绘制法兰内部的蓝色流体通道纹理 (一系列交错的蓝色/白色椭圆)
        Ellipse(
          extent={{-22,100},{-10,-100}},
          fillColor={0,127,255}, // 标准流体蓝色
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{-20,-69},{-12,69}},
          lineColor={0,127,255},
          fillColor={255,255,255}, // 白色高光
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{-6,100},{6,-100}},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{10,100},{22,-100}},
          fillColor={0,127,255},
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{-4,-69},{4,69}},
          lineColor={0,127,255},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{12,-69},{20,69}},
          lineColor={0,127,255},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid)}),

    // 2. Icon 图层：在顶层系统装配图中看到的外部微缩图标
    Icon(coordinateSystem(
        preserveAspectRatio=false,
        extent={{-50,-200},{50,200}},
        initialScale=0.2), graphics={
        // 外部微缩法兰边框
        Rectangle(
          extent={{-50,200},{50,-200}},
          lineColor={0,127,255},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid),
        // 外部微缩蓝色流体纹理
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
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{-39,-118.5},{-25,113}},
          lineColor={0,127,255},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{-7,-118.5},{7,113}},
          lineColor={0,127,255},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid),
        Ellipse(
          extent={{25,-117.5},{39,114}},
          lineColor={0,127,255},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid)}));
end VesselFluidPorts_b;