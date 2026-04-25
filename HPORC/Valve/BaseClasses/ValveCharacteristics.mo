package ValveCharacteristics "阀门固有流量特性函数库 (工业全量翻译解析版)"
  extends Modelica.Icons.VariantsPackage;

  // =====================================================================
  // 1. 基类接口：定义了所有阀门特性函数的输入输出标准
  // =====================================================================
  partial function baseFun "阀门特性函数的基类接口"
    extends Modelica.Icons.Function;

    input Real pos(min=0, max=1)
        "阀门物理开度位置 (0: 完全关闭, 1: 完全打开)";

    output Real rc
        "相对流量系数 (每单位 per unit)。即当前开度下的有效流通能力占最大流通能力的比例。";

    annotation (Documentation(info="<html>
<p>
这是一个部分函数 (partial function)，定义了所有阀门流量特性的标准接口。
该函数以物理开度 \"pos\" (范围 0..1) 作为输入，返回相对流量系数 \"rc = valveCharacteristic\"：
</p>

<blockquote><pre>
    dp = (zeta_TOT/2) * rho * velocity^2
m_flow =    sqrt(2/zeta_TOT) * Av * sqrt(rho * dp)
m_flow = valveCharacteristic * Av * sqrt(rho * dp)
m_flow =                  rc * Av * sqrt(rho * dp)
</pre></blockquote>
<p>简而言之：实际流量 = 相对流量系数(rc) * 全开流量</p>
</html>"));
  end baseFun;

  // =====================================================================
  // 2. 线性特性 (Linear)
  // =====================================================================
  function linear "线性特性"
    extends baseFun;
  algorithm
    // 阀门气动面积与物理开度完全成正比。适用于压降主要集中在阀门本身（管网阻力小）的系统。
    rc := pos;
  end linear;

  // =====================================================================
  // 3. 常数特性 (Constant)
  // =====================================================================
  function one "常数特性"
    extends baseFun;
  algorithm
    // 无论开度怎么变，系数始终为 1。通常用于那些不随开度变化的参数（比如默认的液态压力恢复系数 Fl）。
    rc := 1;
  end one;

  // =====================================================================
  // 4. 二次方/快开特性 (Quadratic / Quick Opening)
  // =====================================================================
  function quadratic "二次方特性"
    extends baseFun;
  algorithm
    // 典型的快开特性，开度初期流量变化极慢，后期急剧增加（或者反过来，取决于具体定义，这里是抛物线）。
    rc := pos*pos;
  end quadratic;

  // =====================================================================
  // 5. 等百分比特性 (Equal Percentage) - 工业调节阀绝对主力！
  // =====================================================================
  function equalPercentage "等百分比特性 (工业 PID 调节最常用)"
    extends baseFun;

    input Real rangeability = 20 "可调比 (Rangeability)。即最大流量与最小可控流量之比" annotation(Dialog);
    input Real delta = 0.01 "线性修正区下限 (为了解决等百分比在 0 开度时无法真正关死的数学绝症)" annotation(Dialog);

  algorithm
    // 【数学防爆黑魔法】：
    // 纯理论的等百分比曲线是一个指数函数，它在 pos=0 时永远不可能等于 0（阀门关不死）。
    // 所以官方在这里做了一个极其聪明的 C0 连续拼接：
    // 当开度大于 delta (默认 1%) 时，走真实的指数曲线；
    // 当开度小于 delta 时，切断指数曲线，强行用一根直线 (pos/delta) 把它拉到绝对的 0！
    rc := if pos > delta then rangeability^(pos-1) else 
            pos/delta*rangeability^(delta-1);

    annotation (Documentation(info="<html>
<p>这种特性的特点是：流量系数的<b>相对变化率</b>与阀门开度的变化量成正比：</p>
<p> d(rc)/d(pos) = k * d(pos)。</p>
<p> 常数 k 可以用可调比 (rangeability) 来表示。可调比是阀门最大有用流量系数与最小有用流量系数的比值：</p>
<p> rangeability = exp(k) = rc(1.0)/rc(0.0)。</p>
<p> 【防爆修正】：理论上的等百分比特性在开度 pos = 0 时，其流量系数并不为零（无法关死）；为此，本模型在实现时进行了巧妙的数学修正：当开度小于 delta（如 1%）时，强制阀门按照线性规律关闭到 0。</p>
</html>"));
  end equalPercentage;

end ValveCharacteristics;