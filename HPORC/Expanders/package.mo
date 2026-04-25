package Expanders "容积式膨胀机组件包 (ORC 终极封版)"

  package BaseClasses "膨胀机底层基类包"

    partial model PartialExpander "容积式膨胀机专属物理基类"

      import SI = Modelica.SIunits;

      replaceable package Medium =
          Modelica.Media.Interfaces.PartialTwoPhaseMedium 
          constrainedby Modelica.Media.Interfaces.PartialTwoPhaseMedium;

      Modelica.Mechanics.Rotational.Interfaces.Flange_b flange_shaft "机械做功输出法兰" 
        annotation (Placement(transformation(extent={{64,-8},{100,28}})));

      Modelica.Fluid.Interfaces.FluidPort_a port_in(redeclare package Medium = Medium)
        "高压流体进口" annotation (Placement(transformation(extent={{-110,-10},{-90,10}})));

      Modelica.Fluid.Interfaces.FluidPort_b port_out(redeclare package Medium = Medium)
        "低压流体出口" annotation (Placement(transformation(extent={{90,-10},{110,10}})));

      SI.Pressure p_in "进口绝对压力";
      SI.Pressure p_out "出口绝对压力";
      Medium.SpecificEnthalpy h_in "进口真实比焓";
      Medium.SpecificEnthalpy h_out "出口真实比焓";

      SI.MassFlowRate m_flow "流经膨胀机的质量流量 (正值代表产功方向)";
      SI.Frequency N_rot "主轴机械旋转频率 (Hz)";

      SI.Power W_dot_mech "主轴输出的机械功率 (负值代表对外做功)";
      SI.Power W_dot_fluid "流体释放的焓降功率 (负值代表失去能量)";

    equation
      N_rot = der(flange_shaft.phi) / (2 * Modelica.Constants.pi);

      port_in.m_flow = m_flow;
      port_out.m_flow = -m_flow;

      p_in = port_in.p;
      p_out = port_out.p;

      // 【终极机理修复】：彻底斩断自引用！发生高背压倒灌时，认为流体在腔内等焓节流退回上游
      h_in = inStream(port_in.h_outflow);
      port_out.h_outflow = h_out;
      port_in.h_outflow = h_in;

      port_out.Xi_outflow = inStream(port_in.Xi_outflow);
      port_out.C_outflow = inStream(port_in.C_outflow);

      port_in.Xi_outflow = inStream(port_out.Xi_outflow);
      port_in.C_outflow = inStream(port_out.C_outflow);
      annotation (
          Icon(coordinateSystem(preserveAspectRatio=true, extent={{-100,-100},{100,100}}), graphics={
            // 1. 膨胀机圆形外壳 (浅灰色)
            Ellipse(extent={{-80,80},{80,-80}}, lineColor={64,64,64}, fillColor={245,245,245}, fillPattern=FillPattern.Solid, lineThickness=0.5),

            // 2. 内部 P&ID 膨胀做功机理符号 (绿色梯形，从左至右膨胀)
            Polygon(points={{-40, 20}, {40, 45}, {40, -45}, {-40, -20}}, lineColor={0,127,0}, fillColor={170,255,170}, fillPattern=FillPattern.Solid, lineThickness=0.5),

            // 3. 高压进气口内部导流管 (蓝色)
            Line(points={{-80, 0}, {-40, 0}}, color={0,0,255}, thickness=1.0),

            // 4. 低压排气口内部导流管 (蓝色)
            Line(points={{40, 0}, {80, 0}}, color={0,0,255}, thickness=1.0),

            // 5. 机械主轴传动杆 (黑色实心，连接至法兰位置)
            Line(points={{20, 32}, {20, 60}, {80, 60}, {80, 10}}, color={0,0,0}, thickness=1.0),

            // 6. 动态组件名称显示
            Text(extent={{-100,-95},{100,-125}}, textColor={0,127,0}, textString="%name")}),
          Documentation(info="<html>
<p><b>容积式膨胀机专属基类</b></p>
<p>彻底剥离了压缩机语义，重新定义了高压进口 <code>port_in</code> 与低压出口 <code>port_out</code>。</p>
</html>"  ));

    end PartialExpander;

  end BaseClasses;
  annotation (
    Icon(coordinateSystem(preserveAspectRatio=true, extent={{-100,-100},{100,100}}), graphics={
      // 标准库文件夹背景 (淡黄色)
      Polygon(points={{-80,80},{-40,80},{-20,60},{80,60},{80,-80},{-80,-80}}, lineColor={160,160,164}, fillColor={255,228,181}, fillPattern=FillPattern.Solid, lineThickness=0.5),
      // 文件夹正面的膨胀机符号 (由窄变宽)
      Polygon(points={{-30, 15}, {30, 35}, {30, -35}, {-30, -15}}, lineColor={0,127,0}, fillColor={170,255,170}, fillPattern=FillPattern.Solid, lineThickness=0.5),
      // 文件夹标题
      Text(extent={{-90,-40},{90,-70}}, textColor={0,0,0}, textString="Expanders")}),
    Documentation(info="<html>
<p><b>容积式膨胀机组件包</b></p>
<p>本包包含专为有机朗肯循环 (ORC) 与废热回收系统设计的容积式膨胀机模型及其底层基类。与压缩机完全物理隔离，采用独立的迎风语义与热力学做功降额法则。</p>
</html>"));
 end Expanders;