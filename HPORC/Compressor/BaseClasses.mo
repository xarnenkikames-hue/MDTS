package BaseClasses "压缩机底层基类与通用记录包"

    partial model PartialCompressor "容积式压缩机底层物理基类"

      import SI = Modelica.SIunits;

      // =======================================================================
      // 1. FLUID (约束为两相流体介质)
      // =======================================================================
      replaceable package Medium =
          Modelica.Media.Interfaces.PartialTwoPhaseMedium 
          constrainedby Modelica.Media.Interfaces.PartialTwoPhaseMedium
        "两相流体介质包 (Two-Phase Medium model)" annotation (choicesAllMatching = true);

      // =======================================================================
      // 2. PORTS (统一采用机械语义命名 flange_shaft)
      // =======================================================================
      Modelica.Mechanics.Rotational.Interfaces.Flange_b flange_shaft "机械旋转主轴法兰" 
        annotation (Placement(transformation(extent={{64,-8},{100,28}})));

      Modelica.Fluid.Interfaces.FluidPort_a port_a(redeclare package Medium = Medium)
        "流体吸气入口" annotation (Placement(transformation(extent={{-110,-10},{-90,10}})));

      Modelica.Fluid.Interfaces.FluidPort_b port_b(redeclare package Medium = Medium)
        "流体排气出口" annotation (Placement(transformation(extent={{90,-10},{110,10}})));

      // =======================================================================
      // 3. COMMON VARIABLES (供子类调用的通用物理量)
      // =======================================================================
      SI.Pressure p_a "吸气绝对压力";
      SI.Pressure p_b "排气绝对压力";
      Medium.SpecificEnthalpy h_a "吸气真实比焓";
      Medium.SpecificEnthalpy h_b "排气真实比焓";

      SI.MassFlowRate m_flow "流经压缩机的质量流量";
      SI.Frequency N_rot "主轴机械旋转频率 (Hz)";

      // 【语义修复】：将原本含糊的 W_dot_fluid 拆分为明确的机械侧与流体侧
      SI.Power W_dot_mech "主轴输入的总机械功率";
      SI.Power W_dot_fluid "流体实际吸收的焓升功率";

    equation
      // =======================================================================
      // A. 机械接口基础关联
      // =======================================================================
      N_rot = der(flange_shaft.phi) / (2 * Modelica.Constants.pi);

      // =======================================================================
      // B. 质量守恒与压力透传
      // =======================================================================
      port_a.m_flow = m_flow;
      port_b.m_flow = -m_flow;

      p_a = port_a.p;
      p_b = port_b.p;

      // =======================================================================
      // C. 迎风语义彻底修复 (废除自引用)
      // =======================================================================
      h_a = inStream(port_a.h_outflow);
      port_b.h_outflow = h_b;
      port_a.h_outflow = h_b; // 倒流时，将排气侧的高压高温气体反推回吸气管网

      // =======================================================================
      // D. 组分与痕量物质守恒
      // =======================================================================
      port_b.Xi_outflow = inStream(port_a.Xi_outflow);
      port_b.C_outflow = inStream(port_a.C_outflow);

      port_a.Xi_outflow = inStream(port_b.Xi_outflow);
      port_a.C_outflow = inStream(port_b.C_outflow);

      annotation (
        Icon(coordinateSystem(preserveAspectRatio=true, extent={{-100,-100},{100,100}}), graphics={
          Ellipse(extent={{-80,80},{80,-80}}, lineColor={0,0,0}, fillColor={255,255,255}, fillPattern=FillPattern.Solid),
          Polygon(points={{-40,40},{40,20},{40,-20},{-40,-40}}, lineColor={0,0,127}, fillColor={170,213,255}, fillPattern=FillPattern.Solid),
          Text(extent={{-100,-110},{100,-150}}, textColor={0,0,255}, textString="%name"),
          Text(extent={{-40,0},{40,-20}}, textColor={0,0,127}, textString="Base")}),
        Documentation(info="<html>
<p><b>容积式压缩机底层基类 (MSL 1.0.0 发布版)</b></p>
<p>统一了机械法兰命名规范，并拆分了机械功与流体功的变量声明，为复杂的壳体散热模型预留了扩展接口。</p>
</html>"));
    end PartialCompressor;

  end BaseClasses;