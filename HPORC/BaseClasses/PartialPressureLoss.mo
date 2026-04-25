partial model PartialPressureLoss
  "所有局部压降阻力件的抽象基类 (假设 port_a 和 port_b 具有相同的流通截面积)"

  // 继承双端口传输模型的基础接口 (包含质量守恒等)
  extends PartialTwoPortTransport;

protected
  // =======================================================================
  // 1. 零点正则化参考态
  // =======================================================================
  parameter Medium.ThermodynamicState state_dp_small=Medium.setState_pTX(
                       Medium.reference_p,
                       Medium.reference_T,
                       Medium.reference_X)
    "极其关键的参考热力学状态：当流量接近0时，用于计算名义流体物性，以求出极小压降 dp_small，防止导数无穷大致使求解器崩溃";

  // =======================================================================
  // 2. 迎风格式的流动物性定义
  // =======================================================================
  Medium.Density d_a
    "当流体从 port_a 流向 port_b 时，读取 port_a 处的迎风密度";
  Medium.Density d_b
    "如果允许反向流动，当流体从 port_b 流向 port_a 时读取 port_b 处的密度；否则直接等于 d_a";

  Medium.DynamicViscosity eta_a
    "当流体从 port_a 流向 port_b 时，读取 port_a 处的迎风动力粘度";
  Medium.DynamicViscosity eta_b
    "如果允许反向流动，当流体从 port_b 流向 port_a 时读取 port_b 处的动力粘度；否则直接等于 eta_a";

equation
  // =======================================================================
  // 3. 能量守恒：等焓节流过程 (Isenthalpic Transformation)
  // =======================================================================
  // 物理意义：流体通过局部阻力件时，不储存质量、不储存能量，也不散失热量。
  // 仅发生压力下降，宏观比焓 h 保持不变。利用 inStream() 函数精准追踪迎风焓值。
  port_a.h_outflow = inStream(port_b.h_outflow);
  port_b.h_outflow = inStream(port_a.h_outflow);

  // =======================================================================
  // 4. 动态物性提取：跟随流向切换状态
  // =======================================================================
  d_a   = Medium.density(state_a);
  eta_a = Medium.dynamicViscosity(state_a);

  if allowFlowReversal then
    // 如果存在反向流动的可能，必须动态计算 b 端的物性
    d_b   = Medium.density(state_b);
    eta_b = Medium.dynamicViscosity(state_b);
  else
    // 如果仅单向流动，强行赋予 a 端的物性以节省计算资源
    d_b   = d_a;
    eta_b = eta_a;
  end if;

end PartialPressureLoss;