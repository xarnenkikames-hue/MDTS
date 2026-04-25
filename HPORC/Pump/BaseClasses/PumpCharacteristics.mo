package PumpCharacteristics "水泵特性曲线的数学拟合函数包"
  extends Modelica.Icons.Package;
  import Modelica.Units.NonSI;
  import SI = Modelica.SIunits;

  // =======================================================================
  // 1. 三大基础抽象函数 (定义输入输出的接口标准)
  // =======================================================================
  partial function baseFlow "水泵流量-扬程 (H-Q) 特性的基础类"
    extends Modelica.Icons.Function;
    input SI.VolumeFlowRate V_flow "输入的体积流量";
    output SI.Position head "输出的水泵扬程";
  end baseFlow;

  partial function basePower "水泵功率-流量特性的基础类"
    extends Modelica.Icons.Function;
    input SI.VolumeFlowRate V_flow "输入的体积流量";
    output SI.Power consumption "输出的消耗功率";
  end basePower;

  partial function baseEfficiency "水泵效率-流量特性的基础类"
    extends Modelica.Icons.Function;
    input SI.VolumeFlowRate V_flow "输入的体积流量";
    output Real eta "输出的等熵效率";
  end baseEfficiency;

  // =======================================================================
  // 2. 流量-扬程曲线 (H-Q) 拟合函数
  // =======================================================================
  function linearFlow "线性流量特性 (2点确定一条直线)"
    extends baseFlow;

    input SI.VolumeFlowRate V_flow_nominal[2] = {0, 0.1}
        "两个额定工作点的体积流量 (单泵)" annotation(Dialog);
    input SI.Position head_nominal[2] = {30, 0}
        "两个工作点对应的扬程" annotation(Dialog);

    /* 构建线性方程组以求解系数：
       head_nominal[1] = c[1] + V_flow_nominal[1]*c[2];
       head_nominal[2] = c[1] + V_flow_nominal[2]*c[2];
    */
    protected
    Real c[2] = Modelica.Math.Matrices.solve([ones(2),V_flow_nominal],head_nominal)
        "线性扬程曲线的拟合系数 (c[1]为截距, c[2]为斜率)";
  algorithm
    // 物理常识断言：扬程必须随着流量的增加而单调递减，否则斜率不对！
    assert(c[2] <= -Modelica.Constants.small,
           "水泵曲线错误：扬程 (head_nominal) 必须随着流量 (V_flow_nominal) 的增加而单调递减！",
           level=AssertionLevel.warning);
    // 流量方程：head = q*c[1] + c[2] (注意原注释有笔误，实际公式如下)
    head := c[1] + V_flow*c[2];
  end linearFlow;

  function quadraticFlow "二次抛物线流量特性 (3点确定)，包含安全区外的线性外推"
    extends baseFlow;
    input SI.VolumeFlowRate V_flow_nominal[3]
        "三个额定工作点的体积流量 (单泵)" annotation(Dialog);
    input SI.Position head_nominal[3] "三个工作点对应的扬程" annotation(Dialog);

    protected
    Real V_flow_nominal2[3] = {V_flow_nominal[1]^2, V_flow_nominal[2]^2, V_flow_nominal[3]^2}
        "额定流量的平方值数组";
    /* 构建线性方程组以求解系数：
       head_nominal[1] = c[1] + V_flow_nominal[1]*c[2] + V_flow_nominal[1]^2*c[3];
       head_nominal[2] = c[1] + V_flow_nominal[2]*c[2] + V_flow_nominal[2]^2*c[3];
       head_nominal[3] = c[1] + V_flow_nominal[3]*c[2] + V_flow_nominal[3]^2*c[3];
    */
    Real c[3] = Modelica.Math.Matrices.solve([ones(3), V_flow_nominal, V_flow_nominal2],head_nominal)
        "二次抛物线扬程曲线的拟合系数";
    SI.VolumeFlowRate V_flow_min = min(V_flow_nominal);
    SI.VolumeFlowRate V_flow_max = max(V_flow_nominal);

  algorithm
    assert(max(c[2].+2*c[3]*V_flow_nominal) <= -Modelica.Constants.small,
           "水泵曲线错误：扬程必须随着流量的增加而单调递减",
           level=AssertionLevel.warning);

    // 【极其高级的线性外推保护】：如果流量超出用户给定的点，不要继续用二次方算(防止扬程变成负数)，而是用端点的切线顺延！
    if V_flow < V_flow_min then
      head := max(head_nominal) + (V_flow-V_flow_min)*(c[2]+2*c[3]*V_flow_min);
    elseif V_flow > V_flow_max then
      head := min(head_nominal) + (V_flow-V_flow_max)*(c[2]+2*c[3]*V_flow_max);
    else
      // 正常工作区方程：head  = c[1] + V_flow*c[2] + V_flow^2*c[3];
      head := c[1] + V_flow*(c[2] + V_flow*c[3]);
    end if;

    annotation(Documentation(revisions="<html>
<ul>
<li><em>2013年1月</em> 由 R&uuml;diger Franke 修改:<br> 在指定数据点范围外扩展了线性外推功能，防止发散。</li>
</ul>
</html>"));
  end quadraticFlow;

  function polynomialFlow "N次多项式流量特性，包含线性外推 (N点确定)"
    extends baseFlow;
    input SI.VolumeFlowRate V_flow_nominal[:]
        "N 个额定工作点的体积流量 (单泵)" annotation(Dialog);
    input SI.Position head_nominal[:] "N 个工作点对应的扬程" annotation(Dialog);

    protected
    Integer N = size(V_flow_nominal,1) "额定工作点的数量";
    Real V_flow_nominal_pow[N,N] = {{if j > 1 then V_flow_nominal[i]^(j-1) else 1 for j in 1:N} for i in 1:N}
        "构建范德蒙德(Vandermonde)矩阵：行代表不同工作点；列代表流量的递增次幂";

    /* 求解 N 元线性方程组 (以 N=3 为例)：
       head_nominal[1] = c[1] + V_flow_nominal[1]*c[2] + V_flow_nominal[1]^2*c[3]; ...
    */
    Real c[size(V_flow_nominal,1)] = Modelica.Math.Matrices.solve(V_flow_nominal_pow,head_nominal)
        "多项式扬程曲线的系数";
    SI.VolumeFlowRate V_flow_min = min(V_flow_nominal);
    SI.VolumeFlowRate V_flow_max = max(V_flow_nominal);
    Real max_dhdV = c[2] + max(sum((i-1)*V_flow_nominal.^(i-2)*c[i] for i in 3:N));
    Real poly;

  algorithm
    assert(max_dhdV <= -Modelica.Constants.small,
           "水泵曲线错误：扬程必须随着流量的增加而单调递减",
           level=AssertionLevel.warning);

    if V_flow < V_flow_min then
      // 算法优化：使用霍纳法则 (Horner's method) 高效评估多项式导数
      poly := c[N]*(N-1);
      for i in 1:N-2 loop
        poly := V_flow_min*poly + c[N-i]*(N-i-1);
      end for;
      head := max(head_nominal) + (V_flow-V_flow_min)*poly;
    elseif V_flow > V_flow_max then
      poly := c[N]*(N-1);
      for i in 1:N-2 loop
        poly := V_flow_max*poly + c[N-i]*(N-i-1);
      end for;
      head := min(head_nominal) + (V_flow-V_flow_max)*poly;
    else
      // 正常区间方程：head = sum(V_flow^(i-1)*c[i] for i in 1:N);
      // 注意：使用霍纳法则重构，大幅降低高阶多项式的数值计算开销
      poly := c[N];
      for i in 1:N-1 loop
        poly := V_flow*poly + c[N-i];
       end for;
      head := poly;
    end if;

    annotation(Documentation(revisions="<html>
<ul>
<li><em>2013年1月</em> 由 R&uuml;diger Franke 修改:<br> 增加了外推功能，并使用霍纳法则重构了多项式求值过程。</li>
</ul>
</html>"));
  end polynomialFlow;

  // =======================================================================
  // 3. 效率与功率曲线拟合函数
  // =======================================================================
  function constantEfficiency "恒定效率特性"
     extends baseEfficiency;
     input Real eta_nominal "额定恒定效率" annotation(Dialog);
  algorithm
    eta := eta_nominal;
  end constantEfficiency;

  function linearPower "线性功率消耗特性 (2点确定一条直线)"
    extends basePower;
    input SI.VolumeFlowRate V_flow_nominal[2]
        "两个额定工作点的体积流量 (单泵)" annotation(Dialog);
    input SI.Power W_nominal[2] "两个工作点对应的耗功" annotation(Dialog);

    /* 构建线性方程组：
       W_nominal[1] = c[1] + V_flow_nominal[1]*c[2];
       W_nominal[2] = c[1] + V_flow_nominal[2]*c[2];
    */
    protected
    // ⚠️ 【已修复官方 BUG】：原版此处错误写成了 ones(3)，2维矩阵必须使用 ones(2)，否则会引发矩阵维度不匹配的致命崩溃！
    Real c[2] = Modelica.Math.Matrices.solve([ones(2),V_flow_nominal],W_nominal)
        "线性功率曲线系数";
  algorithm
    consumption := c[1] + V_flow*c[2];
  end linearPower;

  function quadraticPower "二次抛物线功率消耗特性 (3点确定)"
    extends basePower;
    input SI.VolumeFlowRate V_flow_nominal[3]
        "三个额定工作点的体积流量 (单泵)" annotation(Dialog);
    input SI.Power W_nominal[3]
        "三个工作点对应的耗功" annotation(Dialog);

    protected
    Real V_flow_nominal2[3] = {V_flow_nominal[1]^2,V_flow_nominal[2]^2, V_flow_nominal[3]^2}
        "额定流量的平方值数组";
    /* 构建线性方程组：
       W_nominal[1] = c[1] + V_flow_nominal[1]*c[2] + V_flow_nominal[1]^2*c[3];
       ...
    */
    Real c[3] = Modelica.Math.Matrices.solve([ones(3),V_flow_nominal,V_flow_nominal2],W_nominal)
        "二次抛物线功率曲线系数";
  algorithm
    consumption := c[1] + V_flow*c[2] + V_flow^2*c[3];
  end quadraticPower;

end PumpCharacteristics;