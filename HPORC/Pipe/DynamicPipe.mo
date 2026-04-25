model DynamicPipe "带质量与能量守恒（储能）的动态管道偏微分求解引擎"

  import Modelica.Fluid.Types.ModelStructure;

  // =======================================================================
  // 1. 继承基础直管模型：处理端口状态暴露
  // =======================================================================
  extends PartialStraightPipe(
    final port_a_exposesState = (modelStructure == ModelStructure.av_b) or (modelStructure == ModelStructure.av_vb),
    final port_b_exposesState = (modelStructure == ModelStructure.a_vb) or (modelStructure == ModelStructure.av_vb));

  // =======================================================================
  // 2. 继承双端口流动模型：实现一维空间的离散化 (切分网格)
  // =======================================================================
  extends BaseClasses.PartialTwoPortFlow(
    final lengths=fill(length/n, n),
    final crossAreas=fill(crossArea, n),
    final dimensions=fill(4*crossArea/perimeter, n),
    final roughnesses=fill(roughness, n),
    final dheights=height_ab*dxs,energyDynamics=Modelica.Fluid.Types.Dynamics.DynamicFreeInitial);

  // =======================================================================
  // 3. 传热计算“插槽”与实体化 (包含菜单栏 Dialog 深度汉化)
  // =======================================================================
  parameter Boolean use_HeatTransfer = true
    "= true 时开启传热计算 (启用 HeatTransfer 插槽)" 
      // 【深度汉化】：双击组件后，在“模型假设”标签页下的“传热设置”分组中显示
      annotation (Dialog(tab="模型假设", group="传热设置"));

  replaceable model HeatTransfer =
      Modelica.Fluid.Pipes.BaseClasses.HeatTransfer.IdealFlowHeatTransfer 
    constrainedby 
    Modelica.Fluid.Pipes.BaseClasses.HeatTransfer.PartialFlowHeatTransfer
    "管壁传热源项模型" 
      // 【深度汉化】：联动显示设置，只有 use_HeatTransfer 打勾时，这个下拉框才允许被点击 (enable=use_HeatTransfer)
      annotation (Dialog(tab="模型假设", group="传热设置", enable=use_HeatTransfer), choicesAllMatching=true);

  Modelica.Fluid.Interfaces.HeatPorts_a[nNodes] heatPorts if use_HeatTransfer 
    annotation (Placement(transformation(extent={{-10,45},{10,65}}), iconTransformation(extent={{-30,36},{32,52}})));

  HeatTransfer heatTransfer(
    redeclare final package Medium = Medium,
    final n=n,
    final nParallel=nParallel,
    final surfaceAreas=perimeter*lengths,
    final lengths=lengths,
    final dimensions=dimensions,
    final roughnesses=roughnesses,
    final states=mediums.state,
    final vs = vs,
    final use_k = use_HeatTransfer) "传热计算引擎" 
      annotation (Placement(transformation(extent={{-45,20},{-23,42}})));

  final parameter Real[n] dxs = lengths/sum(lengths) "无量纲化归一化长度";

