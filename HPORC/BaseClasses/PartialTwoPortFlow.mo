partial model PartialTwoPortFlow "分布式一维流体管路模型的基础基类 (实现有限体积法与交错网格离散化)"

  import Modelica.Fluid.Types.ModelStructure;
  import SI = Modelica.SIunits;
  import Types = Modelica.Fluid.Types;

  // =======================================================================
  // 1. 继承流体双端口太爷爷 (确立 DAE 暴露规则)
  // =======================================================================
  extends PartialTwoPort(
    final port_a_exposesState = (modelStructure == ModelStructure.av_b) or (modelStructure == ModelStructure.av_vb),
    final port_b_exposesState = (modelStructure == ModelStructure.a_vb) or (modelStructure == ModelStructure.av_vb));

  // =======================================================================
  // 2. 继承分布式容积计算核心 (自动切分出 n 个控制体积，用于求解质量和能量偏微分)
  // =======================================================================
  extends PartialDistributedVolume(
    final n = nNodes,
    final fluidVolumes = {crossAreas[i]*lengths[i] for i in 1:n}*nParallel);

  // =======================================================================
  // 3. 几何参数配置 (Geometry parameters)
  // =======================================================================
  parameter Real nParallel(min=1)=1
    "相同的平行流动设备数量 (用于极大地节省平行管束的计算量)" 
    annotation(Dialog(group="几何参数"));
  parameter SI.Length[n] lengths "各流体网格段的长度" 
    annotation(Dialog(group="几何参数"));
  parameter SI.Area[n] crossAreas "各流体网格段的流通截面积" 
    annotation(Dialog(group="几何参数"));
  parameter SI.Length[n] dimensions "各流体网格段的水力直径" 
    annotation(Dialog(group="几何参数"));
  parameter Modelica.Fluid.Types.Roughness[n] roughnesses
    "各流体网格段的表面绝对粗糙度" 
    annotation(Dialog(group="几何参数"));

  // =======================================================================
  // 4. 静压头参数 (Static head)
  // =======================================================================
  parameter SI.Length[n] dheights=zeros(n)
    "各流体网格段的高程差 (用于重力压降计算)" 
      annotation(Dialog(group="静压头"), Evaluate=true);

  // =======================================================================
  // 5. 模型假设 (Assumptions)
  // =======================================================================
  parameter Types.Dynamics momentumDynamics=system.momentumDynamics
    "动量平衡方程的动态求解形式 (稳态或动态)" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学设置"));

  // =======================================================================
  // 6. 初始化 (Initialization)
  // =======================================================================
  parameter Medium.MassFlowRate m_flow_start = system.m_flow_start
    "质量流量的初始猜测值" 
     annotation(Evaluate=true, Dialog(tab = "初始化"));

  // =======================================================================
  // 7. 离散化网格拓扑设置 (Discretization)
  // =======================================================================
  parameter Integer nNodes(min=1)=2 "离散的流体体积网格数量 (有限体积法节点数)" 
    annotation(Dialog(tab="高级设置"),Evaluate=true);

  parameter Types.ModelStructure modelStructure=Types.ModelStructure.av_vb
    "决定端口处是流体阻力模型还是容积模型 (极其关键的交错网格拓扑结构)" 
    annotation(Dialog(tab="高级设置"), Evaluate=true);

  parameter Boolean useLumpedPressure=false
    "= true 时，将所有网格的压力状态集总为一个统一压力 (牺牲一点精度极大提升求解速度)" 
    annotation(Dialog(tab="高级设置"),Evaluate=true);

  final parameter Integer nFM=if useLumpedPressure then nFMLumped else nFMDistributed
    "压降流动模型(FlowModel)的总数";
  final parameter Integer nFMDistributed=if modelStructure==Types.ModelStructure.a_v_b then n+1 else if (modelStructure==Types.ModelStructure.a_vb or modelStructure==Types.ModelStructure.av_b) then n else n-1
    "分布式流动模型的数量 (由两端拓扑结构动态决定)";
  final parameter Integer nFMLumped=if modelStructure==Types.ModelStructure.a_v_b then 2 else 1
    "集总流动模型的数量";
  final parameter Integer iLumped=integer(n/2)+1
    "开启集总压力时，代表全局压力的控制体积中心索引" 
    annotation(Evaluate=true);

  // =======================================================================
  // 8. 高级模型选项 (Advanced model options)
  // =======================================================================
  parameter Boolean useInnerPortProperties=false
    "= true 时，使用内部控制体积的属性作为流动模型的边界" 
    annotation(Dialog(tab="高级设置"),Evaluate=true);
  Medium.ThermodynamicState state_a
    "port_a 外部体积定义的热力学状态";
  Medium.ThermodynamicState state_b
    "port_b 外部体积定义的热力学状态";
  Medium.ThermodynamicState[nFM+1] statesFM
    "传递给 FlowModel 压降计算模型的状态向量 (尺寸与流动节点数量匹配)";

  // =======================================================================
  // 9. 压降阻力模型插槽与实体化 (Pressure loss model)
  // =======================================================================
  replaceable model FlowModel =
    Modelica.Fluid.Pipes.BaseClasses.FlowModels.DetailedPipeFlow 
    constrainedby 
    Modelica.Fluid.Pipes.BaseClasses.FlowModels.PartialStaggeredFlowModel
    "壁面摩擦、重力与动量流模型" 
      annotation(Dialog(group="压降设置"), choicesAllMatching=true);

  FlowModel flowModel(
          redeclare final package Medium = Medium,
          final n=nFM+1,
          final states=statesFM,
          final vs=vsFM,
          final momentumDynamics=momentumDynamics,
          final allowFlowReversal=allowFlowReversal,
          final p_a_start=p_a_start,
          final p_b_start=p_b_start,
          final m_flow_start=m_flow_start,
          final nParallel=nParallel,
          final pathLengths=pathLengths,
          final crossAreas=crossAreasFM,
          final dimensions=dimensionsFM,
          final roughnesses=roughnessesFM,
          final dheights=dheightsFM,
          final g=system.g) "流动阻力求解引擎实体" 
     annotation (Placement(transformation(extent={{-77,-37},{75,-19}})));

  // =======================================================================
  // 10. 流动物理量阵列 (Flow quantities)
  // =======================================================================
  Medium.MassFlowRate[n+1] m_flows(
     each min=if allowFlowReversal then -Modelica.Constants.inf else 0,
     each start=m_flow_start)
    "跨越各个网格边界的流体质量流量";
  Medium.MassFlowRate[n+1, Medium.nXi] mXi_flows
    "跨越网格边界的独立组分质量流量";
  Medium.MassFlowRate[n+1, Medium.nC] mC_flows
    "跨越网格边界的痕量物质质量流量";
  Medium.EnthalpyFlowRate[n+1] H_flows
    "跨越网格边界的流体焓流率 (对流传热项)";

  SI.Velocity[n] vs = {0.5*(m_flows[i] + m_flows[i+1])/mediums[i].d/crossAreas[i] for i in 1:n}/nParallel
    "各个流体网格段内部的平均流速 (利用交界面流量算数平均值反算)";

  // =======================================================================
  // 11. 交错网格所依赖的受保护阵列 (Model structure dependent flow geometry)
  // =======================================================================
