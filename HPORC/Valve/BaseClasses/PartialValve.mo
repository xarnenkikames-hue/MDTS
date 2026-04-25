partial model PartialValve "所有阀门的基础物理骨架 (处理开度滤波、流导换算与绝对等焓膨胀)"

  import Modelica.Fluid.Types.CvTypes;
  import SI = Modelica.SIunits;

  // 继承自双端口传输基类，初始化了动量方程的默认值
  extends HPORC.BaseClasses.PartialTwoPortTransport(
    dp_start = dp_nominal,
    m_flow_small = if system.use_eps_Re then system.eps_m_flow*m_flow_nominal else system.m_flow_small,
    m_flow_start = m_flow_nominal);

  parameter Modelica.Fluid.Types.CvTypes CvData=Modelica.Fluid.Types.CvTypes.OpPoint
    "流导系数的输入方式选择 (默认通过额定工作点反推)" 
   annotation(Dialog(group = "Flow coefficient"));

  parameter SI.Area Av(
    fixed= CvData == Modelica.Fluid.Types.CvTypes.Av,
    start=m_flow_nominal/(sqrt(rho_nominal*dp_nominal))*valveCharacteristic(
        opening_nominal)) "Av (公制) 流通面积系数" 
   annotation(Dialog(group = "Flow coefficient",
                     enable = (CvData==Modelica.Fluid.Types.CvTypes.Av)));

  parameter Real Kv = 0 "Kv (公制) 流量系数 [m3/h]" 
  annotation(Dialog(group = "Flow coefficient",
                    enable = (CvData==Modelica.Fluid.Types.CvTypes.Kv)));

  parameter Real Cv = 0 "Cv (英美制) 流量系数 [USG/min]" 
  annotation(Dialog(group = "Flow coefficient",
                    enable = (CvData==Modelica.Fluid.Types.CvTypes.Cv)));

  parameter SI.Pressure dp_nominal "额定压降" 
  annotation(Dialog(group="Nominal operating point"));

  parameter Medium.MassFlowRate m_flow_nominal "额定质量流量" 
  annotation(Dialog(group="Nominal operating point"));

  parameter Medium.Density rho_nominal=Medium.density_pTX(Medium.p_default, Medium.T_default, Medium.X_default)
    "额定入口密度" 
  annotation(Dialog(group="Nominal operating point",
                    enable = (CvData==Modelica.Fluid.Types.CvTypes.OpPoint)));

  parameter Real opening_nominal(min=0,max=1)=1 "额定开度" 
  annotation(Dialog(group="Nominal operating point",
                    enable = (CvData==Modelica.Fluid.Types.CvTypes.OpPoint)));

  parameter Boolean filteredOpening=false
    "= true 时，控制开度将被一个二阶临界阻尼滤波器平滑处理" 
    annotation(Dialog(group="Filtered opening"),choices(checkBox=true));

  parameter SI.Time riseTime=1
    "滤波器的上升时间 (定义为达到阶跃输入开度 99.6% 所需的时间)" 
    annotation(Dialog(group="Filtered opening",enable=filteredOpening));

  parameter Real leakageOpening(min=0,max=1)=1e-3
    "控制信号会被限制在不低于 leakageOpening 的值 (防止完全关闭导致网络拓扑奇异，极大提升数值鲁棒性)" 
    annotation(Dialog(group="Filtered opening",enable=filteredOpening));

  parameter Boolean checkValve=false "是否启用单向阀模式 (阻止反向流动)" 
    annotation(Dialog(tab="Assumptions"));

  replaceable function valveCharacteristic = ValveCharacteristics.linear 
    constrainedby 
    ValveCharacteristics.baseFun
    "固有的流量特性曲线" 
    annotation(choicesAllMatching=true);

protected
  parameter SI.Pressure dp_small=if system.use_eps_Re then dp_nominal/m_flow_nominal*m_flow_small else system.dp_small
    "零流量的正则化平滑" 
   annotation(Dialog(tab="Advanced"));

