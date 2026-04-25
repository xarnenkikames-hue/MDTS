# MDTS

MDTS 是一个基于 **Modelica** 的**深地热电转化系统**建模与仿真项目，运行环境为 **MWorks Sysplorer**。从当前组件库和现有回路模型来看，这个项目并不是单一 ORC 库，而是围绕**深地热源利用场景**，逐步组织了以下几类热工子系统能力：

- **ORC（Organic Rankine Cycle）发电回路**
- **热泵（Heat Pump）/压缩机驱动回路能力**
- **储热/储液/缓冲容积能力**
- 以及这些子系统在统一流体网络框架下的耦合建模基础

当前仓库最完整、最明确的系统级案例主要落在 `R134aORC/`，但 `HPORC/` 组件库本身已经覆盖了泵、压缩机、换热器、阀门、容器、透平/膨胀机等多个方向，因此更准确的理解应是：

> `HPORC` 提供深地热电转化系统所需的通用热流体组件基础，`R134aORC` 是当前最具体、最成熟的一条回路模型主线。

本仓库不是传统软件工程项目，没有 `Makefile`、`CMake`、`package.json` 或 pytest 等构建/测试系统；主要工作流是在 Sysplorer 中对 `.mo` 模型执行加载、检查和仿真。

## 仓库结构

### `HPORC/`：通用热流体组件库

`HPORC` 是项目的底层组件库，顶层包定义见 `HPORC/package.mo:1`。从现有文件结构和基类关系看，它承担的是“系统建模积木库”的角色，而不是单一 ORC 专用库。

可按功能分成以下几层：

- `Interfaces/`
  - 定义 `FluidPort`、`HeatPort` 等连接器
  - 为全库的流体与热连接提供统一接口
- `BaseClasses/`
  - 定义抽象基类，例如 `PartialTwoPort`、`PartialDistributedVolume`、`PartialLumpedVolume`
  - 统一双端口流向、端口储能暴露方式、系统耦合方式
- `System.mo`
  - 统一全局系统参数，例如默认压力、温度、流量初值、动力学设置、正则化参数
- `Sources/`
  - 边界条件与驱动源，例如 `Boundary_pT`、`Boundary_ph`、`MassFlowSource_T`
- `Pipe/`
  - 静态管道、动态管道、两相摩擦与换热辅助模型
- `HeatExchanger/`
  - 换热器总成和壁面模型，核心为 `BasicHX`
- `Pump/`
  - 泵模型，常用入口是 `PrescribedPump`
- `Valve/`
  - 包括可压缩流体阀门、不可压缩阀门、离散阀门等
- `Vessels/`
  - 储液器、缓冲容积、容器相关模型
- `Turbine/` 与 `Expanders/`
  - 透平、膨胀机模型
- `Compressor/`
  - 压缩机模型，例如 `RobustCompressor`

### `R134aORC/`：现有回路模型主线

`R134aORC` 是当前仓库中最清晰的系统级案例集合。虽然包名是 ORC，但从项目整体目标看，它更像是“深地热电转化系统中的一条工质回路建模主线”。

当前目录包括：

- `a/`：Step01 诊断与基线回路
- `b/`：Step02 热态启动回路
- `c/`：Step03 透平单机与在线接入回路
- `d/`：Step04 加负载与无 anchor 调整回路
- `ORCLoop_Minimal_R134a.mo`：独立构造的最小闭式 R134a ORC 测试模型

同时保留了若干阶段性说明文档：

- `R134aORC/a/R134a_ORC_进展说明_v2.docx`
- `R134aORC/b/R134a_ORC_阶段性技术总结_热态母版定稿.docx`
- `R134aORC/c/透平回归阶段测试总结.docx`

## 组件库的实际建模框架

### 1. `System` 是全局默认物理环境

`HPORC/System.mo:1` 不是普通组件，而是顶层模型的全局环境对象。它向所有 `outer system` 子组件提供：

- 默认环境压力与温度
- `allowFlowReversal`
- 质量/能量/动量动力学选项
- `p_start`、`T_start`、`m_flow_start`
- 小流量/小压差正则化参数

顶层模型通常都包含：

