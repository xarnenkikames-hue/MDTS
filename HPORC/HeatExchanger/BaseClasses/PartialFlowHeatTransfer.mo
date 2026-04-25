partial model PartialFlowHeatTransfer
    "所有管道/流道传热关联式的底层代理基类 (Base class for any pipe heat transfer correlation)"
  // 继承最基础的通用传热接口（获取介质温度 Ts、热端口 heatPorts、传热面积 surfaceAreas 和热流 Q_flows）
  extends .HPORC.Interfaces.PartialHeatTransfer;
  import SI = Modelica.SIunits;

  // =======================================================================
  // 核心增量：为流动传热模型专门提供的额外输入流体动力学参数
  // =======================================================================

  // 1. 流体速度场
  input SI.Velocity[n] vs "沿着管道被切分的 n 个容积节点内部，流体的平均流速 (Mean velocities of fluid flow in segments)";

  // 2. 几何与拓扑参数
  parameter Real nParallel "完全相同的并联流动设备数量 (例如：壳管式换热器中的管束总根数，用于面积和流量的倍乘放大)" 
      annotation(Dialog(tab="Internal interface",enable=false,group="Geometry"));

  input SI.Length[n] lengths "沿着流体流动方向，每一个切片节点 (segment) 的物理长度";

  input SI.Length[n] dimensions
      "流体流动的特征尺寸 (对于圆管流动而言，即为管道的水力内部直径 diameter)";

  input Modelica.Fluid.Types.Roughness[n] roughnesses "金属壁面内部表面粗糙度微凸体的平均高度 (绝对粗糙度，极其影响湍流边界层厚度和换热系数)";

  // =======================================================================
  // 官方说明文档与 UI 图标绘制 (已全面汉化)
  // =======================================================================
  annotation (Documentation(info="<html>
<p>
<b>流动设备传热模型的代理基类。</b>
</p>
<p>
在底层接口中，除了基础的传热面积 <code>surfaceAreas[n]</code> 之外，该类特别通过 <code>roughnesses[n]</code>（表面粗糙度）和 <code>lengths[n]</code>（沿流向长度）精确地定义了微观与宏观几何特征。<br>
更关键的是，为了适配不同类型的流动设备，它引入了极其重要的流体动力学特征量：特征尺寸 <code>dimensions[n]</code>（通常是管径）以及流体的平均流速 <code>vs[n]</code>。<br>
这些参数是计算无量纲数（如雷诺数、普朗特数、努塞尔数）的绝对基础。关于雷诺数的具体定义范例，请参见底层函数库：
<a href=\"modelica://Modelica.Fluid.Pipes.BaseClasses.CharacteristicNumbers.ReynoldsNumber\">Pipes.BaseClasses.CharacteristicNumbers.ReynoldsNumber</a>。
</p>
</html>"),Icon(coordinateSystem(preserveAspectRatio=true,  extent={{-100,-100},
              {100,100}}), graphics={Rectangle(
            extent={{-80,60},{80,-60}},
            pattern=LinePattern.None,
            fillColor={255,0,0}, // 绘制一个代表传热的红色水平圆柱体管段
            fillPattern=FillPattern.HorizontalCylinder), Text(
            extent={{-40,22},{38,-18}},
            textString="%name")}));
end PartialFlowHeatTransfer;