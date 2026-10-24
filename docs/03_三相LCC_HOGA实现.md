# 03 三相 LCC 的 HOGA 实现：事件增强移动 Fourier 周期稳态

> 对应代码：`code/matlab/core/lcc3v2Hoga.m`（审计版 V2.3）、`code/matlab/accelerated/studyHoga.m`（向量化等价版）、`code/matlab/h49/h49Solve.m`（固定 H=49 版）。
> 对应报告：`reports/audit/HOGA_Audit_Report.md`、`reports/comparison/HOGA_EDF_FHA_Accuracy_Analysis.md` 第 1.3 节。

## 3.1 为什么不是直接套论文的线性平衡方程

论文第 III 节的稳态做法是：给定开关信号的移动 Fourier 系数 `<s>`，解线性平衡方程得到 `<x>`。这对 PWM/PSM/PFM 的**已知开关时刻**很有效。

三相 LCC 的困难在于：

1. 六个二极管的事件时刻由**状态轨迹**决定，不是预先给定的占空比；
2. 整流桥有六张面（六种导通对），还允许三管重叠和全截止；
3. 事件时刻与电流谐波、二次侧 DC 电压必须**同时**满足周期闭合、触边/释放和谱方程；
4. 如果只把电流截断到有限阶，电压在门控跳变处的导数不连续，强形式 KVL 不可能逐点成立。

因此本项目采用 **event-enriched moving-Fourier equilibrium**：

- 电流 `q(t)` 用有限复 Fourier 级数表示（`±1…±H`，DC 为零）；
- 二次侧电压 `e(t)` 不用有限阶截断，而是在每个导通区间内**精确分段积分**；
- 二极管事件时刻 `τ_k` 和二次侧 DC 电压作为非线性未知量；
- 电流系数在给定事件 schedule 下由线性方程消元；
- 用 `lsqnonlin` 解事件残差 + 触边/释放 + 周期闭合。

这就是“事件增强”的含义：**不是把所有波形都截断到 H 阶，而是让整流电压保留分段精确结构，只对谐振电流做 Fourier 截断。**

## 3.2 未知量与事件 schedule

### 3.2.1 电流的 Fourier 表示

```
i(τ) = Σ_{h=-H, h≠0}^{H} I_h e^{jhωτ},   I_{-h} = conj(I_h)
```

`q` 的两个 α/β 坐标各有 `2H` 个复系数。DC 电流系数 `I_0 = 0`，由串联电容的周期条件给出，不是未知量。因此电流侧有 `4H` 个实未知（每个复系数实部/虚部）。

### 3.2.2 事件 schedule

门控边沿固定在 `τ = 0, 1/6, 2/6, 3/6, 4/6, 5/6, 1`。二极管事件位于这些门控边沿之间，数量 `Ne` 取决于导通模式（两管、三管、全截止）。事件 schedule 由 `lcc3v2Discover` 从 legacy 有限阶候选的拓扑中提取，或者由上一个 HOGA 解延续。

### 3.2.3 非线性未知量

```
v = [ e0_α/Vd, e0_β/Vd, τ_1, ..., τ_Ne ]
```

- `e0` 是二次侧电压在周期起点的 α/β 分量，缩放到 `[-2, 2]`；
- `τ_k` 被限制在相邻门控边沿/相邻事件的中点之间，防止事件穿越或合并。

所以非线性维度只有 `2 + Ne`，而不是“所有谐波系数”。这是该方法能在几十阶下仍然可解的关键。

## 3.3 事件残差

对给定 `v`：

1. 由 `τ_k` 和门控边沿构造完整区间边界 `ed = sort([0, τ, gateEdges, 1])`；
2. 每个区间有一个活动面集合 `ms{s}`（哪些二极管对导通）；
3. 用区间投影矩阵把电流映射到二次侧电压；
4. 计算残差。

残差由三部分组成：

### (a) 周期闭合

```
r_period = Δe / Vd
```

`Δe` 是一个周期内二次侧电压的净变化。周期稳态要求它为零。

### (b) 活动面电压约束

在每个区间的起点，活动的二极管对必须把对应线电压钳在 `Vd`：

```
r_face = (A_active * e(τ_s) - Vd) / Vd
```

`A_active` 的行是 `U_a - U_b`。这些方程保证“导通的二极管对确实承受 `Vd`”。

### (c) 释放/互补条件

当某个面在事件处被“丢掉”（从活动集移除）时，它必须要么：

- 在电压事件处由另一个面接替；或
- 其有符号反作用电流为零（释放到内部）。