```modelica
inner HPORC.System system(
  p_start = p_init,
  use_eps_Re = true);
```

### 2. `PartialTwoPort` 统一双端口流体元件接口

`HPORC/BaseClasses/PartialTwoPort.mo:1` 是很多组件的共同抽象上层。它统一规定了：

- `port_a` / `port_b` 的设计流向
- 是否允许反向流动
- 端口是否暴露内部储能状态

这意味着库中大量设备都可以按统一方式串接成回路，例如：

- 泵
- 阀门
- 静态管道
- 部分换热与压降元件

### 3. 容积元件在回路中承担稳定与耦合作用

`HPORC/Vessels/CylindricalClosedVolume.mo:1` 与 `HPORC/Vessels/ClosedVolume.mo:1` 都属于容积类元件。它们在现有模型中承担的角色不只是“储液罐”，还包括：

- receiver
- header
- plenum
- 缓冲与分流汇流节点
- 储液/储能近似节点

从系统角度看，这类容积元件是把复杂耦合回路从“纯理想连接”转为“可数值求解网络”的关键。

### 4. 换热器是跨回路耦合核心

`HPORC/HeatExchanger/BasicHX.mo:1` 是现有回路模型最核心的耦合组件之一。

它具有两套端口：

- `port_a1 / port_b1`：一侧流体
- `port_a2 / port_b2`：另一侧流体

在 `R134aORC` 现有模型里通常这样使用：

- 蒸发器：
  - 工质侧 = `Medium_1 = Modelica.Media.R134a.R134a_ph`
  - 热源侧 = `Medium_2 = Modelica.Media.Water.ConstantPropertyLiquidWater`
- 冷凝器：
  - 冷源侧 = `Medium_1 = Modelica.Media.Water.ConstantPropertyLiquidWater`
  - 工质侧 = `Medium_2 = Modelica.Media.R134a.R134a_ph`

这说明 `BasicHX` 并不局限于 ORC，而是系统中“不同流体回路之间交换能量”的通用耦合单元。

### 5. 压缩机、透平、膨胀机共同说明库不是单一 ORC 库

从现有组件目录可以直接看出，库同时具备：

- 泵：`HPORC/Pump/`
- 压缩机：`HPORC/Compressor/RobustCompressor.mo:1`
- 透平：`HPORC/Turbine/PartialTurbine.mo:1`
- 膨胀机：`HPORC/Expanders/CustomVolumetricExpander.mo:1`

这类设备组合更符合“热电转化系统/热泵/储热耦合系统基础库”的定位，而不是单一的 ORC 专项工具箱。

例如：

- `RobustCompressor` 明确实现了湿压缩保护、过热度惩罚、压缩机机械动力学
- `PartialTurbine` 提供了透平机械轴、流体焓降和旋转动力学接口
- `CustomVolumetricExpander` 提供了容积式膨胀机实现

## 现有回路模型梳理

以下内容只基于当前已经存在的回路模型，不讨论无效尝试或失败分支。

### Step01：诊断与最小主回路

代表模型：`R134aORC/a/R134a_ORC_Step01_Testbench.mo:1`

该模型提供了当前主线回路的基础骨架，主要特点：

- R134a 工质侧闭环
- 水侧热源与冷源边界
- `receiver + pump + evaporator + valve + condenser + receiver`
- `Boundary_ph + expPipe` 提供低压 anchor
- 冷态初始化为主，热侧激励可通过参数启停

这是当前系统主线中最重要的基线模型之一。

### Step02：热态启动回路

代表模型：`R134aORC/b/R134a_ORC_Step02_HotStart.mo:1`

在 Step01 结构基础上，Step02 明确引入热源时序，开始考察热态启动。其意义在于：

- 验证热源侧激励进入后，回路如何从冷态向工作态过渡
- 保持主回路拓扑不大改动，便于隔离热启动影响
- 为后续引入透平支路提供“热态母版”

### Step03：透平单机与在线接入

代表模型：

- `R134aORC/c/R134a_ORC_Step03_C0_TurbineBench.mo:1`
- `R134aORC/c/R134a_ORC_Step03_C1_MinOnlineTurbine_Fixed.mo:1`

