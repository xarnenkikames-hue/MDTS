model FixedBoundary "固定值全能边界源 (支持任意组合的压力/密度、温度/比焓边界)"
  import Modelica.Media.Interfaces.Choices.IndependentVariables;


  // 继承基础局部源接口 (自带端口、默认参数等)
  extends Sources.BaseClasses.PartialSource;

  // =======================================================================
  // 1. 压力/密度选择器
  // =======================================================================
  parameter Boolean use_p=true "= true 时使用绝对压力 p 作为边界；= false 时使用流体密度 d" 
    annotation (Evaluate = true, Dialog(group = "边界压力或边界密度选择"));

  parameter Medium.AbsolutePressure p=Medium.p_default "边界绝对压力" 
    annotation (Dialog(group = "边界压力或边界密度选择", enable = use_p));

  parameter Medium.Density d=
    (if use_T then Medium.density_pTX(Medium.p_default,Medium.T_default,Medium.X_default) 
     else Medium.density_phX(Medium.p_default,Medium.h_default,Medium.X_default))
    "边界流体密度" 
    annotation (Dialog(group = "边界压力或边界密度选择", enable=not use_p));

  // =======================================================================
  // 2. 温度/比焓选择器 (处理相变极其关键)
  // =======================================================================
  parameter Boolean use_T=true "= true 时使用温度 T 作为边界；= false 时使用比焓 h (相变必备)" 
    annotation (Evaluate = true, Dialog(group = "边界温度或边界比焓选择"));

  parameter Medium.Temperature T = Medium.T_default "边界温度" 
    annotation (Dialog(group = "边界温度或边界比焓选择", enable = use_T));

  parameter Medium.SpecificEnthalpy h = Medium.h_default "边界比焓" 
    annotation (Dialog(group="边界温度或边界比焓选择", enable = not use_T));

  // =======================================================================
  // 3. 多组分与痕量物质边界
  // =======================================================================
  parameter Medium.MassFraction X[Medium.nX](quantity=Medium.substanceNames) = Medium.X_default
    "边界流体各独立组分的质量分数 m_i/m" 
    annotation (Dialog(group = "多组分流体专属设置", enable=Medium.nXi > 0));

  parameter Medium.ExtraProperty C[Medium.nC](quantity=Medium.extraPropertiesNames) = Medium.C_default
    "边界流体痕量物质属性" 
    annotation (Dialog(group = "痕量物质流体专属设置", enable=Medium.nC > 0));

protected
  Medium.ThermodynamicState state "边界内部计算用的流体热力学状态";

equation
  // =======================================================================
  // 4. 安全检查与防呆机制
  // =======================================================================
  Modelica.Fluid.Utilities.checkBoundary(Medium.mediumName, Medium.substanceNames, Medium.singleState, use_p, X, "FixedBoundary");

  // =======================================================================
  // 5. 极其复杂的热力学状态底层反算机制
  // (根据用户的 p/d, T/h 选择，以及 Medium 底层的独立变量类型，逆推完整的边界热力学状态)
  // =======================================================================
  if use_p or Medium.singleState then
     // --- 给定压力 p 的工况 ---
     if use_T then
        // 给定了 p, T, X
        state = Medium.setState_pTX(p, T, X);
     else
        // 给定了 p, h, X
        state = Medium.setState_phX(p, h, X);
     end if;

     // 适配底层以 d, T, X 为独立变量的极其罕见工质库
     if Medium.ThermoStates == IndependentVariables.dTX then
        medium.d = Medium.density(state);
     else
        medium.p = Medium.pressure(state);
     end if;

     // 适配底层以 p, h 为独立变量的主流工质库 (如制冷剂、水)
     if Medium.ThermoStates == IndependentVariables.ph or 
        Medium.ThermoStates == IndependentVariables.phX then
        medium.h = Medium.specificEnthalpy(state);
     else
        medium.T = Medium.temperature(state);
     end if;

  else
     // --- 给定密度 d 的工况 ---
     if use_T then
        // 给定了 d, T, X
        state = Medium.setState_dTX(d, T, X);

        if Medium.ThermoStates == IndependentVariables.dTX then
           medium.d = Medium.density(state);
        else
           medium.p = Medium.pressure(state);
        end if;

        if Medium.ThermoStates == IndependentVariables.ph or 
           Medium.ThermoStates == IndependentVariables.phX then
           medium.h = Medium.specificEnthalpy(state);
        else
           medium.T = Medium.temperature(state);
        end if;

     else
        // 给定了 d, h, X (物理上极其变态的组合，强制赋值)
        medium.d = d;
        medium.h = h;
        state = Medium.setState_dTX(d,T,X);
     end if;
  end if;

  // 组分与痕量物质强制赋值
  medium.Xi = X[1:Medium.nXi];
  ports.C_outflow = fill(C, nPorts);

  // =======================================================================
  // 图形注解与官方说明文档
  // =======================================================================
  annotation (defaultComponentName="boundary",
    Icon(coordinateSystem(preserveAspectRatio=false, extent={{-100,-100},{100,100}}), graphics={
        Ellipse(
          extent={{-100,100},{100,-100}},
          fillPattern=FillPattern.Sphere,
          fillColor={0,127,255}),
        Text(
          extent={{-150,110},{150,150}},
          textString="%name",
          textColor={0,0,255})}),
    Documentation(info="<html>
<p>
<strong>FixedBoundary</strong> 模型用于为流体网络定义完全固定不变的恒定边界条件：
</p>
<ul>
<li> 边界绝对压力 或 边界流体密度。</li>
<li> 边界绝对温度 或 边界比热力学焓。</li>
<li> 边界组分浓度（仅对多组分流体或含有痕量物质的流体生效）。</li>
</ul>
<p>
<strong>⚠️ 核心警告 (流束方向性)：</strong><br>
你在此模型中设置的 <strong>边界温度、密度、比焓、质量分数等热力学属性</strong>，<strong>仅仅</strong> 在流体从该边界 <strong>流入</strong> 你的系统时才起作用。<br>
如果流体发生反转（从你的系统流向该边界），边界就变成了一个被动的“接收黑洞”。此时除了<strong>边界压力</strong>依然保持恒定外，边界的其它热力学设定值将不再对系统产生任何物理影响！
</p>
</html>"));
end FixedBoundary;