public
  constant SI.Area Kv2Av = 27.7e-6 "Kv 转换因子";
  constant SI.Area Cv2Av = 24.0e-6 "Cv 转换因子";

  Modelica.Blocks.Interfaces.RealInput opening(min=0, max=1)
    "阀门开度指令 (范围 0..1)" 
                                     annotation (Placement(transformation(
        origin={0,90}, extent={{-20,-20},{20,20}}, rotation=270), iconTransformation(
        extent={{-20,-20},{20,20}}, rotation=270, origin={0,80})));

  Modelica.Blocks.Interfaces.RealOutput opening_filtered if filteredOpening
    "滤波后的实际阀门开度 (范围 0..1)" 
    annotation (Placement(transformation(extent={{60,40},{80,60}}),
        iconTransformation(extent={{60,50},{80,70}})));

  Modelica.Blocks.Continuous.Filter filter(order=2, f_cut=5/(2*Modelica.Constants.pi
        *riseTime)) if filteredOpening 
    annotation (Placement(transformation(extent={{34,44},{48,58}})));

protected
  Modelica.Blocks.Interfaces.RealOutput opening_actual 
    annotation (Placement(transformation(extent={{60,10},{80,30}})));

// =====================================================================
// 内部组件：最小值限制器 (用于强制注入泄漏量，防止 0 开度死机)
// =====================================================================
block MinLimiter "限制信号不得低于设定的阈值"
 parameter Real uMin=0 "输入信号的物理下限";
 extends Modelica.Blocks.Interfaces.SISO;

equation
  y = smooth(0, noEvent( if u < uMin then uMin else u));
  annotation (
    Documentation(info="<html>
<p>
该模块将输入信号直接作为输出传递，只要输入信号大于 uMin。
如果输入信号小于 uMin，则强制输出 y=uMin。
</p>
</html>"), Icon(coordinateSystem(
    preserveAspectRatio=true,
    extent={{-100,-100},{100,100}}), graphics={
    Line(points={{0,-90},{0,68}}, color={192,192,192}),
    Polygon(
      points={{0,90},{-8,68},{8,68},{0,90}},
      lineColor={192,192,192},
      fillColor={192,192,192},
      fillPattern=FillPattern.Solid),
    Line(points={{-90,0},{68,0}}, color={192,192,192}),
    Polygon(
      points={{90,0},{68,-8},{68,8},{90,0}},
      lineColor={192,192,192},
      fillColor={192,192,192},
      fillPattern=FillPattern.Solid),
    Line(points={{-80,-70},{-50,-70},{50,70},{64,90}}),
    Text(
      extent={{-150,-150},{150,-110}},
      textString="uMin=%uMin"),
    Text(
      extent={{-150,150},{150,110}},
      textString="%name",
      textColor={0,0,255})}),
    Diagram(coordinateSystem(
    preserveAspectRatio=true,
    extent={{-100,-100},{100,100}}), graphics={
    Line(points={{0,-60},{0,50}}, color={192,192,192}),
    Polygon(
      points={{0,60},{-5,50},{5,50},{0,60}},
      lineColor={192,192,192},
      fillColor={192,192,192},
      fillPattern=FillPattern.Solid),
    Line(points={{-60,0},{50,0}}, color={192,192,192}),
    Polygon(
      points={{60,0},{50,-5},{50,5},{60,0}},
      lineColor={192,192,192},
      fillColor={192,192,192},
      fillPattern=FillPattern.Solid),
    Line(points={{-50,-40},{-30,-40},{30,40},{50,40}}),
    Text(
      extent={{46,-6},{68,-18}},
      textColor={128,128,128},
      textString="u"),
    Text(
      extent={{-30,70},{-5,50}},
      textColor={128,128,128},
      textString="y"),
    Text(
      extent={{-58,-54},{-28,-42}},
      textColor={128,128,128},
      textString="uMin"),
    Text(
      extent={{26,40},{66,56}},
      textColor={128,128,128},
      textString="uMax")}));
end MinLimiter;

  MinLimiter minLimiter(uMin=leakageOpening) 
    annotation (Placement(transformation(extent={{10,44},{24,58}})));

