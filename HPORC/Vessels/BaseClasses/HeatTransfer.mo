package HeatTransfer "用于容器设备的外壁面传热模型包 (HeatTransfer models for vessels)"
  // 继承标准图标包
  extends Modelica.Icons.Package;
  import SI = Modelica.SIunits;

  // =======================================================================
  // 1. 传热代理基类 (定义接口，不写具体方程)
  // =======================================================================
  partial model PartialVesselHeatTransfer
      "容器壁面传热模型的底层代理基类 (Base class for vessel heat transfer models)"
    // 继承流体库最底层的通用传热接口（该接口定义了介质温度 Ts、热端口 heatPorts、传热面积 surfaceAreas 和热流 Q_flows）
    extends Modelica.Fluid.Interfaces.PartialHeatTransfer;

    annotation(Documentation(info="<html>
<p>容器设备壁面传热模型的代理基类。</p>
<p>它本身不包含具体的传热方程，仅仅是在 UI 界面上绘制了一个红色的热力学球体图标，并定义了标准的流体热交互边界引脚。</p>
</html>"    ),Icon(coordinateSystem(preserveAspectRatio=true,  extent={{-100,-100},
                {100,100}}), graphics={Ellipse(
              extent={{-60,64},{60,-56}},
              fillPattern=FillPattern.Sphere,
              fillColor={232,0,0}), Text(
              extent={{-38,26},{40,-14}},
              textString="%name")}));
  end PartialVesselHeatTransfer;

  // =======================================================================
  // 2. 理想传热模型 (默认选项：无限大传热系数)
  // =======================================================================
  model IdealHeatTransfer
      "IdealHeatTransfer: 无热阻的理想传热模型 (Ideal heat transfer without thermal resistance)"
    extends PartialVesselHeatTransfer;

  equation
    // 【物理铁律】：内部流体介质的温度 (Ts) 绝对等于外部热端口的金属壁面温度 (heatPorts.T)
    // 求解器会根据这个强绑定等式，自动反向推算出满足守恒所需的热流 Q_flows
    Ts = heatPorts.T;

    annotation(Documentation(info="<html>
<p><b>无热阻的理想传热模型。</b></p>
<p>物理假设：容器金属外壳的导热系数无限大，且内部流体的对流换热系数无限大。<br>
这意味着外部连接的金属热端口温度，将瞬间与容器内部工质的混合温度拉平，没有任何热惯性延迟。</p>
</html>"));
  end IdealHeatTransfer;

  // =======================================================================
  // 3. 恒定系数传热模型 (符合牛顿冷却定律的真实工程模型)
  // =======================================================================
  model ConstantHeatTransfer
      "ConstantHeatTransfer: 恒定传热系数的对流散热模型 (Constant heat transfer coefficient)"
    extends PartialVesselHeatTransfer;

    // 需要工程师手动输入的对流换热系数 (例如：空气自然对流通常为 5~25 W/(m2.K))
    parameter SI.CoefficientOfHeatTransfer alpha0
        "恒定对流换热系数 (Constant heat transfer coefficient)";

  equation
    // 【牛顿冷却定律】：Q = h * A * (T_wall - T_fluid)
    // 热流率 = (常数 alpha0 + 修正系数 k) * 换热面积 * (外部热端口温度 - 内部流体温度)
    // 遍历求解 n 个离散节点的传热（对于集总容器，通常 n=1）
    Q_flows = {(alpha0+k)*surfaceAreas[i]*(heatPorts[i].T - Ts[i]) for i in 1:n};

    annotation(Documentation(info="<html>
<p><b>基于恒定对流换热系数的简单传热关联式。</b></p>
<p>这是一个极具工程实用价值的模型。当你需要模拟高压储液罐在环境冷风中散热导致的压力下降时，可以选择此模型并输入一个经验传热系数 <code>alpha0</code>。</p>
</html>"));
  end ConstantHeatTransfer;

  annotation (Documentation(info="<html>
管道与容器模型的壁面传热关联式合集。
</html>"));

end HeatTransfer;