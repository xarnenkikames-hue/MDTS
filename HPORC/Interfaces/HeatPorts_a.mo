connector HeatPorts_a
  "带有实心填充、大尺寸图标的热端口连接器（法兰），专门用于热端口阵列（在 UI 界面拖拽添加后，必须定义其阵列维度 n）"

  // 继承最基础的热传导端口属性（底层包含了两个核心共轭变量：温度 T [跨越变量] 和 热流率 Q_flow [穿越变量]）
  extends HeatPort;

  // =======================================================================
  // UI 界面图层与图标绘制 (纯深红色阵列纹理)
  // =======================================================================
  annotation (
    // 实例化时的默认名称前缀
    defaultComponentName="heatPorts_a",

    // Icon 图层：在顶层系统装配图中看到的外部微缩图标
    Icon(coordinateSystem(
        preserveAspectRatio=false,
        // 画布大小设置为横向细长型，以在视觉上暗示这是一个“数组/阵列”而非单一节点
        extent={{-200,-50},{200,50}},
        initialScale=0.2), graphics={
        // 外部微缩法兰白色底板边框 (带有深红色的线框)
        Rectangle(
          extent={{-201,50},{200,-50}},
          lineColor={127,0,0}, // 热力学标准深红色
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid),
        // 内部绘制第一个实心深红色矩形 (视觉上代表阵列中的第一个传热节点)
        Rectangle(
          extent={{-171,45},{-83,-45}},
          lineColor={127,0,0},
          fillColor={127,0,0},
          fillPattern=FillPattern.Solid),
        // 内部绘制第二个实心深红色矩形 (视觉上代表阵列中的中间传热节点)
        Rectangle(
          extent={{-45,45},{43,-45}},
          lineColor={127,0,0},
          fillColor={127,0,0},
          fillPattern=FillPattern.Solid),
        // 内部绘制第三个实心深红色矩形 (视觉上代表阵列中的末端传热节点)
        Rectangle(
          extent={{82,45},{170,-45}},
          lineColor={127,0,0},
          fillColor={127,0,0},
          fillPattern=FillPattern.Solid)}));
end HeatPorts_a;