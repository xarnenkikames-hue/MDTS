model CylindricalClosedVolume
  "圆柱形大小固定、对环境封闭的容积（储液槽），带有进出流体端口 (Cylindrical volume of fixed size, closed to the ambient)"
  import Modelica.Constants.pi;
  import SI = Modelica.SIunits;

  // 1. 用户界面输入的几何参数
  parameter SI.Volume V "容器的总内部容积 (Volume)";
  parameter Real L_D_ratio = 3.0 "圆柱体的长径比 (L/D)，通常工业储液罐在 2.0 到 5.0 之间" 
    annotation(Dialog(group="Geometry"));

  // 2. 继承集总参数容器基类 (接管底层的质量和能量守恒偏微分方程，并引入端口)
  extends BaseClasses.PartialLumpedVessel(
    final fluidVolume = V,

    // 截面积计算：pi * r^2
    // 根据 V = 2 * L_D_ratio * pi * r^3 反推 r^2
    vesselArea = pi * (V / (2 * L_D_ratio * pi))^(2/3),

    // 传热边界：圆柱体总表面积 = 2*pi*r^2 (上下底) + 2*pi*r*L (侧面)
    // 提取公因式：2*pi*r^2 * (1 + 2*L_D_ratio)
    heatTransfer(surfaceAreas={ 2 * pi * (V / (2 * L_D_ratio * pi))^(2/3) * (1 + 2 * L_D_ratio) }));

equation
  // 3. 边界做功守恒
  // 这是一个刚性定容容器（V恒定），系统边界没有膨胀或压缩，因此机械做功（pdV功）严格为 0
  Wb_flow = 0;

  // 4. 内部压力场分布 (均相平压假设)
  for i in 1:nPorts loop
    // 遍历所有外接的流体端口，将每一个端口的静态压力强制等于容器内部的均相介质压力 (medium.p)
    vessel_ps_static[i] = medium.p;
  end for;

  // =======================================================================
  // 图标与官方说明文档 (已全面汉化并重构为圆柱体逻辑)
  // =======================================================================
  annotation (defaultComponentName="cylindricalVolume",
    Icon(coordinateSystem(preserveAspectRatio=true, extent={{-100,-100},{100,100}}),
      graphics={
        Rectangle(
          extent={{-60,100},{60,-100}},
          fillPattern=FillPattern.Solid,
          fillColor={170,213,255},
          lineColor={0,0,255}),
        Text(
          extent={{-150,15},{150,-15}},
          textString="V=%V\nL/D=%L_D_ratio")}),
    Documentation(info="<html>
<p>
大小恒定的理想混合容积，自带两个流体交互端口和一个介质模型（Medium Model）。<br>
流体的各项物理属性均由上游流入的工质计算得出。如果关闭局部阻力计算 (<code>use_portsData=false</code>)，则两个连接端口的压力完全相等，且等同于内部介质的均相压力。<br>
允许通过热端口（Thermal Port）进行外部热交换，如果该端口在顶层网络中未连接，则热传导量自动视为零（完全绝热）。<br>
</p>
<p>
<b>几何特性重构（圆柱体假设）：</b><br>
在底层计算传热面积与横截面积时，强制假设该容器为<b>圆柱体</b>。<br>
通过引入长径比参数 <code>L_D_ratio</code> (即 L/D)，利用公式 <code>V = pi * r^2 * L = 2 * k * pi * r^3</code> 逆推容器半径 <code>r</code>，并精确计算出参与外部热交换的圆柱体总表面积。<br>
默认情况下采取理想传热模型；即热端口的金属表面温度直接等于容器内部工质的混合温度。
</p>
<p>
<b>进阶防爆防死锁说明：</b><br>
如果开启局部阻力 (<code>use_portsData=true</code>)，端口压力将代表所连接管道出口后（或入口前）的真实局部压力。<br>
此时，可以通过设定水力阻力系数 <code>portsData.zeta_in</code> 和 <code>portsData.zeta_out</code>，根据质量流动的方向，自动计算容器与管道接头处因涡流和截面突变产生的耗散压降。<br>
这在构建闭式循环时能极大地平抑流量波动。
</p>
</html>"));
end CylindricalClosedVolume;