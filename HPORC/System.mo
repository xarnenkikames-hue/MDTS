model System "全局系统属性与默认值控制中心 (掌管环境、流动方向、初始化与数值正则化)"
  import SI = Modelica.SIunits;
  // =======================================================================
  // 1. 全局默认工质
  // =======================================================================
  package Medium = Modelica.Media.Interfaces.PartialMedium
    "为全系统提供默认初始值的工质模型" 
      annotation (choicesAllMatching = true);

  // =======================================================================
  // 2. 环境宇宙常数
  // =======================================================================
  parameter SI.AbsolutePressure p_ambient=101325
    "默认环境绝对压力 (1个标准大气压)" 
    annotation(Dialog(group="环境设定"));
  parameter SI.Temperature T_ambient=293.15
    "默认环境温度 (20°C)" 
    annotation(Dialog(group="环境设定"));
  parameter SI.Acceleration g=Modelica.Constants.g_n
    "全局重力加速度" 
    annotation(Dialog(group="环境设定"));

  // =======================================================================
  // 3. 全局动力学假设 (一键切换稳态/动态)
  // =======================================================================
  parameter Boolean allowFlowReversal = true
    "= false 时严禁全系统出现倒流 (强制流向必须从 port_a -> port_b)" 
    annotation(Dialog(tab="模型假设"), Evaluate=true);

  parameter Modelica.Fluid.Types.Dynamics energyDynamics=
    Modelica.Fluid.Types.Dynamics.DynamicFreeInitial
    "能量平衡方程的默认求解形式 (默认：动态求解，且初值自由迭代)" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学"));

  parameter Modelica.Fluid.Types.Dynamics massDynamics=
    energyDynamics "质量平衡方程的默认求解形式 (默认与能量一致)" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学"));

  final parameter Modelica.Fluid.Types.Dynamics substanceDynamics=
    massDynamics "组分平衡方程的默认求解形式" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学"));

  final parameter Modelica.Fluid.Types.Dynamics traceDynamics=
    massDynamics "痕量物质平衡方程的默认求解形式" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学"));

  parameter Modelica.Fluid.Types.Dynamics momentumDynamics=
    Modelica.Fluid.Types.Dynamics.SteadyState
    "动量平衡方程的默认求解形式 (默认：稳态。极少使用动态动量，那会导致严重的水锤效应和声波方程，计算极度缓慢)" 
    annotation(Evaluate=true, Dialog(tab = "模型假设", group="动力学"));

  // =======================================================================
  // 4. 全局初始化猜想值 (拯救求解器)
  // =======================================================================
  parameter SI.MassFlowRate m_flow_start = 0
    "全系统质量流量的默认初始猜测值" 
    annotation(Dialog(tab = "初始化"));
  parameter SI.AbsolutePressure p_start = p_ambient
    "全系统压力的默认初始猜测值" 
    annotation(Dialog(tab = "初始化"));
  parameter SI.Temperature T_start = T_ambient
    "全系统温度的默认初始猜测值" 
    annotation(Dialog(tab = "初始化"));

  // =======================================================================
  // 5. 极度硬核的数值正则化 (Advanced: 防除以零崩溃)
  // =======================================================================
  parameter Boolean use_eps_Re = false
    "= true 时，利用雷诺数自动判定层流区并平滑化 (官方强烈推荐的新版算法)" 
    annotation(Evaluate=true, Dialog(tab = "高级设置"));

  parameter SI.MassFlowRate m_flow_nominal = if use_eps_Re then 1 else 1e2*m_flow_small
    "系统的全局标称质量流量 (用于归一化)" 
    annotation(Dialog(tab="高级设置", enable = use_eps_Re));

  parameter Real eps_m_flow(min=0) = 1e-4
    "微小流量平滑因子。当 |m_flow| < eps_m_flow * m_flow_nominal 时，开启线性化防爆盾" 
    annotation(Dialog(tab = "高级设置", enable = use_eps_Re));

  parameter SI.AbsolutePressure dp_small(min=0) = 1
    "经典版：微小压降平滑阈值 (低于此压降强制切入层流线性方程)" 
    annotation(Dialog(tab="高级设置", group="经典算法", enable = not use_eps_Re));

  parameter SI.MassFlowRate m_flow_small(min=0) = 1e-2
    "经典版：微小流量平滑阈值" 
    annotation(Dialog(tab = "高级设置", group="经典算法", enable = not use_eps_Re));

initial equation
  // (注释掉的警告代码：提醒用户尽快从经典 dp_small 算法迁移到更科学的雷诺数 eps_Re 算法)

  annotation (
    defaultComponentName="system",
    // 【魔法的核心】：拖入画板自动加上 inner 前缀，成为全局广播源
    defaultComponentPrefixes="inner",
    missingInnerMessage="
你的模型使用了 outer 'system' 组件，但画板上没有找到全局的 inner 'system' 核心！
要进行仿真，请必须将 Modelica.Fluid.System 组件拖入你的系统顶层模型中，以提供全局物理环境。
",
    Icon(coordinateSystem(preserveAspectRatio=false, extent={{-100,-100},{100,100}}), graphics={
        Rectangle(extent={{-100,100},{100,-100}}, lineColor={0,0,255}, fillColor={255,255,255}, fillPattern=FillPattern.Solid),
        Text(extent={{-150,150},{150,110}}, textColor={0,0,255}, textString="%name"),
        // 绘制代表地球重力的小苹果/箭头等图标
        Line(points={{-86,-30},{82,-30}}),
        Line(points={{-82,-68},{-52,-30}}), Line(points={{-48,-68},{-18,-30}}),
        Line(points={{-14,-68},{16,-30}}), Line(points={{22,-68},{52,-30}}),
        Line(points={{74,84},{74,14}}),
        Polygon(points={{60,14},{88,14},{74,-18},{60,14}}, fillPattern=FillPattern.Solid),
        Text(extent={{16,20},{60,-18}}, textString="g"),
        Text(extent={{-90,82},{74,50}}, textString="defaults"),
        Line(points={{-82,14},{-42,-20},{2,30}}, thickness=0.5),
        Ellipse(extent={{-10,40},{12,18}}, pattern=LinePattern.None, fillColor={255,0,0}, fillPattern=FillPattern.Solid)}),
    Documentation(info="<html>
<p>
每个流体模型顶层<strong>必须且仅需一个</strong> <code>System</code> 组件，用于提供全系统级别的设定，比如环境条件、全局动力学假设等。
这些系统设定将通过 <code>inner/outer</code>（内层/外层）机制瞬间广播到所有的流体底部分支模型中。
</p>
<p>
<strong>开发规范：</strong>普通的流体模型不应该直接写死系统参数。相反，应声明局部参数，并将其默认值指向这个全局系统，例如 <code>parameter p_start = system.p_start</code>。
</p>
<p>
<strong>关于零流量崩溃的数值正则化：</strong><br>
全局的 <code>system.m_flow_small</code> 和 <code>system.dp_small</code> 是经典的平滑参数。它们用于在流速接近0时（例如泵刚启动、阀门将要关死时），强行将二次方的阻力方程转换为线性方程，避免求解器计算雅可比矩阵时发生除以0的奇异崩溃。
目前官方强烈建议在高级选项卡中勾选 <code>system.use_eps_Re = true</code>，它能更科学地依据雷诺数自动划分层流区和零流量区。
</p>
</html>"));
end System;