partial model PartialTwoPortTransport
    "双端口流体传输抽象基类 (仅用于在两端口间传输流体，内部绝对不储存质量或能量)"

  // 继承最基础的双端口模型，并明确声明：我的端口绝不暴露热力学状态！
  // (这就是之前化解 DAE 死锁的底层根源：我是一个纯粹的流动节点，不是体积节点)
  extends PartialTwoPort(
    final port_a_exposesState=false,
    final port_b_exposesState=false);

  // 【防报错补丁：导入国际单位制】
  import SI = Modelica.SIunits;

  // =======================================================================
  // 1. Advanced (高级求解器设置与零点正则化)
  // =======================================================================
  // 注意：dp_start 的值应当由继承它的子模型基于局部的额定压降进行重新定义
  parameter Medium.AbsolutePressure dp_start(min=-Modelica.Constants.inf) = 0.01*system.p_start
      "压降猜测初值 dp = port_a.p - port_b.p (用于帮助求解器快速收敛)" 
    annotation(Dialog(tab = "高级设置"));

  parameter Medium.MassFlowRate m_flow_start = system.m_flow_start
      "质量流量猜测初值 m_flow = port_a.m_flow" 
    annotation(Dialog(tab = "高级设置"));

  // 注意：m_flow_small 的值应当由子模型基于局部的额定流量进行重新定义
  parameter Medium.MassFlowRate m_flow_small = if system.use_eps_Re then system.eps_m_flow*system.m_flow_nominal else system.m_flow_small
      "用于零流量附近正则化平滑的微小质量流量极值 (防止流量过零时导数无穷大致使求解器崩溃)" 
    annotation(Dialog(tab = "高级设置"));

  // =======================================================================
  // 2. Diagnostics (诊断与显示选项)
  // =======================================================================
  parameter Boolean show_T = true
      "= true 时，计算并在结果中显示端口 a 和 b 的真实温度" 
    annotation(Dialog(tab="高级设置",group="诊断与显示"));

  parameter Boolean show_V_flow = true
      "= true 时，计算并在结果中显示流入端口的体积流量" 
    annotation(Dialog(tab="高级设置",group="诊断与显示"));

  // =======================================================================
  // 3. Variables (核心流体变量)
  // =======================================================================
  Medium.MassFlowRate m_flow(
     min=if allowFlowReversal then -Modelica.Constants.inf else 0,
     start = m_flow_start) "设计流向上的质量流量";

  SI.Pressure dp(start=dp_start)
      "端口 a 与端口 b 之间的压差 (= port_a.p - port_b.p)";

  // 【核心机制：regStep 正则化平滑】
  // 体积流量 V_flow = 质量流量 m_flow / 密度 rho。
  // 但流量反向瞬间，该用 a 端还是 b 端的密度？如果产生阶跃突变，求解器会崩溃。
  // Utilities.regStep 函数可以在 m_flow 跨越 0 的极小区间内，将两端密度进行极其平滑的数学插值过渡！
  SI.VolumeFlowRate V_flow=
      m_flow/Modelica.Fluid.Utilities.regStep(m_flow,
                  Medium.density(state_a),
                  Medium.density(state_b),
                  m_flow_small) if show_V_flow
      "流入端口的体积流量 (当流体从 port_a 流向 port_b 时为正)";

  // 同理，计算端口温度时也使用 regStep 函数进行跨零点的平滑过渡
  Medium.Temperature port_a_T=
      Modelica.Fluid.Utilities.regStep(port_a.m_flow,
                  Medium.temperature(state_a),
                  Medium.temperature(Medium.setState_phX(port_a.p, port_a.h_outflow, port_a.Xi_outflow)),
                  m_flow_small) if show_T
      "靠近 port_a 处的流体温度 (需启用 show_T)";

  Medium.Temperature port_b_T=
      Modelica.Fluid.Utilities.regStep(port_b.m_flow,
                  Medium.temperature(state_b),
                  Medium.temperature(Medium.setState_phX(port_b.p, port_b.h_outflow, port_b.Xi_outflow)),
                  m_flow_small) if show_T
      "靠近 port_b 处的流体温度 (需启用 show_T)";

protected
  Medium.ThermodynamicState state_a "从 port_a 流入的流体热力学状态";
  Medium.ThermodynamicState state_b "从 port_b 流入的流体热力学状态";

equation
  // =======================================================================
  // 4. 核心方程组 (严格物理约束)
  // =======================================================================
  // 【流体状态提取】：利用 inStream() 精准捕捉迎风面的真实焓值和质量分数
  state_a = Medium.setState_phX(port_a.p, inStream(port_a.h_outflow), inStream(port_a.Xi_outflow));
  state_b = Medium.setState_phX(port_b.p, inStream(port_b.h_outflow), inStream(port_b.Xi_outflow));

  // 定义设计流向下的压降
  dp = port_a.p - port_b.p;

  // 定义设计流向下的质量流量
  m_flow = port_a.m_flow;

  // 安全断言：如果设死了不允许反向流动，但实际算出了反向流量，直接报错停止仿真
  assert(m_flow > -m_flow_small or allowFlowReversal, "物理错误：系统已设置为禁止反向流动，但检测到了反向流量！");

  // 【铁律：质量守恒 (绝不储能)】
  // 流入的加上流出的必须等于0 (即进多少出多少)
  port_a.m_flow + port_b.m_flow = 0;

  // 【物质传输守恒】：质量分数和微量组分的迎风传递
  port_a.Xi_outflow = inStream(port_b.Xi_outflow);
  port_b.Xi_outflow = inStream(port_a.Xi_outflow);

  port_a.C_outflow = inStream(port_b.C_outflow);
  port_b.C_outflow = inStream(port_a.C_outflow);

  // =======================================================================
  // 图形与官方说明文档 (已全面汉化)
  // =======================================================================
  annotation (
    Documentation(info="<html>
<p>
本组件用于在其两个端口之间传输流体，<strong>内部绝对不储存质量或能量</strong>。
不过，流体在通过本组件时，可以与外界环境交换能量（例如以机械功的形式，如水泵）。
<code>PartialTwoPortTransport</code> 专门用作诸如孔板、阀门和简单流体机械等设备的<strong>底层抽象基类</strong>。</p>
<p>
任何继承并使用本组件的子类，都<strong>必须且只需补充以下 3 个方程</strong>即可闭合：
</p>
<ul>
<li>动量守恒方程：规定压降 <code>dp</code> 与质量流量 <code>m_flow</code> 之间的具体数学关系，</li>
<li><code>port_b.h_outflow</code>：用于计算正向流动时的出口比焓，以及</li>
<li><code>port_a.h_outflow</code>：用于计算反向流动时的出口比焓。</li>
</ul>
<p>
此外，为了保证求解器的鲁棒性，子类应当为以下参数分配合理的值：
</p>
<ul>
<li><code>dp_start</code>：压降的初始猜测值</li>
<li><code>m_flow_small</code>：用于在零流量点附近进行正则化平滑的微小流量值。</li>
</ul>
</html>"));
end PartialTwoPortTransport;