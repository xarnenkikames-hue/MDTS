model PrescribedPump "给定转速的理想离心泵 (实战主力，自带防停泵崩溃机制)"

  // 继承底层水泵基类 (所有真实的 H-Q 曲线、功率效率计算都在这里面)
  extends BaseClasses.PartialPump;

  // =======================================================================
  // 1. 转速控制信号选择器
  // =======================================================================
  parameter Boolean use_N_in = false
    "= true 时，激活顶部的转速输入引脚 (允许你用外部信号做变频控制)" 
    annotation(Evaluate=true, HideResult=true, choices(checkBox=true));

  parameter Modelica.Units.NonSI.AngularVelocity_rpm 
    N_const = N_nominal
    "固定的旋转速度 (默认等于额定转速 N_nominal，单位: RPM)" 
    annotation(Dialog(enable = not use_N_in));

  // =======================================================================
  // 2. 对外暴露的转速控制引脚 (注意单位是 rev/min)
  // =======================================================================
  Modelica.Blocks.Interfaces.RealInput N_in(unit="rev/min") if use_N_in
    "外部动态控制的转速信号引脚 (图标正上方)" 
    annotation (Placement(transformation(
        extent={{-20,-20},{20,20}},
        rotation=-90,
        origin={0,100}), iconTransformation(
        extent={{-20,-20},{20,20}},
        rotation=-90,
        origin={0,100})));

protected
  // 内部信号中转站
  Modelica.Blocks.Interfaces.RealInput N_in_internal(unit="rev/min")
    "用于连接条件接口的内部中转变量";

equation
  // =======================================================================
  // 3. 信号路由与数值防呆
  // =======================================================================

  // 尝试连接外部信号
  connect(N_in, N_in_internal);

  // 如果没开引脚，使用固定转速
  if not use_N_in then
    N_in_internal = N_const;
  end if;

  // 【神级数值防呆】：为转速设定一个极小的下限 (1e-3 RPM)，彻底避免在零转速时底层相似定律方程发生除以0的奇异崩溃！
  N = max(N_in_internal, 1e-3) "传递给底层偏微分方程的实际转速";

  // =======================================================================
  // 图形注解与官方说明文档
  // =======================================================================
  annotation (defaultComponentName="pump",
    Icon(coordinateSystem(preserveAspectRatio=true,  extent={{-100,-100},{100,100}}), graphics={
        Text(
          visible=use_N_in,
          extent={{14,98},{178,82}},
          textString="N_in [rpm]")}),
    Documentation(info="<html>
<p>本模型描述了一台（或通过 <code>nParallel</code> 参数并联的多台）<strong>离心泵</strong>。其运行转速是被明确给定的（可以是固定值，也可以由外部变频信号提供）。</p>
<p>该模型继承自 <code>PartialPump</code>，所有的性能曲线（流量-扬程、耗功、效率）都在父类中定义。</p>
<p>如果引脚 <code>N_in</code> 被连接，它将实时提供水泵的转速 (RPM)；否则，模型将假设水泵以恒定的转速 <code>N_const</code> 运行（该固定值可以区别于水泵的额定转速 <code>N_nominal</code>）。</p>
</html>",
      revisions="<html>
<ul>
<li><em>2005年10月31日</em>
    由 <a href=\"mailto:francesco.casella@polimi.it\">Francesco Casella</a>:<br>
       将此模型添加至 Fluid 官方库</li>
</ul>
</html>"));
end PrescribedPump;