protected
  SI.Length[nFM] pathLengths "沿流动路径的长度";
  SI.Length[nFM] dheightsFM "流动网格段之间的高程差";
  SI.Area[nFM+1] crossAreasFM "流动网格段的流通面积";
  SI.Velocity[nFM+1] vsFM "流动网格段的平均流速";
  SI.Length[nFM+1] dimensionsFM "流动网格段的水力直径";
  Modelica.Fluid.Types.Roughness[nFM+1] roughnessesFM "表面绝对粗糙度";

equation
  assert(nNodes > 1 or modelStructure <> ModelStructure.av_vb,
      "严重物理错误：当模型结构为 av_vb 时，网格数 nNodes 至少必须为 2，否则内部压降模型将被挤压至消失！");

  // =======================================================================
  // 12. 针对 FlowModel 的交错网格几何离散化映射 (极其复杂的数组重组)
  // =======================================================================
  if useLumpedPressure then
    if modelStructure <> ModelStructure.a_v_b then
      pathLengths[1] = sum(lengths);
      dheightsFM[1] = sum(dheights);
      if n == 1 then
        crossAreasFM[1:2] = {crossAreas[1], crossAreas[1]};
        dimensionsFM[1:2] = {dimensions[1], dimensions[1]};
        roughnessesFM[1:2] = {roughnesses[1], roughnesses[1]};
      else // n > 1
        crossAreasFM[1:2] = {sum(crossAreas[1:iLumped-1])/(iLumped-1), sum(crossAreas[iLumped:n])/(n-iLumped+1)};
        dimensionsFM[1:2] = {sum(dimensions[1:iLumped-1])/(iLumped-1), sum(dimensions[iLumped:n])/(n-iLumped+1)};
        roughnessesFM[1:2] = {sum(roughnesses[1:iLumped-1])/(iLumped-1), sum(roughnesses[iLumped:n])/(n-iLumped+1)};
      end if;
    else
      if n == 1 then
        pathLengths[1:2] = {lengths[1]/2, lengths[1]/2};
        dheightsFM[1:2] = {dheights[1]/2, dheights[1]/2};
        crossAreasFM[1:3] = {crossAreas[1], crossAreas[1], crossAreas[1]};
        dimensionsFM[1:3] = {dimensions[1], dimensions[1], dimensions[1]};
        roughnessesFM[1:3] = {roughnesses[1], roughnesses[1], roughnesses[1]};
      else // n > 1
        pathLengths[1:2] = {sum(lengths[1:iLumped-1]), sum(lengths[iLumped:n])};
        dheightsFM[1:2] = {sum(dheights[1:iLumped-1]), sum(dheights[iLumped:n])};
        crossAreasFM[1:3] = {sum(crossAreas[1:iLumped-1])/(iLumped-1), sum(crossAreas)/n, sum(crossAreas[iLumped:n])/(n-iLumped+1)};
        dimensionsFM[1:3] = {sum(dimensions[1:iLumped-1])/(iLumped-1), sum(dimensions)/n, sum(dimensions[iLumped:n])/(n-iLumped+1)};
        roughnessesFM[1:3] = {sum(roughnesses[1:iLumped-1])/(iLumped-1), sum(roughnesses)/n, sum(roughnesses[iLumped:n])/(n-iLumped+1)};
      end if;
    end if;
  else
    if modelStructure == ModelStructure.av_vb then
      // nFM = n-1 (两端为容积)
      if n == 2 then
        pathLengths[1] = lengths[1] + lengths[2];
        dheightsFM[1] = dheights[1] + dheights[2];
      else
        pathLengths[1:n-1] = cat(1, {lengths[1] + 0.5*lengths[2]}, 0.5*(lengths[2:n-2] + lengths[3:n-1]), {0.5*lengths[n-1] + lengths[n]});
        dheightsFM[1:n-1] = cat(1, {dheights[1] + 0.5*dheights[2]}, 0.5*(dheights[2:n-2] + dheights[3:n-1]), {0.5*dheights[n-1] + dheights[n]});
      end if;
      crossAreasFM[1:n] = crossAreas;
      dimensionsFM[1:n] = dimensions;
      roughnessesFM[1:n] = roughnesses;
    elseif modelStructure == ModelStructure.av_b then
      // nFM = n (非对称，b端为阻力)
      pathLengths[1:n] = lengths;
      dheightsFM[1:n] = dheights;
      crossAreasFM[1:n+1] = cat(1, crossAreas[1:n], {crossAreas[n]});
      dimensionsFM[1:n+1] = cat(1, dimensions[1:n], {dimensions[n]});
      roughnessesFM[1:n+1] = cat(1, roughnesses[1:n], {roughnesses[n]});
    elseif modelStructure == ModelStructure.a_vb then
      // nFM = n (非对称，a端为阻力)
      pathLengths[1:n] = lengths;
      dheightsFM[1:n] = dheights;
      crossAreasFM[1:n+1] = cat(1, {crossAreas[1]}, crossAreas[1:n]);
      dimensionsFM[1:n+1] = cat(1, {dimensions[1]}, dimensions[1:n]);
      roughnessesFM[1:n+1] = cat(1, {roughnesses[1]}, roughnesses[1:n]);
    elseif modelStructure == ModelStructure.a_v_b then
      // nFM = n+1 (两端均为阻力)
      pathLengths[1:n+1] = cat(1, {0.5*lengths[1]}, 0.5*(lengths[1:n-1] + lengths[2:n]), {0.5*lengths[n]});
      dheightsFM[1:n+1] = cat(1, {0.5*dheights[1]}, 0.5*(dheights[1:n-1] + dheights[2:n]), {0.5*dheights[n]});
      crossAreasFM[1:n+2] = cat(1, {crossAreas[1]}, crossAreas[1:n], {crossAreas[n]});
      dimensionsFM[1:n+2] = cat(1, {dimensions[1]}, dimensions[1:n], {dimensions[n]});
      roughnessesFM[1:n+2] = cat(1, {roughnesses[1]}, roughnesses[1:n], {roughnesses[n]});
    else
      assert(false, "Unknown model structure");
    end if;
  end if;

  // =======================================================================
  // 13. 质量与能量平衡的源/汇项 (控制体积内的净留存项)
  // =======================================================================
  for i in 1:n loop
    mb_flows[i] = m_flows[i] - m_flows[i + 1];
    mbXi_flows[i, :] = mXi_flows[i, :] - mXi_flows[i + 1, :];
    mbC_flows[i, :]  = mC_flows[i, :]  - mC_flows[i + 1, :];
    Hb_flows[i] = H_flows[i] - H_flows[i + 1];
  end for;

  // =======================================================================
  // 14. 分布式流体量的迎风差分離散化 (完美防止数值震荡的神仙函数)
  // =======================================================================
  for i in 2:n loop
    H_flows[i] = semiLinear(m_flows[i], mediums[i - 1].h, mediums[i].h);
    mXi_flows[i, :] = semiLinear(m_flows[i], mediums[i - 1].Xi, mediums[i].Xi);
    mC_flows[i, :]  = semiLinear(m_flows[i], Cs[i - 1, :],         Cs[i, :]);
  end for;
  H_flows[1] = semiLinear(port_a.m_flow, inStream(port_a.h_outflow), mediums[1].h);
  H_flows[n + 1] = -semiLinear(port_b.m_flow, inStream(port_b.h_outflow), mediums[n].h);
  mXi_flows[1, :] = semiLinear(port_a.m_flow, inStream(port_a.Xi_outflow), mediums[1].Xi);
  mXi_flows[n + 1, :] = -semiLinear(port_b.m_flow, inStream(port_b.Xi_outflow), mediums[n].Xi);
  mC_flows[1, :] = semiLinear(port_a.m_flow, inStream(port_a.C_outflow), Cs[1, :]);
  mC_flows[n + 1, :] = -semiLinear(port_b.m_flow, inStream(port_b.C_outflow), Cs[n, :]);

  // =======================================================================
  // 15. 边界条件传递
  // =======================================================================
  port_a.m_flow    = m_flows[1];
  port_b.m_flow    = -m_flows[n + 1];
  port_a.h_outflow = mediums[1].h;
  port_b.h_outflow = mediums[n].h;
  port_a.Xi_outflow = mediums[1].Xi;
  port_b.Xi_outflow = mediums[n].Xi;
  port_a.C_outflow = Cs[1, :];
  port_b.C_outflow = Cs[n, :];

  if useInnerPortProperties and n > 0 then
    state_a = Medium.setState_phX(port_a.p, mediums[1].h, mediums[1].Xi);
    state_b = Medium.setState_phX(port_b.p, mediums[n].h, mediums[n].Xi);
  else
    state_a = Medium.setState_phX(port_a.p, inStream(port_a.h_outflow), inStream(port_a.Xi_outflow));
    state_b = Medium.setState_phX(port_b.p, inStream(port_b.h_outflow), inStream(port_b.Xi_outflow));
  end if;

  // =======================================================================
  // 16. 针对 flowModel 的交错网格离散化状态分配
  // =======================================================================
  if useLumpedPressure then
    if modelStructure <> ModelStructure.av_vb then
      // 所有网格压力相等
      fill(mediums[1].p, n-1) = mediums[2:n].p;
    elseif n > 2 then
      // 需要拆分为两个核心压力区
      fill(mediums[1].p, iLumped-2) = mediums[2:iLumped-1].p;
      fill(mediums[n].p, n-iLumped) = mediums[iLumped:n-1].p;
    end if;
    if modelStructure == ModelStructure.av_vb then
      port_a.p = mediums[1].p;
      statesFM[1] = mediums[1].state;
      m_flows[iLumped] = flowModel.m_flows[1];
      statesFM[2] = mediums[n].state;
      port_b.p = mediums[n].p;
      vsFM[1] = vs[1:iLumped-1]*lengths[1:iLumped-1]/sum(lengths[1:iLumped-1]);
      vsFM[2] = vs[iLumped:n]*lengths[iLumped:n]/sum(lengths[iLumped:n]);
    elseif modelStructure == ModelStructure.av_b then
      port_a.p = mediums[1].p;
      statesFM[1] = mediums[iLumped].state;
      statesFM[2] = state_b;
      m_flows[n+1] = flowModel.m_flows[1];
      vsFM[1] = vs*lengths/sum(lengths);
      vsFM[2] = m_flows[n+1]/Medium.density(state_b)/crossAreas[n]/nParallel;
    elseif modelStructure == ModelStructure.a_vb then
      m_flows[1] = flowModel.m_flows[1];
      statesFM[1] = state_a;
      statesFM[2] = mediums[iLumped].state;
      port_b.p = mediums[n].p;
      vsFM[1] = m_flows[1]/Medium.density(state_a)/crossAreas[1]/nParallel;
      vsFM[2] = vs*lengths/sum(lengths);
    elseif modelStructure == ModelStructure.a_v_b then
      m_flows[1] = flowModel.m_flows[1];
      statesFM[1] = state_a;
      statesFM[2] = mediums[iLumped].state;
      statesFM[3] = state_b;
      m_flows[n+1] = flowModel.m_flows[2];
      vsFM[1] = m_flows[1]/Medium.density(state_a)/crossAreas[1]/nParallel;
      vsFM[2] = vs*lengths/sum(lengths);
      vsFM[3] = m_flows[n+1]/Medium.density(state_b)/crossAreas[n]/nParallel;
    else
      assert(false, "Unknown model structure");
    end if;
  else
    if modelStructure == ModelStructure.av_vb then
      // nFM = n-1
      statesFM[1:n] = mediums[1:n].state;
      m_flows[2:n] = flowModel.m_flows[1:n-1];
      vsFM[1:n] = vs;
      port_a.p = mediums[1].p;
      port_b.p = mediums[n].p;
    elseif modelStructure == ModelStructure.av_b then
      // nFM = n
      statesFM[1:n] = mediums[1:n].state;
      statesFM[n+1] = state_b;
      m_flows[2:n+1] = flowModel.m_flows[1:n];
      vsFM[1:n] = vs;
      vsFM[n+1] = m_flows[n+1]/Medium.density(state_b)/crossAreas[n]/nParallel;
      port_a.p = mediums[1].p;
    elseif modelStructure == ModelStructure.a_vb then
      // nFM = n
      statesFM[1] = state_a;
      statesFM[2:n+1] = mediums[1:n].state;
      m_flows[1:n] = flowModel.m_flows[1:n];
      vsFM[1] = m_flows[1]/Medium.density(state_a)/crossAreas[1]/nParallel;
      vsFM[2:n+1] = vs;
      port_b.p = mediums[n].p;
    elseif modelStructure == ModelStructure.a_v_b then
      // nFM = n+1
      statesFM[1] = state_a;
      statesFM[2:n+1] = mediums[1:n].state;
      statesFM[n+2] = state_b;
      m_flows[1:n+1] = flowModel.m_flows[1:n+1];
      vsFM[1] = m_flows[1]/Medium.density(state_a)/crossAreas[1]/nParallel;
      vsFM[2:n+1] = vs;
      vsFM[n+2] = m_flows[n+1]/Medium.density(state_b)/crossAreas[n]/nParallel;
    else
      assert(false, "Unknown model structure");
    end if;
  end if;

  // =======================================================================
  // 17. 图形注解与官方汉化说明文档
  // =======================================================================
  annotation (defaultComponentName="pipe",
Documentation(info="<html>
<p>分布式流动模型的基础基类。流体的总容积沿流动路径被离散切分为 <code>nNodes</code> 个独立网格段。默认值为 <code>nNodes=2</code>。</p>
<h4>质量与能量守恒 (Mass and Energy balances)</h4>
<p>
质量与能量守恒方程继承自 <code>PartialDistributedVolume</code>。
基于有限体积法 (FVM) 的思想，每个网格段都会建立一个总体积质量守恒和一个总能量守恒方程。如果流体包含多种组分，还会自动添加各组分的质量守恒方程。
</p>
<p>
任何继承本基类的模型，都必须定义几何参数以及各网格段之间的高程差（用于计算静压头）。
此外，还必须为分布式的能量守恒方程定义两个源项向量：
</p>
<ul>
<li><code><strong>Qb_flows[nNodes]</strong></code>：热流源项，例如跨越管壁边界的传导热流。</li>
<li><code><strong>Wb_flows[nNodes]</strong></code>：机械功源项 (压降耗散生热)。</li>
</ul>

<h4>动量守恒 (Momentum balance)</h4>
<p>
动量守恒由 <strong><code>FlowModel</code></strong> 组件决定，它可以被任何继承自 <code>PartialStaggeredFlowModel</code> 的压降模型替换。
默认设置为详细管道流模型 <code>DetailedPipeFlow</code>。
</p>
<p>
该模型综合考虑了：
</p>
<ul>
<li>由于壁面摩擦和其他耗散损失引起的压降。</li>
<li>由于管道倾斜（非水平设备）引起的重力静压降。</li>
<li>沿流动路径因截面积变化或流体密度变化引起的动量加速/减速压降（需启用 <code>use_Ib_flows</code>）。</li>
</ul>

<h4>模型结构拓扑 (Model Structure)</h4>
<p>
动量守恒方程是基于<strong>交错网格方法 (Staggered Grid Approach)</strong> 建立在各个流动网格段交界处的。
参数 <strong><code>modelStructure</code></strong> 决定了 <code>port_a</code> 和 <code>port_b</code> 两个端点处的边界条件形式。
包含以下选项（默认选项为 av_vb）：
</p>
<ul>
<li><code>av_vb</code>：对称设置。在 nNodes 个体积节点之间，布置 nNodes-1 个动量阻力节点。
    端口 <code>port_a</code> 和 <code>port_b</code> 分别向外暴露第一个和最后一个热力学体积状态。
    <strong>警告：</strong>将多个以此模式设置的流动设备直接相连，会导致求解压力状态时出现极易崩溃的<strong>高指数 DAE (微分代数方程组)</strong>。</li>
<li><code>a_v_b</code>：替代的对称设置。在 nNodes 个体积节点之上，布置 nNodes+1 个动量阻力节点。
    在 <code>port_a</code> 与第一个容积之间、最后一个容积与 <code>port_b</code> 之间，被强行插入了半个动量阻力节点。
    连接以此模式设置的设备时，端口处只存在代数压力，从而彻底消除了 DAE 死锁。
    <strong>注意：</strong>为端口压力提供良好的初始猜测值，对于求解这种大型非线性代数方程组至关重要。</li>
<li><code>av_b</code>：非对称设置，包含 nNodes 个动量平衡节点。在第 n 个体积节点和 <code>port_b</code> 之间存在一个阻力节点，而 <code>port_a</code> 处暴露压力状态。</li>
<li><code>a_vb</code>：非对称设置，包含 nNodes 个动量平衡节点。在第一个体积节点和 <code>port_a</code> 之间存在一个阻力节点，而 <code>port_b</code> 处暴露压力状态。</li>
</ul>
<p>
当你将两个组件（例如两根管道）直接相连时，连接点处的动量守恒会自动退化为：
</p>
<blockquote><pre>pipe1.port_b.p = pipe2.port_a.p</pre></blockquote>
<p>
注意：这仅在连接点两侧的流速相同时才在物理上严格成立。如果连接处直径或流体密度发生显著变化（如动能突变不可忽略），强烈建议在中间手动插入一个局部阻力件（Fitting）。
</p>
</html>",
    revisions="<html>
<ul>
<li><em>2008年12月5日</em> 由 Michael Wetter 修改：修改了痕量物质的质量守恒方程。</li>
<li><em>2008年12月</em> 由 R&uuml;diger Franke 修改：从原始的 DistributedPipe 派生出本基类，将平衡方程移至容积基类，并引入了彻底解决 DAE 问题的 <code>modelStructure</code> 体系。</li>
<li><em>2006年3月4日</em> 由 Katrin Pr&ouml;l&szlig; 创建：首次将本模型添加入 Fluid 官方库。</li>
</ul>
</html>"),
// 以下为极度庞大且精细的交错网格 Diagram 结构展示绘图代码 (保持原样不动)
Icon(coordinateSystem(preserveAspectRatio=true,  extent={{-100,-100},{100,
            100}}), graphics={Ellipse(
          extent={{-72,10},{-52,-10}},
          fillPattern=FillPattern.Solid), Ellipse(
          extent={{50,10},{70,-10}},
          fillPattern=FillPattern.Solid)}),
Diagram(coordinateSystem(preserveAspectRatio=true,  extent={{-100,-100},{
            100,100}}), graphics={
        Polygon(
          points={{-100,-50},{-100,50},{100,60},{100,-60},{-100,-50}},
          fillColor={215,215,215},
          fillPattern=FillPattern.Solid,
          pattern=LinePattern.None),
        Polygon(
          points={{-34,-53},{-34,53},{34,57},{34,-57},{-34,-53}},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid,
          pattern=LinePattern.None),
        Line(
          points={{-100,-50},{-100,50}},
          arrow={Arrow.Filled,Arrow.Filled},
          pattern=LinePattern.Dot),
        Text(
          extent={{-99,36},{-69,30}},
          textColor={0,0,255},
          textString="crossAreas[1]"),
        Line(
          points={{-100,70},{-34,70}},
          arrow={Arrow.Filled,Arrow.Filled},
          pattern=LinePattern.Dot),
        Text(
          extent={{0,36},{40,30}},
          textColor={0,0,255},
          textString="crossAreas[2:n-1]"),
        Line(
          points={{100,-60},{100,60}},
          arrow={Arrow.Filled,Arrow.Filled},
          pattern=LinePattern.Dot),
        Text(
          extent={{100.5,36},{130.5,30}},
          textColor={0,0,255},
          textString="crossAreas[n]"),
        Line(
          points={{-34,52},{-34,-53}},
          pattern=LinePattern.Dash),
        Line(
          points={{34,57},{34,-57}},
          pattern=LinePattern.Dash),
        Line(
          points={{34,70},{100,70}},
          arrow={Arrow.Filled,Arrow.Filled},
          pattern=LinePattern.Dot),
        Line(
          points={{-34,70},{34,70}},
          arrow={Arrow.Filled,Arrow.Filled},
          pattern=LinePattern.Dot),
        Text(
          extent={{-30,77},{30,71}},
          textColor={0,0,255},
          textString="lengths[2:n-1]"),
        Line(
          points={{-100,-70},{0,-70}},
          arrow={Arrow.None,Arrow.Filled}),
        Text(
          extent={{-80,-63},{-20,-69}},
          textColor={0,0,255},
          textString="flowModel.dps_fg[1]"),
        Line(
          points={{0,-70},{100,-70}},
          arrow={Arrow.None,Arrow.Filled}),
        Text(
          extent={{20.5,-63},{80,-69}},
          textColor={0,0,255},
          textString="flowModel.dps_fg[2:n-1]"),
        Line(
          points={{-95,0},{-5,0}},
          arrow={Arrow.None,Arrow.Filled}),
        Text(
          extent={{-62,7},{-32,1}},
          textColor={0,0,255},
          textString="m_flows[2]"),
        Line(
          points={{5,0},{95,0}},
          arrow={Arrow.None,Arrow.Filled}),
        Text(
          extent={{34,7},{64,1}},
          textColor={0,0,255},
          textString="m_flows[3:n]"),
        Line(
          points={{-150,0},{-105,0}},
          arrow={Arrow.None,Arrow.Filled}),
        Line(
          points={{105,0},{150,0}},
          arrow={Arrow.None,Arrow.Filled}),
        Text(
          extent={{-140,7},{-110,1}},
          textColor={0,0,255},
          textString="m_flows[1]"),
        Text(
          extent={{111,7},{141,1}},
          textColor={0,0,255},
          textString="m_flows[n+1]"),
        Text(
          extent={{35,-92},{100,-98}},
          textColor={0,0,255},
          textString="(ModelStructure av_vb, n=3)"),
        Line(
          points={{-100,-50},{-100,-86}},
          pattern=LinePattern.Dot),
        Line(
          points={{0,-55},{0,-86}},
          pattern=LinePattern.Dot),
        Line(
          points={{100,-60},{100,-86}},
          pattern=LinePattern.Dot),
        Ellipse(
          extent={{-5,5},{5,-5}},
          pattern=LinePattern.None,
          fillPattern=FillPattern.Solid),
        Text(
          extent={{3,-4},{33,-10}},
          textColor={0,0,255},
          textString="states[2:n-1]"),
        Ellipse(
          extent={{95,5},{105,-5}},
          pattern=LinePattern.None,
          fillPattern=FillPattern.Solid),
        Text(
          extent={{104,-4},{124,-10}},
          textColor={0,0,255},
          textString="states[n]"),
        Ellipse(
          extent={{-105,5},{-95,-5}},
          pattern=LinePattern.None,
          fillPattern=FillPattern.Solid),
        Text(
          extent={{-96,-4},{-76,-10}},
          textColor={0,0,255},
          textString="states[1]"),
        Text(
          extent={{-99.5,30},{-69.5,24}},
          textColor={0,0,255},
          textString="dimensions[1]"),
        Text(
          extent={{-0.5,30},{40,24}},
          textColor={0,0,255},
          textString="dimensions[2:n-1]"),
        Text(
          extent={{100.5,30},{130.5,24}},
          textColor={0,0,255},
          textString="dimensions[n]"),
        Line(
          points={{-34,73},{-34,52}},
          pattern=LinePattern.Dot),
        Line(
          points={{34,73},{34,57}},
          pattern=LinePattern.Dot),
        Line(
          points={{-100,50},{100,60}},
          thickness=0.5),
        Line(
          points={{-100,-50},{100,-60}},
          thickness=0.5),
        Line(
          points={{-100,73},{-100,50}},
          pattern=LinePattern.Dot),
        Line(
          points={{100,73},{100,60}},
          pattern=LinePattern.Dot),
        Line(
          points={{0,-55},{0,55}},
          arrow={Arrow.Filled,Arrow.Filled},
          pattern=LinePattern.Dot),
        Line(
          points={{-34,11},{34,11}},
          arrow={Arrow.None,Arrow.Filled}),
        Text(
          extent={{5,18},{25,12}},
          textColor={0,0,255},
          textString="vs[2:n-1]"),
        Text(
          extent={{-72,18},{-62,12}},
          textColor={0,0,255},
          textString="vs[1]"),
        Line(
          points={{-100,11},{-34,11}},
          arrow={Arrow.None,Arrow.Filled}),
        Text(
          extent={{63,18},{73,12}},
          textColor={0,0,255},
          textString="vs[n]"),
        Line(
          points={{34,11},{100,11}},
          arrow={Arrow.None,Arrow.Filled}),
        Text(
          extent={{-80,-75},{-20,-81}},
          textColor={0,0,255},
          textString="flowModel.pathLengths[1]"),
        Line(
          points={{-100,-82},{0,-82}},
          arrow={Arrow.Filled,Arrow.Filled}),
        Line(
          points={{0,-82},{100,-82}},
          arrow={Arrow.Filled,Arrow.Filled}),
        Text(
          extent={{15,-75},{85,-81}},
          textColor={0,0,255},
          textString="flowModel.pathLengths[2:n-1]"),
        Text(
          extent={{-100,77},{-37,71}},
          textColor={0,0,255},
          textString="lengths[1]"),
        Text(
          extent={{34,77},{100,71}},
          textColor={0,0,255},
          textString="lengths[n]")}));
end PartialTwoPortFlow;