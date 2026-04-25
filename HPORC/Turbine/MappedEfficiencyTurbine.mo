model MappedEfficiencyTurbine
  "第三层：方程级非对称气动图谱透平实现类 (彻底消灭硬编码)"
  import SI = Modelica.SIunits;
  extends PartialFlowTurbine;

  parameter Real PR_nominal(min=1.01) = 5.0 "额定膨胀比" annotation(Dialog(group="气动图谱"));
  parameter Real eta_is_nominal(min=0, max=1) = 0.85 "额定最高等熵效率" annotation(Dialog(group="气动图谱"));
  parameter Real decay_PR_low(min=0) = 0.15 "低压比衰减系数" annotation(Dialog(group="气动图谱"));
  parameter Real decay_PR_high(min=0) = 0.02 "高压比衰减系数" annotation(Dialog(group="气动图谱"));
  parameter Real decay_speed(min=0) = 0.5 "转速匹配度衰减系数" annotation(Dialog(group="气动图谱"));
  parameter SI.SpecificEnthalpy dh_is_nominal = 1e5 "额定设计等熵焓降" annotation(Dialog(group="气动图谱"));

  parameter Real eta_min = 0.1 annotation(Dialog(tab="高级设置"));
  parameter Real eta_band = 0.02 annotation(Dialog(tab="高级设置"));

  // 【修复】：彻底消灭 1000 和 500 的硬编码魔法数字
  parameter SI.SpecificEnthalpy dh_floor = 1000 "等熵焓降防爆下限" annotation(Dialog(tab="高级设置"));
  parameter SI.SpecificEnthalpy dh_band = 500 "等熵焓降平滑过渡带" annotation(Dialog(tab="高级设置"));

  Real PR;
  Real eta_PR_penalty;
  Real N_ratio;
  Real eta_speed_penalty;
  Real eta_raw;

protected
  constant SI.Pressure p_out_min = 1.0;
  SI.SpecificEnthalpy dh_is_eff;

equation
  PR = p_in / Modelica.Fluid.Utilities.regStep(p_out - p_out_min, p_out, p_out_min, p_floor_band);

  eta_PR_penalty = Modelica.Fluid.Utilities.regStep(PR - PR_nominal, decay_PR_high * (PR - PR_nominal)^2, decay_PR_low * (PR - PR_nominal)^2, 0.5);

  // 使用参数化的 dh_floor 和 dh_band
  dh_is_eff = Modelica.Fluid.Utilities.regStep(dh_is_actual - dh_floor, dh_is_actual, dh_floor, dh_band);

  N_ratio = (w_abs_eff / max(w_nominal, 1.0)) / Modelica.Fluid.Utilities.regRoot(dh_is_eff / dh_is_nominal, 0.01);

  eta_speed_penalty = decay_speed * (N_ratio - 1)^2;

  eta_raw = eta_is_nominal - eta_PR_penalty - eta_speed_penalty;
  eta_is_actual = Modelica.Fluid.Utilities.regStep(eta_raw - eta_min, eta_raw, eta_min, eta_band);

  annotation (defaultComponentName="turbine_mapped", Icon(coordinateSystem(extent={{-100,-100},{100,100}},
preserveAspectRatio=true,
grid={2,2}),graphics = {Polygon(origin={0,0},
lineColor={0,0,255},
fillColor={0,127,255},
fillPattern=FillPattern.Solid,
points={{-60,30},{60,70},{60,-70},{-60,-30},{-60,30}}), Rectangle(origin={80,-30},
lineColor={64,64,64},
fillColor={192,192,192},
fillPattern=FillPattern.Solid,
extent={{-20,10},{20,-10}}), Text(origin={0,-100},
lineColor={0,0,255},
extent={{-100,20},{100,-20}},
textString="%name",
textColor={0,0,255}), Text(origin={0,0},
lineColor={255,255,255},
extent={{-45,20},{45,-20}},
textString="Mapped",
textColor={255,255,255})}));
end MappedEfficiencyTurbine;