这一阶段把“透平本体验证”和“透平接入系统”拆成两步：

- `C0_TurbineBench`
  - 是透平单机台架模型
  - 用于验证 `CustomVolumetricExpander_C0` 与入口阀、前室、机械链的协同关系
- `C1_MinOnlineTurbine_Fixed`
  - 把透平接回完整回路
  - 引入 `hpHeader`、`lpHeader`、`turbineInletPlenum` 等容积节点
  - 解决蒸发器出口直接理想三通引发的高刚性和零流问题

这一阶段体现出项目的真实建模方法：

> 新设备不会直接硬塞进主回路，而是先台架验证，再通过 header / plenum / short pipe 这类缓冲结构平滑接入系统。

### Step04：带负载与结构微调

代表模型：

- `R134aORC/d/R134a_ORC_Step04_D0_LoadFromC1.mo`
- `R134aORC/d/R134a_ORC_Step04_D0_LoadFromC1_NoAnchor.mo`
- `R134aORC/d/R134a_ORC_Step04_D0_LoadFromC1_NoAnchor_hotT300.mo`
- `R134aORC/d/R134a_ORC_Step04_D0_LoadFromC1_NoAnchor_Tuned.mo`

这一阶段是在 C1 的在线透平回路上继续推进：

- 增加外部机械负载
- 调整是否保留低压 anchor
- 调整体积缓冲件与短管尺度
- 调整热侧流量和温升时序

从命名与参数组织可见，D 轮的工作重点不是“重新发明新拓扑”，而是围绕现有在线回路做结构缓冲与时序细化。

### `ORCLoop_Minimal_R134a`

文件：`R134aORC/ORCLoop_Minimal_R134a.mo:1`

这是一个独立构造的最小闭式 R134a ORC 测试模型，用于快速验证：

- 当前组件接口是否能形成最小闭式回路
- 含透平结构是否能通过模型检查
- 不依赖大规模控制系统的最小拓扑是否闭合

它不是项目主线阶段的一部分，而更像“基于现有组件的结构验证模型”。

## 工质、介质与初始化约定

从现有回路模型可以归纳出以下稳定约定：

- 工质侧统一使用：
  - `Modelica.Media.R134a.R134a_ph`
- 水侧热源/冷源常用：
  - `Modelica.Media.Water.ConstantPropertyLiquidWater`
- 两相区初始化优先使用 `p-h`
- 常见初值：
  - `p_init = 6e5`
  - `h_init = 227000`
  - `h_water_init = 84000`
- 换热器中常见：
  - `use_T_start = false`
- 顶层 system 常见：
  - `use_eps_Re = true`

这些约定说明项目非常重视两相区初始化的数值稳健性。

## 常用操作方式

本项目主要通过 Sysplorer 或 MCP 工具操作模型。

### 检查模型

```python
check_model(model_name="R134aORC.b.R134a_ORC_Step02_HotStart")
```

### 仿真模型

```python
simulate_model(model_name="R134aORC.d.R134a_ORC_Step04_D0_LoadFromC1_NoAnchor_Tuned")
```

### 导出原理图

```python
model_manager(
  action="export_model_diagram",
  model_name="R134aORC.ORCLoop_Minimal_R134a",
  output_path="D:\\Modelica\\MDTS\\R134aORC\\ORCLoop_Minimal_R134a.png"
)
```

## 当前可得的项目理解

仅从**现有组件库**和**当前已有回路模型**出发，可以把 MDTS 理解为：

- 一个面向深地热电转化系统的热流体建模平台
- `HPORC` 是通用组件层
- `R134aORC` 是当前最具体、最成熟的一条系统建模主线
- 系统能力并不只限于 ORC，而是已经覆盖：
  - 发电回路
  - 压缩机/热泵相关能力
  - 储液/储热/缓冲容积能力
  - 多回路能量交换能力

如果后续继续完善文档，建议进一步补充：

- 每个阶段模型的目标与适用场景
- 不同容积节点（receiver/header/plenum）在系统中的角色差异
- 哪些组件更偏“系统级耦合”，哪些更偏“单机性能部件”