equation
  // =======================================================================
  // 4. 能量守恒偏微分方程的闭合 (源项注入)
  // =======================================================================
  Qb_flows = heatTransfer.Q_flows;

  // =======================================================================
  // 5. 机械能耗散转化为热能 (极度复杂的交错网格插值算法)
  // =======================================================================
  if n == 1 or useLumpedPressure then
    Wb_flows = dxs * ((vs*dxs)*(crossAreas*dxs)*((port_b.p - port_a.p) + sum(flowModel.dps_fg) - system.g*(dheights*mediums.d)))*nParallel;
  else
    if modelStructure == ModelStructure.av_vb or modelStructure == ModelStructure.av_b then
      Wb_flows[2:n-1] = {vs[i]*crossAreas[i]*((mediums[i+1].p - mediums[i-1].p)/2 + (flowModel.dps_fg[i-1]+flowModel.dps_fg[i])/2 - system.g*dheights[i]*mediums[i].d) for i in 2:n-1}*nParallel;
    else
      Wb_flows[2:n-1] = {vs[i]*crossAreas[i]*((mediums[i+1].p - mediums[i-1].p)/2 + (flowModel.dps_fg[i]+flowModel.dps_fg[i+1])/2 - system.g*dheights[i]*mediums[i].d) for i in 2:n-1}*nParallel;
    end if;

    if modelStructure == ModelStructure.av_vb then
      Wb_flows[1] = vs[1]*crossAreas[1]*((mediums[2].p - mediums[1].p)/2 + flowModel.dps_fg[1]/2 - system.g*dheights[1]*mediums[1].d)*nParallel;
      Wb_flows[n] = vs[n]*crossAreas[n]*((mediums[n].p - mediums[n-1].p)/2 + flowModel.dps_fg[n-1]/2 - system.g*dheights[n]*mediums[n].d)*nParallel;
    elseif modelStructure == ModelStructure.av_b then
      Wb_flows[1] = vs[1]*crossAreas[1]*((mediums[2].p - mediums[1].p)/2 + flowModel.dps_fg[1]/2 - system.g*dheights[1]*mediums[1].d)*nParallel;
      Wb_flows[n] = vs[n]*crossAreas[n]*((port_b.p - mediums[n-1].p)/1.5 + flowModel.dps_fg[n-1]/2+flowModel.dps_fg[n] - system.g*dheights[n]*mediums[n].d)*nParallel;
    elseif modelStructure == ModelStructure.a_vb then
      Wb_flows[1] = vs[1]*crossAreas[1]*((mediums[2].p - port_a.p)/1.5 + flowModel.dps_fg[1]+flowModel.dps_fg[2]/2 - system.g*dheights[1]*mediums[1].d)*nParallel;
      Wb_flows[n] = vs[n]*crossAreas[n]*((mediums[n].p - mediums[n-1].p)/2 + flowModel.dps_fg[n]/2 - system.g*dheights[n]*mediums[n].d)*nParallel;
    elseif modelStructure == ModelStructure.a_v_b then
      Wb_flows[1] = vs[1]*crossAreas[1]*((mediums[2].p - port_a.p)/1.5 + flowModel.dps_fg[1]+flowModel.dps_fg[2]/2 - system.g*dheights[1]*mediums[1].d)*nParallel;
      Wb_flows[n] = vs[n]*crossAreas[n]*((port_b.p - mediums[n-1].p)/1.5 + flowModel.dps_fg[n]/2+flowModel.dps_fg[n+1] - system.g*dheights[n]*mediums[n].d)*nParallel;
    else
      assert(false, "未知的网格结构拓扑！");
    end if;
  end if;

  connect(heatPorts, heatTransfer.heatPorts) 
    annotation (Line(points={{0,55},{0,54},{-34,54},{-34,38.7}}, color={191,0,0}));

  // =======================================================================
  // 图形注解与官方说明文档 (已全面汉化)
  // =======================================================================
  annotation (defaultComponentName="pipe",
Documentation(info="<html>
<p><b>具备质量、能量与动量分布守恒求解能力的动态直管模型。</b><br>
它提供了完整的一维流体流动平衡方程。本通用模型提供了大量参数设置选项，处理相变等高度非线性工况时鲁棒性极佳。</p>

<p><code>DynamicPipe</code> 使用<b>有限体积法 (FVM)</b> 处理偏微分方程，并使用<b>交错网格 (Staggered Grid)</b> 方案处理动量守恒。管道沿流动路径被分割为 <code>nNodes</code> 个等距段。默认值为 <code>nNodes=2</code>。</p>

<p><b>⚠️ 核心警告 (高指数 DAE 死锁)：</b><br>
如果将多个动态管道直接相连（即两个包含状态变量的容积模型直接对接），通常会导致压力状态的<b>高指数 DAE (微分代数方程组) 求解失败</b>！<br>
默认的交错网格结构为 <code>av_vb</code> (两端均为体积节点)。如果遇到极度复杂的网络连接，可以通过修改 <code><strong>modelStructure</strong></code> 参数，在压力状态和边界之间强制插入一个动量守恒平衡（例如 <code>a_v_b</code>），以规避 DAE 死锁。</p>

<p><code><strong>HeatTransfer</strong></code> 组件规定了能量守恒中的热源项 <code>Qb_flows</code>。该组件是可替换的 (Replaceable)，可以使用任何继承自 <code>PartialFlowHeatTransfer</code> 接口的高保真传热关联式（如相变换热模型）进行无缝替换。</p>
</html>"),
Icon(coordinateSystem(preserveAspectRatio=true,  extent={{-100,-100},{100,100}}), graphics={
        Rectangle(extent={{-100,44},{100,-44}}, fillPattern=FillPattern.HorizontalCylinder, fillColor={0,127,255}),
        Ellipse(extent={{-72,10},{-52,-10}}, fillPattern=FillPattern.Solid),
        Ellipse(extent={{50,10},{70,-10}}, fillPattern=FillPattern.Solid),
        Text(extent={{-48,15},{46,-20}}, textString="%nNodes")}),
Diagram(coordinateSystem(preserveAspectRatio=true,  extent={{-100,-100},{100,100}}), graphics={
        Rectangle(extent={{-100,60},{100,50}}, fillColor={255,255,255}, fillPattern=FillPattern.Backward),
        Rectangle(extent={{-100,-50},{100,-60}}, fillColor={255,255,255}, fillPattern=FillPattern.Backward),
        Line(points={{100,45},{100,50}}, arrow={Arrow.None,Arrow.Filled}, pattern=LinePattern.Dot),
        Line(points={{0,45},{0,50}}, arrow={Arrow.None,Arrow.Filled}, pattern=LinePattern.Dot),
        Line(points={{100,-45},{100,-50}}, arrow={Arrow.None,Arrow.Filled}, pattern=LinePattern.Dot),
        Line(points={{0,-45},{0,-50}}, arrow={Arrow.None,Arrow.Filled}, pattern=LinePattern.Dot),
        Line(points={{-50,60},{-50,50}}, pattern=LinePattern.Dot),
        Line(points={{50,60},{50,50}}, pattern=LinePattern.Dot),
        Line(points={{0,-50},{0,-60}}, pattern=LinePattern.Dot)}));
end DynamicPipe;