代码用最小二乘求 Lagrange 乘子 `λ`，把 `λ_removed` 归一化后加入残差。这样防止“解出一个电压满足、但二极管电流为负”的非物理候选。

> 这就是为什么“谱残差很小”不等于“物理解”：legacy 在 400 V/H31 的谱残差约 `6.53e-11 V`，但法锥偏差约 5.65 V、功率偏差 2.185%，被物理守卫拒绝。V2.3 的事件增强表示解决了这一类弱谱闭合不足。

## 3.4 给定事件后的线性消元

对每个区间 `s`，活动面矩阵 `A_s`，定义投影：

```
T_s = I - A_s^T (A_s A_s^T)^{-1} A_s
```

`T_s` 把二次侧电压投影到“不违反活动面约束”的子空间。于是：

- 二次侧电压导数：`de/dτ = Kf^T T_s i`；
- 二极管电流：`j = C (I - T_s) i / (3n)`；
- `Kf = n C^T / (3 Cp)`。

把每个区间的 `T_s` 和区间 Fourier 积分系数代入，得到电流系数 `I` 的线性方程：

```
L(event) I = f
```

其中 `L` 包含 `j h ω Ls`、`1/(j h ω Cs)`、共享 `Rin` 的 Toeplitz 卷积、以及 `C e/(3n)` 的耦合。给定事件 schedule，`I` 可以**直接线性求解**，不需要迭代。

求出 `I` 后，二次侧电压的 DC 分量和周期闭合量也可以由区间积分得到。于是非线性残差只依赖 `e0` 和事件时刻。

## 3.5 求解流程

```
输入: p (参数), Vo, H, seed (可选)
  │
  ├─ 若没有 seed:
  │    legacy 有限阶 (min(H,7)) 求候选
  │    lcc3v2Discover 提取事件 schedule
  │    用候选的 e0 作为初值
  │
  ├─ 构造事件边界、活动面集合
  ├─ 构造区间投影 T_s、Fourier 积分系数
  ├─ lsqnonlin 解 [e0/Vd, τ_k]
  │    残差 = 周期闭合 + 活动面电压 + 释放条件
  │
  ├─ 线性回代求电流系数 I
  ├─ 重构 8192 点波形 (τ = (j+0.371)/N)
  ├─ 计算 Io、RMS、峰值、Cp 峰值、功率、二极管最小电流
  ├─ 物理守卫
  └─ 输出 result (含 event_schedule、coeff、metric、wave)
```

重构点数：

```
N = max(8192, 64*(2H+1))
```

峰值不是用 `√2·RMS` 或基波幅值代替，而是在重构波形上逐相取极值，再做局部细化。

## 3.6 物理守卫

`lcc3v2Hoga.m` 的 `physical_guard_pass` 要求：

| 守卫 | 阈值 | 含义 |
|---|---:|---|
| 代数残差 `norm(rr,inf)` | `< 1e-9` | 事件方程收敛 |
| 二极管电压违约 | `≤ 1e-3 * Vd` | 没有超过钳位 |
| 法向残差 `normal_max` | `≤ 1e-3 * Vd` | 互补/法锥成立 |
| 最小有符号二极管电流 | `≥ -1e-7 A` | 没有明显反向电流 |
| 功率相对残差 | `≤ 1e-3` | 功率闭合 |
| 歧义事件 | 不允许 | 事件不能模糊/重合 |

`physical_guard_pass` 通过只说明“在配置的二极管/弱 KVL/能量守卫下可行”，**不等于** H 阶收敛、参考一致、全局唯一或稳定。

## 3.7 验收层级

`lcc3v2Accept.m` 要求三层同时通过：

### 第一层：代数/事件 + 物理守卫

见 3.6。

### 第二层：阶数收敛

连续两次升阶（例如 H9→H15→H31）满足：

```
Io 相对变化 < 0.5%
Irms 相对变化 < 0.5%
峰值相对变化 < 1%
事件拓扑一致
事件时间偏移 < 1e-3 T
```

并且前一次变化也要满足同样条件（`previous_change`）。

### 第三层：独立参考

独立事件 ODE（`lcc3v2Reference.m`）的 fine/coarse 都要周期收敛，且：

- 参考自身加密变化：`Io < 1e-4`、峰值 `< 1e-3`、事件时间 `< 1e-5 T`；
- HOGA 与参考的积分量/峰值/波形 L2 在阈值内；
- 事件拓扑一致。

这三层缺一不可。只有第一层通过的点，不能称为“严格验收”。

## 3.8 H49 版本

`h49Solve.m` 是 `studyHoga.m` 的受控派生，只改四件事：