initial equation
  if CvData == CvTypes.Kv then
    Av = Kv*Kv2Av "单位转换";
  elseif CvData == CvTypes.Cv then
    Av = Cv*Cv2Av "单位转换";
  end if;

equation
  // =====================================================================
  // 【最高热力学铁律】：绝对等焓状态变换 (Isenthalpic state transformation)
  // =====================================================================
  port_a.h_outflow = inStream(port_b.h_outflow);
  port_b.h_outflow = inStream(port_a.h_outflow);

  connect(filter.y, opening_filtered) annotation (Line(
      points={{48.7,51},{60,51},{60,50},{70,50}}, color={0,0,127}));

  if filteredOpening then
     connect(filter.y, opening_actual);
  else
     connect(opening, opening_actual);
  end if;

  connect(minLimiter.y, filter.u) annotation (Line(
      points={{24.7,51},{32.6,51}}, color={0,0,127}));
  connect(minLimiter.u, opening) annotation (Line(
      points={{8.6,51},{0,51},{0,90}}, color={0,0,127}));

  annotation (
    Icon(coordinateSystem(
        preserveAspectRatio=true,
        extent={{-100,-100},{100,100}}), graphics={
        Line(points={{0,52},{0,0}}),
        Rectangle(
          extent={{-20,60},{20,52}},
          fillPattern=FillPattern.Solid),
        Polygon(
          points={{-100,50},{100,-50},{100,50},{0,0},{-100,-50},{-100,50}},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid),
        Polygon(
          points=DynamicSelect({{-100,0},{100,-0},{100,0},{0,0},{-100,-0},{
              -100,0}}, {{-100,50*opening_actual},{-100,50*opening_actual},{100,-50*
              opening},{100,50*opening_actual},{0,0},{-100,-50*opening_actual},{-100,50*
              opening}}),
          fillColor={0,255,0},
          lineColor={255,255,255},
          fillPattern=FillPattern.Solid),
        Polygon(points={{-100,50},{100,-50},{100,50},{0,0},{-100,-50},{-100,
              50}}),
        Ellipse(visible=filteredOpening,
          extent={{-40,94},{40,14}},
          lineColor={0,0,127},
          fillColor={255,255,255},
          fillPattern=FillPattern.Solid),
        Line(visible=filteredOpening,
          points={{-20,25},{-20,63},{0,41},{20,63},{20,25}},
          thickness=0.5),
        Line(visible=filteredOpening,
          points={{40,60},{60,60}},
          color={0,0,127})}),
    Documentation(info="<html>
<p>本模型是 <code>ValveIncompressible</code>, <code>ValveVaporizing</code>, 以及 <code>ValveCompressible</code> 的基类模型。模型基于 IEC 534 / ISA S.75 标准进行阀门尺寸计算。</p>
<p>该模型可选支持反向流动（假设对称行为）或单向阀模式。与标准中的原始方程相比，本模型进行了适当的数学正则化 (regularized) 处理，以彻底避免在压降接近零时的数值奇异性。</p>
<p>模型假定为绝热过程（无对环境的热损失）；在能量平衡中忽略了从入口到出口的动能变化（绝对等焓）。</p>
<p><strong>建模选项 (Modelling options)</strong></p>
<p>可以使用以下选项来指定阀门在全开状态下的流通系数：</p>
<ul><li><code>CvData = Modelica.Fluid.Types.CvTypes.Av</code>: 流通系数由公制 <code>Av</code> 系数 (m^2) 给定。</li>
<li><code>CvData = Modelica.Fluid.Types.CvTypes.Kv</code>: 流通系数由公制 <code>Kv</code> 系数 (m^3/h) 给定。</li>
<li><code>CvData = Modelica.Fluid.Types.CvTypes.Cv</code>: 流通系数由美制 <code>Cv</code> 系数 (USG/min) 给定。</li>
<li><code>CvData = Modelica.Fluid.Types.CvTypes.OpPoint</code>: 流通能力由额定工作点参数反推计算：<code>p_nominal</code>, <code>dp_nominal</code>, <code>m_flow_nominal</code>, <code>rho_nominal</code>, <code>opening_nominal</code>。</li>
</ul>
<p>必须始终指定额定压降 <code>dp_nominal</code>；为避免数值奇异性，当压降小于 <code>b*dp_nominal</code>（默认值为额定压降的 1%）时，流量特性将被修改平滑。如果在极低压降下发生数值问题，请增大此参数。</p>
<p>如果 <code>checkValve</code> 为 true，则当出口压力高于入口压力时，流体被截止；否则允许反向流动。请仅在需要时使用此选项，因为它会增加方程的数值复杂性。</p>
<p>阀门的开度特性 <code>valveCharacteristic</code> 默认为线性，可替换为任何用户定义的函数。库中已提供二次方、等百分比等特性。下一图展示了恒定压差下不同开度特性的曲线：
</p>

<blockquote>
<img src=\"modelica://Modelica/Resources/Images/Fluid/Valves/BaseClasses/ValveCharacteristics1a.png\"
     alt=\"ValveCharacteristics1a.png\"><br>
<img src=\"modelica://Modelica/Resources/Images/Fluid/Valves/BaseClasses/ValveCharacteristics1b.png\"
     alt=\"Components/ValveCharacteristics1b.png\">
</blockquote>

<p>
关于 <strong>Kv</strong> 和 <strong>Cv</strong> 参数的处理方式，详见用户指南：
<a href=\"modelica://Modelica.Fluid.UsersGuide.ComponentDefinition.ValveCharacteristics\">User's Guide</a>.
</p>

<p>
借助可选参数 \"filteredOpening\"，可以通过一个 <strong>二阶临界阻尼 (second order, criticalDamping)</strong> 滤波器对开度指令进行滤波，使得实际开度被 \"riseTime\" 延迟。
这种方法逼近了真实阀门驱动电机的机械延迟。
\"riseTime\" 参数用于计算滤波器的截止频率：f_cut = 5/(2*pi*riseTime)。
它定义了 opening_filtered 达到开度阶跃输入 99.6% 所需的时间。阀门的图标会以如下方式改变
(左图: filteredOpening=false, 右图: filteredOpening=true):
</p>

<blockquote>
<img src=\"modelica://Modelica/Resources/Images/Fluid/Valves/BaseClasses/FilteredValveIcon.png\"
     alt=\"FilteredValveIcon.png\">
</blockquote>

<p>
【极其重要】：如果 \"filteredOpening = <strong>true</strong>\"，输入信号 \"opening\" 将被参数 <strong>leakageOpening</strong> 限制下限。
即，如果 \"opening\" 变得比 \"leakageOpening\" 还小，那么滤波器将使用 \"leakageOpening\" 作为输入而不是 \"opening\"。
原因在于，\"opening=0\" 可能会从结构上改变流体网络的方程，导致奇异 (singularity)。
如果引入一个极小的泄漏流（现实中往往也是存在的），这种奇异性就能被避免。
</p>

<p>
在下图中，展示了在 filteredOpening = <strong>true</strong>, riseTime = 1 s, 且 leakageOpening = 0.02 的情况下，\"opening\" 和 \"filtered_opening\" 的关系。
</p>

<blockquote>
<img src=\"modelica://Modelica/Resources/Images/Fluid/Valves/BaseClasses/ValveFilteredOpening.png\"
     alt=\"ValveFilteredOpening.png\">
</blockquote>

</html>", revisions="<html>
<ul>
<li><em>2010年9月5日</em>
    由 <a href=\"mailto:martin.otter@dlr.de\">Martin Otter</a> 编写:<br>
    基于 Mike Barth 的提议引入了可选的开度滤波，并改进了文档。</li>
<li><em>2005年11月2日</em>
    由 <a href=\"mailto:francesco.casella@polimi.it\">Francesco Casella</a> 编写:<br>
        自 ThermoPower 库移植。</li>
</ul>
</html>"));
end PartialValve;