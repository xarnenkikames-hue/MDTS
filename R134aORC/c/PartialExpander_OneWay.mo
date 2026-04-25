partial model PartialExpander_OneWay
  "容积式膨胀机专属基类（单向版，纯工质）"

  import SI = Modelica.SIunits;

  replaceable package Medium =
      Modelica.Media.Interfaces.PartialTwoPhaseMedium 
      constrainedby Modelica.Media.Interfaces.PartialTwoPhaseMedium;

  Modelica.Mechanics.Rotational.Interfaces.Flange_b flange_shaft
    "机械做功输出法兰";

  Modelica.Fluid.Interfaces.FluidPort_a port_in(redeclare package Medium = Medium)
    "高压流体进口";

  Modelica.Fluid.Interfaces.FluidPort_b port_out(redeclare package Medium = Medium)
    "低压流体出口";

  SI.Pressure p_in "进口绝对压力";
  SI.Pressure p_out "出口绝对压力";

  Medium.SpecificEnthalpy h_in "实际进入膨胀机的进口焓";
  Medium.SpecificEnthalpy h_out "膨胀机出口焓";

  SI.MassFlowRate m_flow "正值代表从 port_in -> port_out";
  SI.Frequency N_rot "主轴机械旋转频率 (Hz)";

  SI.Power W_dot_mech "机械轴功率";
  SI.Power W_dot_fluid "流体焓降功率";

equation
  N_rot = der(flange_shaft.phi) / (2 * Modelica.Constants.pi);

  port_in.m_flow  = m_flow;
  port_out.m_flow = -m_flow;

  p_in  = port_in.p;
  p_out = port_out.p;

  // 入口实际进入流体的焓
  h_in = actualStream(port_in.h_outflow);

  // 对于单向膨胀机，两个端口向外“吐”出去的内部焓统一采用 h_out
  // 这样不会在 port_in 端形成 h_in 的自复制
  port_out.h_outflow = h_out;
  port_in.h_outflow  = h_out;

  // 对纯工质（如 R134a_ph），Xi/C 数组通常为零长度，可不额外写方程

end PartialExpander_OneWay;