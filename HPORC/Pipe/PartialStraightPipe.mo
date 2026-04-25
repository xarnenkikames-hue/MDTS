partial model PartialStraightPipe "所有直管模型的基础类 (赋予一维流动以几何实体)"

  // 继承双端口太爷爷 (确立了宇宙法则和插头方向)
  extends BaseClasses.PartialTwoPort;

  // 【防报错补丁：导入国际单位制与数学常数】
  import SI = Modelica.SIunits;
  import Modelica.Constants.pi;

  // =======================================================================
  // 1. Geometry (宏观几何参数)
  // =======================================================================
  // 注意：将 nParallel 定义为 Real (实数) 是为了在某些反向设计计算中支持连续求导
  parameter Real nParallel(min=1)=1 "相同的平行管束数量 (极大节省换热器计算量)" 
    annotation(Dialog(tab="常规设置", group="几何参数"));

  parameter SI.Length length "单根管道的有效换热/流动长度" 
    annotation(Dialog(tab="常规设置", group="几何参数"));

  parameter Boolean isCircular=true
    "= true 时，代表流通截面为标准圆形" 
    annotation (Evaluate, Dialog(tab="常规设置", group="几何参数"));

  parameter SI.Diameter diameter "圆管内径" 
    annotation(Dialog(tab="常规设置", group="几何参数", enable=isCircular));

  parameter SI.Area crossArea=pi*diameter*diameter/4
    "内部流通截面积" 
    annotation(Dialog(tab="常规设置", group="几何参数", enable=not isCircular));

  parameter SI.Length perimeter(min=0)=pi*diameter
    "内部湿周 (用于计算水力直径和换热面积)" 
    annotation(Dialog(tab="常规设置", group="几何参数", enable=not isCircular));

  parameter Modelica.Fluid.Types.Roughness roughness=2.5e-5
    "表面微观凸起的平均绝对高度 (默认 2.5e-5 m，代表光滑钢管)" 
      annotation(Dialog(tab="常规设置", group="几何参数"));

  final parameter SI.Volume V=crossArea*length*nParallel "管束内部总容积";

  // =======================================================================
  // 2. Static head (静压头与高程)
  // =======================================================================
  parameter SI.Length height_ab=0 "端口 b 与 端口 a 之间的高程差 (用于计算重力压降)" 
      annotation(Dialog(tab="常规设置", group="静压头 (高程差)"));

  // =======================================================================
  // 3. Pressure loss (压降阻力计算“插槽”)
  // =======================================================================
  // 这就是那个留给 FlowModel 的 PCIe 显卡插槽！
  replaceable model FlowModel =
    Modelica.Fluid.Pipes.BaseClasses.FlowModels.DetailedPipeFlow 
    constrainedby 
    Modelica.Fluid.Pipes.BaseClasses.FlowModels.PartialStaggeredFlowModel
    "管道壁面摩擦、重力压降与动量流模型" 
      annotation(Dialog(tab="常规设置", group="压降与阻力"), choicesAllMatching=true);

equation
  // =======================================================================
  // 几何逻辑安全检查
  // =======================================================================
  assert(length >= height_ab, "物理几何错误：管道的实际长度必须大于或等于其高程差！");

  // =======================================================================
  // 图形 UI 与官方汉化文档
  // =======================================================================
  annotation (
    defaultComponentName="pipe",
    Icon(coordinateSystem(
        preserveAspectRatio=false,
        extent={{-100,-100},{100,100}}), graphics={
        // 画一个代表直管的实心圆柱体底色
        Rectangle(
          extent={{-100,40},{100,-40}},
          fillPattern=FillPattern.Solid,
          fillColor={95,95,95},
          pattern=LinePattern.None),
        // 覆盖上具有金属光泽的蓝色水平圆柱渐变贴图
        Rectangle(
          extent={{-100,44},{100,-44}},
          fillPattern=FillPattern.HorizontalCylinder,
          fillColor={0,127,255})}),
    Documentation(info="<html>
<p>
本组件是所有一维直管流体模型（如静态管、动态管）的<strong>抽象基础类</strong>。
它对 <code>PartialTwoPort</code> 进行了专业化扩展，为其添加了详尽的几何参数接口（如管长、面积、平行管束数量）以及直管的标志性图标。
</p>
<p>
通过 <code>isCircular</code> 开关，用户可以灵活地在标准圆管和异形截面管道（需手动输入等效面积与湿周）之间进行切换。
</p>
</html>"));
end PartialStraightPipe;