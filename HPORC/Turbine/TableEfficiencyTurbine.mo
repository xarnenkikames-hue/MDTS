model TableEfficiencyTurbine
  "第三层：基于 CombiTable2D 查表的设备级气动图谱透平实现类"
  import SI = Modelica.SIunits;
  extends PartialFlowTurbine;

  parameter SI.SpecificEnthalpy dh_is_nominal = 1e5 "额定设计等熵焓降" annotation(Dialog(group="气动图谱"));
  parameter Real eta_min = 0.1 annotation(Dialog(tab="高级设置"));
  parameter Real eta_band = 0.02 annotation(Dialog(tab="高级设置"));

  // 厂家效率表 (行: PR, 列: N_ratio)
  parameter Real[:,:] efficiency_table = [
       0.0,   1.5,   3.0,   5.0,   7.0,  10.0,  20.0;
       0.5,  0.40,  0.60,  0.70,  0.65,  0.50,  0.30;
       0.8,  0.50,  0.75,  0.82,  0.78,  0.60,  0.45;
       1.0,  0.55,  0.80,  0.85,  0.80,  0.65,  0.50;
       1.2,  0.50,  0.78,  0.83,  0.75,  0.55,  0.35
  ] "厂家提供的效率 Map 表";

  Modelica.Blocks.Tables.CombiTable2Ds eff_map(
    table=efficiency_table,
    smoothness=Modelica.Blocks.Types.Smoothness.LinearSegments) 
    annotation (Placement(transformation(extent={{-20,40},{0,60}})));

  Real PR;
  Real N_ratio;
  Real eta_raw;

protected
  constant SI.Pressure p_out_min = 1.0;
  SI.SpecificEnthalpy dh_is_eff;

equation
  PR = p_in / Modelica.Fluid.Utilities.regStep(p_out - p_out_min, p_out, p_out_min, p_floor_band);
  dh_is_eff = Modelica.Fluid.Utilities.regStep(dh_is_actual - 1000, dh_is_actual, 1000, 500);
  N_ratio = (w_abs_eff / max(w_nominal, 1.0)) / Modelica.Fluid.Utilities.regRoot(dh_is_eff / dh_is_nominal, 0.01);

  // 输入查表坐标
  eff_map.u1 = PR;
  eff_map.u2 = N_ratio;

  // 输出赋值给基类
  eta_raw = eff_map.y;
  eta_is_actual = Modelica.Fluid.Utilities.regStep(eta_raw - eta_min, eta_raw, eta_min, eta_band);

  annotation (defaultComponentName="turbine_table", Icon(coordinateSystem(preserveAspectRatio=true, extent={{-100,-100},{100,100}}), graphics={Polygon(points={{-60,30},{60,70},{60,-70},{-60,-30},{-60,30}}, lineColor={0,0,255}, fillColor={0,127,255}, fillPattern=FillPattern.Solid), Rectangle(extent={{60,10},{100,-10}}, lineColor={64,64,64}, fillColor={192,192,192}, fillPattern=FillPattern.Solid), Text(extent={{-100,-80},{100,-120}}, textString="%name", textColor={0,0,255}), Text(extent={{-45,20},{45,-20}}, textString="Table", textColor={255,255,255})}));
end TableEfficiencyTurbine;