| 编号 | 修改 | 原因 |
|---|---|---|
| D1 | 固定 `H=49`，移除 H 参数 | AOC 验证只允许 H49 |
| D2 | 删除 `min(H,7)` 拓扑发现；必须提供同 `Vo` 的先验 HOGA 事件解 | 不做低阶求解 |
| D3 | 全截止分支用先验开路系数作初值 | 仅初值 |
| D4 | 增加共轭对称、索引记账等诊断 | 十项验收 |

方程、守卫、容差、事件闭合与物理约束不变。H49 的谐波索引是 `[-49:-1, +1:+49]`，共 98 个复系数/坐标；DC 电流恒为零，因此“99 个索引 = 98 个求解 + 1 个恒为零”，不是 99 个未知量。

H49 的十项验收见 `code/matlab/h49/h49_accept.m` 与 `reports/aoc/AOC_20point_accuracy_report.md`。

## 3.9 已知数值限制

1. **强形式 KVL 不逐点成立**。有限 Fourier 电流的导数在门控跳变处有 Gibbs 现象；H31 全周期强形式 KVL RMS 约 3.9 V。这是表示能力的边界，不是把参数调一调就能消失的。
2. **谱残差小 ≠ 模型误差小**。事件残差可以到 `1e-13` 量级，但峰值/波形误差仍可能存在。
3. **升阶不保证单调改善**。100 V 的 H7→H15 峰值误差反而增大；H7≈H9 是因为三倍频零序抵消，不是“阶数没用”。
4. **全截止分支有 DC 解族**。固定代表解的 `Io=0` 不能证明实际充电可达。
5. **没有移动窗口/小信号**。当前只解冻结周期稳态；论文的 LTP 小信号、变频动态、闭环稳定性都没有实现。
6. **没有 ZVS 认证**。零死区、无 Coss 的模型只能给“换流电流方向”的必要条件。

## 3.10 代码地图

| 文件 | 作用 |
|---|---|
| `core/lcc3v2Hoga.m` | 事件增强 HOGA 主求解器（V2.3） |
| `core/lcc3v2Params.m` | 物理参数与数值设置（`Nfourier=1536`、容差等） |
| `core/lcc3v2Geometry.m` | `B`、`U`、`C`、六面 `A`、`pairs` |
| `core/lcc3v2Discover.m` | 从 legacy 候选提取事件 schedule |
| `core/lcc3v2Metrics.m` | 波形指标、功率、二极管诊断 |
| `core/lcc3v2Reference.m` | 独立事件 ODE 参考 |
| `core/lcc3v2Accept.m` | 三层验收 |
| `core/lcc3_physics.m` | 门控 Fourier 激励、Δ 子空间、整流可行域 |
| `accelerated/studyHoga.m` | 向量化等价实现；扫描用 |
| `h49/h49Solve.m` | 固定 H49 |
| `h49/h49_accept.m` | H49 十项验收 |
| `comparison/model_config.m` | 统一参数入口 |
| `comparison/solve_model.m` | HOGA/EDF/FHA/REFERENCE 统一接口 |
| `normalized/runNormalizedStudy.m` | 归一化 A/B 扫描入口 |
| `normalized/studyPoint*.m` | 单点求解/精化/恢复 |
| `verification/run_comparison.m` | 20 点四模型比较 |
| `verification/run_final_tests.m` | 30 项回归 |

## 3.11 最小调用示例

> 以下示例假设已把 `code/matlab/core`、`code/matlab/accelerated`、`code/matlab/comparison` 加入 MATLAB path，并且已有同 `Vo` 的 HOGA 事件解作为 seed。仓库不附带完整扫描的 `.mat`，因此不能保证“复制即可跑”；复现请按 `docs/08_文件与证据索引.md` 回到原项目数据。

```matlab
addpath('code/matlab/core');
addpath('code/matlab/accelerated');
addpath('code/matlab/comparison');

cfg = model_config();
p   = lcc3v2Params("original_reduced");
p.fs = 280e3;

% 需要一个同 Vo 的 HOGA 事件解作为 seed；下面只是结构示意
% seed = load('.../HOGA_V400_f280000.mat').result.raw;
% raw  = studyHoga(p, 400, 31, seed);
% acc  = lcc3v2Accept(raw, refFine, refCoarse, refChange, orderChange, p);
```

## 3.12 来源

- `reports/audit/HOGA_Audit_Report.md`
- `reports/comparison/HOGA_EDF_FHA_Accuracy_Analysis.md` 第 1.3、2.2、5.1 节
- `code/matlab/core/lcc3v2Hoga.m`
- `code/matlab/core/lcc3v2Accept.m`
- `reports/aoc/AOC_20point_accuracy_report.md`
