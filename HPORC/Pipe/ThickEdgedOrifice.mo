model ThickEdgedOrifice "厚壁孔板局部流阻模型 (完美解决容积节点 DAE 死锁的缓冲件)"

  // 继承孔板的图标属性
  extends Modelica.Fluid.Dissipation.Utilities.Icons.PressureLoss.Orifice_i;
  // 继承局部压降的基础接口 (自带端口 a/b, 压降 dp, 流量 m_flow 等变量)
  extends HPORC.BaseClasses.PartialPressureLoss;

  // =======================================================================
  // 1. 几何参数配置
  // =======================================================================
  parameter Modelica.Fluid.Fittings.BaseClasses.Orifices.ThickEdgedOrifice.Geometry geometry
    "厚壁孔板的几何特征 (包含截面积、湿周、缩流长度等)" 
      annotation (Placement(transformation(extent={{-20,0},{0,20}})),
      choices(
      choice=Modelica.Fluid.Fittings.BaseClasses.Orifices.ThickEdgedOrifice.Choices.circular(),
      choice=Modelica.Fluid.Fittings.BaseClasses.Orifices.ThickEdgedOrifice.Choices.rectangular(),
      choice=Modelica.Fluid.Fittings.BaseClasses.Orifices.ThickEdgedOrifice.Choices.general()));

protected
  // =======================================================================
  // 2. 零流量正则化参数 (防崩溃核心)
  // =======================================================================
  parameter Medium.AbsolutePressure dp_small(min=0)=
             Modelica.Fluid.Dissipation.PressureLoss.Orifice.dp_thickEdgedOverall_DP(
             Modelica.Fluid.Dissipation.PressureLoss.Orifice.dp_thickEdgedOverall_IN_con(
                   A_0=geometry.venaCrossArea,
                   A_1=geometry.crossArea,
                   C_0=geometry.venaPerimeter,
                   C_1=geometry.perimeter,
                   L=geometry.venaLength,
                   dp_smooth=1e-10),
                Modelica.Fluid.Dissipation.PressureLoss.Orifice.dp_thickEdgedOverall_IN_var(
                  rho=Medium.density(state_dp_small),
                  eta=Medium.dynamicViscosity(state_dp_small)),
                m_flow_small)
    "默认极小压降：用于在层流区和零流量点附近进行曲线正则化平滑，防止导数无穷大致使求解器崩溃 (由 m_flow_small 反算得出)";

equation
  // =======================================================================
  // 3. 压降与流量的代数方程求解
  // =======================================================================
  if allowFlowReversal then
     // 如果允许反向流动，调用底层专用的双向稳健求解函数
     m_flow = Modelica.Fluid.Fittings.BaseClasses.Orifices.ThickEdgedOrifice.massFlowRate(
                dp, geometry, d_a, d_b, eta_a, eta_b, dp_small, m_flow_small);
  else
     // 如果仅限单向流动 (a -> b)，直接调用单向耗散压降关联式计算质量流量
     m_flow = Modelica.Fluid.Dissipation.PressureLoss.Orifice.dp_thickEdgedOverall_MFLOW(
                 Modelica.Fluid.Dissipation.PressureLoss.Orifice.dp_thickEdgedOverall_IN_con(
                   A_0=geometry.venaCrossArea,
                   A_1=geometry.crossArea,
                   C_0=geometry.venaPerimeter,
                   C_1=geometry.perimeter,
                   L=geometry.venaLength,
                   dp_smooth=dp_small),
                Modelica.Fluid.Dissipation.PressureLoss.Orifice.dp_thickEdgedOverall_IN_var(rho=d_a, eta=eta_a), dp);
  end if;

  // =======================================================================
  // 图形与官方说明文档 (已全面汉化)
  // =======================================================================
  annotation (Documentation(info="<html>
<p>
本组件模拟了一个带有尖锐边缘的<strong>厚壁孔板 (Thick Edged Orifice)</strong>。
<br>适用于不可压缩流体和单相流体流过任意形状截面（如圆形、方形等）的全局流动状态，并且考虑了表面粗糙度的影响。预期该组件也可以处理马赫数 <b>Ma < 0.3</b> 的可压缩流体。
<br><strong>核心假设：</strong>本组件内部不储存任何质量和能量（纯阻力代数方程）。
</p>

<p>
在模型底层，主要调用了一个复杂的函数来将质量流量作为压降的函数进行计算。同时，底层库也为该函数定义了<strong>反函数</strong>。智能求解器在处理复杂管网时，可以自动调用反函数来避免求解非线性代数方程组，极大提升了计算速度与稳定性。
</p>

<p>
若需了解详细的经验关联式与数学模型，请参阅底层函数的
<a href=\"modelica://Modelica.Fluid.Dissipation.Utilities.SharedDocumentation.PressureLoss.Orifice.dp_thickEdgedOverall\">相关文档</a>。
</p>

</html>"));
end ThickEdgedOrifice;