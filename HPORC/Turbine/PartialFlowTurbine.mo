partial model PartialFlowTurbine
  "第二层：通流特性半实现类 (固化了壅塞与斯托多拉流量计算，预留效率接口)"
  import SI = Modelica.SIunits;
  extends PartialTurbine;

  parameter Real K_flow(unit="m4.s/kg", min=0) = 3e-7 "经验通流系数" annotation(Dialog(group="气动参数"));
  parameter Real PR_choke(min=0.1, max=0.95) = 0.55 "壅塞临界压比" annotation(Dialog(group="气动参数"));

  parameter SI.Pressure p_floor_band = 1e3 annotation(Dialog(tab="高级设置"));
  parameter Real G_hom(unit="kg/(s.Pa)") = 1e-6 annotation(Dialog(tab="高级设置"));

  SI.Pressure p_out_eff_dyn;

equation
  // 计算壅塞有效背压，供给基类的能量方程使用
  p_out_eff_ab = Modelica.Fluid.Utilities.regStep(port_a.p*PR_choke - port_b.p, port_a.p*PR_choke, port_b.p, p_floor_band);
  p_out_eff_ba = Modelica.Fluid.Utilities.regStep(port_b.p*PR_choke - port_a.p, port_b.p*PR_choke, port_a.p, p_floor_band);
  p_out_eff_dyn = Modelica.Fluid.Utilities.regStep(dp, p_out_eff_ab, p_out_eff_ba, dp_small);

  // 计算流量
  port_a.m_flow = homotopy(rho_in*K_flow*Modelica.Fluid.Utilities.regRoot(p_in^2 - p_out_eff_dyn^2, dp_small^2), G_hom*(port_a.p - port_b.p));
end PartialFlowTurbine;