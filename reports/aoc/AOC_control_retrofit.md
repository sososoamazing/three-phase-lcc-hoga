> **归档说明**：本文是原项目报告的公开归档版；数值与结论未改，仅将本机绝对路径替换为占位符、把图片指向本仓库 `reports/accuracy_figures/`。原文中未随包迁移的内部 CSV/目录链接可能失效；可复现数据以 `data/` 与 `docs/08_文件与证据索引.md` 为准。

# 在 ideal_three_phase_LCC 上增加的 AOC 控制（说明）

**目标模型**：`MATLAB_PRJ/three_phase/simulink/ideal_three_phase_LCC_AOC.slx`
**原模型**：`ideal_three_phase_LCC.slx`（未修改，保持原样）

## 改了什么

| 原模型 | 新模型 |
|---|---|
| `Sine Wave1/2/3` 固定频率源（`2*pi*fs`）直接进 `Driver` A/B/C | `From(Vo)` → `PfmFrequency`（1-D 查表，Flat）→ `PhaseRate`（×2π）→ `PhaseAccumulator`（积分）→ 三路 `sin`（0/+120°/+240°）→ `GateMaskA/B/C` → `Driver` A/B/C |
| 无到压停充 | `AtTarget(>=800)` + `LatchOr` + `StopLatch`（UnitDelay 1e-7）自锁 → `GateEnable = 1-latch` → 三路 `GateMask` |
| 固定 `fs=280 kHz` | `pfmVoltage/pfmFrequency` 由 `aoc_schedule` 生成（61 断点，0–800 V，241.59–300 kHz，0–20 V 用 300 kHz 启动） |
| 求解器 VariableStepAuto，RelTol 1e-3，Stop 0.003 | ode15s，RelTol 2e-7，AbsTol 2e-9，MaxStep `1/(200·299257)`，Stop 0.0035 |
| 无记录 | `VoLog`、`FsLog` 两个 `To Workspace`（可删） |

新增块名：`VoFrom`、`PfmFrequency`、`PhaseRate`、`PhaseAccumulator`、`PhaseB`、`PhaseC`、`SinA/B/C`、`GateMaskA/B/C`、`AtTarget`、`TargetVoltage`、`LatchOr`、`StopLatch`、`OneConst`、`GateEnable`、`VoLog`、`FsLog`。

`InitFcn` 末尾追加：

```matlab
addpath('$PROJECT_ROOT/model_comparison_HOGA_EDF_FHA/charging_trajectory_AOC_10point_validation/scripts');
[pfmVoltage,pfmFrequency]=aoc_schedule;
```

> 如果移动了工程目录，需要同步改这一行，或把 `aoc_schedule.m` 放到 MATLAB 路径上。

## 实测验证（器件保持原模型的理想值 Ron=eps、Vf=eps）

| 检查 | 结果 |
|---|---|
| 输出电压 | 0 → 800.11 V，3.5 ms 末值 800.11 V |
| 到压时间 | **t800 = 2.151012 ms**（对比：器件 1e-6/0.6 V 的验证模型为 2.153487 ms，差 0.12%，来自二极管压降） |
| 频率阶梯 | 20 V→243.6 kHz、200 V→244.6、300 V→243.9、400 V→272.3、500 V→280.0、600 V→281.8、700 V→290.4、790 V→299.3 kHz |
| 最低频率 | 241.6 kHz |
| 停充 | 到 800 V 后锁存，电压保持 800.11 V 不再上升 |

运行时会看到 `Driver/On Delay*` 的过零警告（零死区理想驱动造成），不影响结果。

## 怎么用

```matlab
open_system('MATLAB_PRJ/three_phase/simulink/ideal_three_phase_LCC_AOC')
% 直接 Run；VoLog / FsLog 会出现在 out 里
out = sim('ideal_three_phase_LCC_AOC');
plot(out.Vo_meas.time, out.Vo_meas.signals.values)
```

- 改频率表：编辑 `.../aoc_reoptimization_20261020/data/local_254V_revision_20261020/aoc_smooth254_59_nodes.csv`，或直接改 `aoc_schedule.m`；
- 改目标电压：把 `TargetVoltage` 常量的 800 改掉；
- 关掉记录：删除 `VoLog`、`FsLog`；
- 想复现 2.153487 ms：把 6 个二极管 `Vf` 改成 0.6、`Ron` 改成 1e-6、MOS `Rds` 改成 1e-6、`Goff` 改成 1e-11。

## 注意

- 原模型 `ideal_three_phase_LCC.slx` 没有改动；
- 这是**开环频率前馈**，不是恒流/恒功率闭环；电流限值、ZVS 都没有闭环保护；
- 仿真前请确认 `aoc_schedule.m` 在路径上，否则 `pfmVoltage` 未定义会报错。
