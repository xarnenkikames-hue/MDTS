model WallConstProps
  "带热惯性的管壁模型，假设一维热传导及恒定材料物性"
  import SI = Modelica.SIunits;
  parameter Integer n(min=1)=1
    "垂直于热传导方向（即轴向）的离散网格数";

//Geometry (几何尺寸)
  parameter SI.Length s "管壁厚度";
  parameter SI.Area area_h "总换热面积";

//Material properties (材料物性)
  parameter SI.Density rho_wall "管壁材料密度";
  parameter SI.SpecificHeatCapacity c_wall
    "管壁材料比热容 (决定热惯性大小)";
  parameter SI.ThermalConductivity k_wall
    "管壁材料导热系数 (决定内部热阻)";
  parameter SI.Mass[n] m=fill(rho_wall*area_h*s/n,n)
    "管壁质量在各离散网格中的分布";

//Initialization (初始化与全局系统)
  outer Modelica.Fluid.System system;
  parameter Modelica.Fluid.Types.Dynamics energyDynamics=system.energyDynamics
    "能量守恒方程的求解形式 (动态求解或稳态求解)" 
    annotation(Evaluate=true, Dialog(tab = "Assumptions", group="Dynamics"));
  parameter SI.Temperature T_start "管壁中心温度的初始猜测值";
  parameter SI.Temperature dT "两侧表面温差 (port_b.T - port_a.T) 的初始猜测值";

//Temperatures (温度与热端口声明)
  SI.Temperature[n] Tb(each start=T_start+0.5*dT) "外侧表面温度 (靠近壳程)";
  SI.Temperature[n] Ta(each start=T_start-0.5*dT) "内侧表面温度 (靠近管程)";
  SI.Temperature[n] T(start=ones(n)*T_start, each stateSelect=StateSelect.prefer)
    "管壁中心温度 (核心积分状态变量)";

  Modelica.Thermal.HeatTransfer.Interfaces.HeatPort_a[n] heatPort_a
    "内侧流体热端口" 
    annotation (Placement(transformation(extent={{-20,40},{20,60}})));
  Modelica.Thermal.HeatTransfer.Interfaces.HeatPort_a[n] heatPort_b
    "外侧流体热端口" 
    annotation (Placement(transformation(extent={{-20,-40},{20,-60}})));

initial equation
  // 仿真起始时刻 (t=0) 的初值给定逻辑
  if energyDynamics == Modelica.Fluid.Types.Dynamics.SteadyStateInitial then
    der(T) = zeros(n); // 稳态初始化：强制初始时刻温度变化率为0
  elseif energyDynamics == Modelica.Fluid.Types.Dynamics.FixedInitial then
    T = ones(n)*T_start; // 动态初始化：强制使用设定的初始温度
  end if;

equation
  // =======================================================================
  // 核心控制方程：遍历每个金属离散网格，应用能量守恒与傅里叶定律
  // =======================================================================
  for i in 1:n loop
    assert(m[i]>0, "物理错误：管壁质量必须大于0");

    // 【储能方程】：应用集总参数法计算热惯性 (c*m*dT/dt = Qin + Qout)
    if energyDynamics == Modelica.Fluid.Types.Dynamics.SteadyState then
      0 = heatPort_a[i].Q_flow + heatPort_b[i].Q_flow; // 稳态不储热
    else
      c_wall*m[i]*der(T[i]) = heatPort_a[i].Q_flow + heatPort_b[i].Q_flow; // 动态储热方程
    end if;

    // 【导热方程】：假设热量从表面传至中心的距离为 s/2，内部热阻系数为 2*k/s
    heatPort_a[i].Q_flow=2*k_wall/s*(Ta[i]-T[i])*area_h/n; // 内表面到中心的传热量
    heatPort_b[i].Q_flow=2*k_wall/s*(Tb[i]-T[i])*area_h/n; // 外表面到中心的传热量
  end for;

  // 端口温度闭合：将计算出的表面温度赋予对外连接的端口
  Ta=heatPort_a.T;
  Tb=heatPort_b.T;

  // =======================================================================
  // 图形注解与官方说明文档 (已全面汉化)
  // =======================================================================
    annotation (Icon(coordinateSystem(preserveAspectRatio=false, extent={{-100,
            -100},{100,100}}), graphics={Rectangle(
          extent={{-100,40},{100,-40}},
          fillColor={95,95,95},
          fillPattern=FillPattern.Forward), Text(
          extent={{-82,18},{76,-18}},
          textString="%name")}),
                            Documentation(revisions="<html>
<ul>
<li><em>2006年3月4日</em>
    作者: Katrin Pr&ouml;l&szlig;:<br>
        将此模型添加至 Fluid 官方库</li>
</ul>
</html>",      info="<html>
<p>
用于管道（或导管）模型的圆形（或其他封闭形状）管壁的简化模型。
热传导被严格视为一维过程，热容（电容）集中在算术平均温度处（即采用集总参数法）。
空间离散化（参数 <code>n</code>）旨在与相连的流体模型离散网格保持完美对齐。
</p>
</html>"));
end WallConstProps;