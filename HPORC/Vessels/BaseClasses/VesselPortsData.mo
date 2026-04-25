record VesselPortsData "用于描述容器进出口物理特征的数据包：
    diameter -- 进出口端口的内部水力直径
    height -- 端口距离容器底部的高度
    zeta_out -- 流出容器时的水力阻力系数，默认值为 0.5 (适用于与壁面平齐安装的小管径)
    zeta_in -- 流入容器时的水力阻力系数，默认值为 1.04 (适用于与壁面平齐安装的小管径)"

    // 继承 Modelica 标准图标记录
    extends Modelica.Icons.Record;
    import SI = Modelica.SIunits;

  parameter SI.Diameter diameter
    "进出口端口的内部 (水力) 直径";
  parameter SI.Height height = 0 "端口距离容器底部的物理高度";
  parameter Real zeta_out(min=0)=0.5
    "流出容器的水力局部阻力系数 (默认 0.5 适用于齐平壁面安装)";
  parameter Real zeta_in(min=0)=1.04
    "流入容器的水力局部阻力系数 (默认 1.04 适用于齐平壁面安装)";

  // =======================================================================
  // 官方说明文档与 Idelchik 流体阻力手册查表数据 (全网最完整汉化版)
  // =======================================================================
  annotation (preferredView="info", Documentation(info="<html>
<h4>容器端口阻力数据 (Vessel Port Data)</h4>
<p>
本记录包 (record) 用于描述<strong>容器端口</strong>的物理特性。其中的大多数变量从名字即可看出含义；此处仅对局部阻力系数 &zeta; (zeta) 进行详细探讨。以下所有经验数据均引自流体力学权威著作《Idelchik (1994) 流体阻力手册》。
</p>

<h4>流出系数 (Outlet Coefficients - 流体从容器进入管道)</h4>

<p>
如果一根<strong>具有恒定横截面的直管与容器内壁平齐安装</strong>，其出口局部压降系数为 <code>&zeta; = 0.5</code> (参考 Idelchik, 第160页, 图表 3-1, 第2段)。
</p>
<p>
如果一根<strong>直管插入了容器内部，使得管口入口端距离内壁的距离为</strong> <code>b</code>，则可使用下表进行取值。在此表中，&delta; 代表管道壁厚 (Idelchik, 第160页, 图表 3-1, 第1段)。
</p>

<table border=\"1\" cellspacing=\"0\" cellpadding=\"2\">
  <caption align=\"bottom\">流出压降系数 (管口距离壁面有一定距离 b)</caption>
  <tr>
    <td></td> <td>   </td><th colspan=\"5\" align=\"center\"> b / D_hyd (距离/水力直径) </th>
  </tr>
  <tr>
    <td></td> <td>   </td><th> 0.000 </th><th> 0.005 </th><th> 0.020 </th><th> 0.100 </th><th> 0.500-&#8734; </th>
  </tr>
  <tr>
     <th rowspan=\"5\" valign=\"middle\">&delta; / D_hyd <br>(壁厚/直径)</th> <th> 0.000 </th><td> 0.50 </td><td> 0.63  </td><td> 0.73  </td><td> 0.86  </td><td>      1.00     </td>
  </tr>
  <tr>
              <th> 0.008 </th><td> 0.50 </td><td> 0.55  </td><td> 0.62  </td><td> 0.74  </td><td>      0.88     </td>
  </tr>
  <tr>
              <th> 0.016 </th><td> 0.50 </td><td> 0.51  </td><td> 0.55  </td><td> 0.64  </td><td>      0.77     </td>
  </tr>
  <tr>
              <th> 0.024 </th><td> 0.50 </td><td> 0.50  </td><td> 0.52  </td><td> 0.58  </td><td>      0.68     </td>
  </tr>
  <tr>
              <th> 0.040 </th><td> 0.50 </td><td> 0.50  </td><td> 0.51  </td><td> 0.51  </td><td>      0.54     </td>
  </tr>
</table>

<p>
如果一根<strong>带有圆形喇叭口 (收集器/渐缩管) 且无挡板的直管与容器壁平齐安装</strong>，其压降系数可由下表确定。其中，r 为喇叭口表面的曲率半径 (Idelchik, 第164页, 图表 3-4, 段落 b)。
</p>

<table border=\"1\" cellspacing=\"0\" cellpadding=\"2\">
  <caption align=\"bottom\">流出压降系数 (喇叭口与壁面平齐)</caption>
  <tr>
    <td></td> <th colspan=\"6\" align=\"center\"> r / D_hyd (曲率半径/水力直径) </th>
  </tr>
  <tr>
    <td></td> <th> 0.01 </th><th> 0.03 </th><th> 0.05 </th><th> 0.08 </th><th> 0.16 </th><th>&ge;0.20</th>
  </tr>
  <tr>
     <th>&zeta;</th> <td> 0.44 </td><td> 0.31 </td><td> 0.22  </td><td> 0.15  </td><td> 0.06  </td><td>      0.03     </td>
  </tr>
</table>

<p>
如果一根<strong>带有圆形喇叭口且无挡板的直管，伸入容器内部一定距离安装</strong>，其压降系数可由下表确定。其中 r 为喇叭口的曲率半径 (Idelchik, 第164页, 图表 3-4, 段落 a)。
</p>

<table border=\"1\" cellspacing=\"0\" cellpadding=\"2\">
  <caption align=\"bottom\">流出压降系数 (喇叭口伸入容器内部)</caption>
  <tr>
    <td></td> <th colspan=\"6\" align=\"center\"> r / D_hyd (曲率半径/水力直径) </th>
  </tr>
  <tr>
    <td></td> <th> 0.01 </th><th> 0.03 </th><th> 0.05 </th><th> 0.08 </th><th> 0.16 </th><th>&ge;0.20</th>
  </tr>
  <tr>
     <th>&zeta;</th> <td> 0.87 </td><td> 0.61 </td><td> 0.40  </td><td> 0.20  </td><td> 0.06  </td><td>      0.03     </td>
  </tr>
</table>

<h4>流入系数 (Inlet Coefficients - 流体从管道喷射进入容器)</h4>

<p>
如果一根<strong>恒定圆形截面的直管与容器壁平齐安装</strong>，流体喷入容器的压降系数如下表所示 (参考 Idelchik, 第209页, 图表 4-2，假设 <code>A_port/A_vessel = 0</code> 即容器无限大，以及 第640页 图表 11-1 图a)。根据文献描述，对于充分发展的湍流，取 <code>m = 9</code> 是最合理的。
</p>

<table border=\"1\" cellspacing=\"0\" cellpadding=\"2\">
  <caption align=\"bottom\">流入压降系数 (圆管与壁面平齐，突扩射流)</caption>
  <tr>
    <td></td> <th colspan=\"6\" align=\"center\"> m (速度剖面系数) </th>
  </tr>
  <tr>
    <td></td> <th> 1.0 </th><th> 2.0 </th><th> 3.0 </th><th> 4.0 </th><th> 7.0 </th><th>9.0</th>
  </tr>
  <tr>
     <th>&zeta;</th> <td> 2.70 </td><td> 1.50 </td><td> 1.25  </td><td> 1.15  </td><td> 1.06  </td><td>      1.04     </td>
  </tr>
</table>

<p>
对于相对于容器横截面积较大的端口直径，其流入压降系数需考虑面积比，下表提供了修正数据 (参考 Idelchik, 第209页, 图表 4-2，取 <code>m = 7</code>)。
</p>

<table border=\"1\" cellspacing=\"0\" cellpadding=\"2\">
  <caption align=\"bottom\">流入压降系数 (考虑管口与容器面积比)</caption>
  <tr>
    <td></td> <th colspan=\"6\" align=\"center\"> A_port / A_vessel (管口面积 / 容器横截面积) </th>
  </tr>
  <tr>
    <td></td> <th> 0.0 </th><th> 0.1 </th><th> 0.2 </th><th> 0.4 </th><th> 0.6 </th><th>0.8</th>
  </tr>
  <tr>
     <th>&zeta;</th> <td> 1.04 </td><td> 0.84 </td><td> 0.67  </td><td> 0.39  </td><td> 0.18  </td><td>      0.06     </td>
  </tr>
</table>

<h4>参考文献 (References)</h4>

<dl><dt>Idelchik I.E. (1994):</dt>
    <dd><a href=\"http://www.bookfinder.com/dir/i/Handbook_of_Hydraulic_Resistance/0849399084/\"><strong>Handbook
        of Hydraulic Resistance (流体阻力手册)</strong></a>. 第3版, Begell House出版, ISBN
        0-8493-9908-4</dd>
</dl>
</html>"));
end VesselPortsData;