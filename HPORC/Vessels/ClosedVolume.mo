model ClosedVolume
  "大小固定、对环境封闭的容积（储液槽），带有进出流体端口 (Volume of fixed size, closed to the ambient, with inlet/outlet ports)"
  import Modelica.Constants.pi;
  import SI = Modelica.SIunits;

  // 继承集总参数容器基类 (接管底层的质量和能量守恒偏微分方程，并引入端口)
  extends Modelica.Fluid.Vessels.BaseClasses.PartialLumpedVessel(
    final fluidVolume = V, // 将底层的流体容积大小强行绑定为下方定义的参数 V

    // 几何假设：容器被视为一个完美的球体。
    // 特征面积（通常用于某些阻力计算的参考面积）
    vesselArea = pi*(3/4*V)^(2/3),

    // 传热边界：假设外部传热表面积等于该球体的表面积。
    // 数学推导：球体体积 V = (4/3)*pi*r^3  =>  r = [ (3*V) / (4*pi) ]^(1/3)
    // 球体表面积 A = 4*pi*r^2 = 4*pi * [ (3/4)*(V/pi) ]^(2/3)
    heatTransfer(surfaceAreas={4*pi*(3/4*V/pi)^(2/3)}));

  // 唯一需要用户在顶层 UI 输入的几何参数
  parameter SI.Volume V "容器的总内部容积 (Volume)";

equation
  // 1. 边界做功守恒
  // 这是一个刚性定容容器（V恒定），系统边界没有膨胀或压缩，因此机械做功（pdV功）严格为 0
  Wb_flow = 0;

  // 2. 内部压力场分布 (均相平压假设)
  for i in 1:nPorts loop
    // 遍历所有外接的流体端口，将每一个端口的静态压力强制等于容器内部的均相介质压力 (medium.p)
    // 这意味着在不开启 portsData 的情况下，容器内部没有压降，是一个等压水池。
    vessel_ps_static[i] = medium.p;
  end for;

  // =======================================================================
  // 图标与官方说明文档 (已全面汉化)
  // =======================================================================
  annotation (defaultComponentName="volume",
    Icon(coordinateSystem(preserveAspectRatio=true,  extent={{-100,-100},{
          100,100}}), graphics={Ellipse(
        extent={{-100,100},{100,-100}},
        fillPattern=FillPattern.Sphere,
        fillColor={170,213,255}), Text(
        extent={{-150,12},{150,-18}},
        textString="V=%V")}),
    Documentation(info="<html>
<p>
大小恒定的理想混合容积，自带两个流体交互端口和一个介质模型（Medium Model）。<br>
流体的各项物理属性均由上游流入的工质计算得出。如果关闭局部阻力计算 (<code>use_portsData=false</code>)，则两个连接端口的压力完全相等，且等同于内部介质的均相压力。<br>
允许通过热端口（Thermal Port）进行外部热交换，如果该端口在顶层网络中未连接，则热传导量自动视为零（完全绝热）。<br>
在底层计算传热面积时，强制假设该容器为<b>球形</b>，利用公式 <code>V=4/3*pi*r^3</code> 逆推半径，并由 <code>A=4*pi*r^2</code> 计算表面积。<br>
默认情况下采取理想传热模型；即热端口的金属表面温度直接等于容器内部工质的混合温度。
</p>
<p>
<b>进阶防爆防死锁说明：</b><br>
如果开启局部阻力 (<code>use_portsData=true</code>)，端口压力将代表所连接管道出口后（或入口前）的真实局部压力。<br>
此时，可以通过设定水力阻力系数 <code>portsData.zeta_in</code> 和 <code>portsData.zeta_out</code>，根据质量流动的方向，自动计算容器与管道接头处因涡流和截面突变产生的耗散压降。<br>
这在构建闭式循环时能极大地平抑流量波动。详细阻力计算法则请参考 <a href=\"modelica://Modelica.Fluid.Vessels.BaseClasses.VesselPortsData\">VesselPortsData</a> 以及 <em>[Idelchik, 流体阻力手册, 2004]</em>。
</p>
</html>"));
end ClosedVolume;