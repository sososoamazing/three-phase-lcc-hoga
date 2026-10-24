# 报告归档

这些是原项目报告的公开归档版。**数值与结论未改**；只做了三件事：

1. 本机绝对路径 → `$PROJECT_ROOT` / `$MATLAB` / `$PYTHON`；
2. 图片链接 → 本仓库 `reports/accuracy_figures/`；
3. 文件头加“归档说明”。

部分原文中的内部 CSV/目录链接没有随包迁移，可能失效；数据以 `data/` 为准。

## `reports/comparison/`

| 文件 | 内容 | 备注 |
|---|---|---|
| `HOGA_EDF_FHA_Accuracy_Analysis.md` | 七章精度分析，28 图、17 表 | 主报告；图已复制 |
| `Model_Comparison_Report.md` | 建模/审计/EDF/FHA 统一验证工作报告 | 12 KB |
| `Conclusions_for_Thesis.md` | 可用于论文的结论边界 | 2 KB |

## `reports/audit/`

| 文件 | 内容 |
|---|---|
| `HOGA_Audit_Report.md` | 源码/方程/整流通道审计；F01–F05 问题表 |
| `HOGA_Fix_Log.md` | 两项隔离修复日志 |
| `topology_and_assumptions.md` | 实际接线、参数、六维方程、整流约束 |

## `reports/normalized/`

| 文件 | 内容 | 备注 |
|---|---|---|
| `01_模型参数拓扑审计.md` | 归一化研究的参数/拓扑审计 | — |
| `02_扫描与求解状态.md` | A/B/C 扫描、验收、未决分布 | **最新计数口径**（276/203/73/68） |
| `03_开关模型交叉验证报告.md` | 18 次开关验证 | 17 通过 / 1 失败保留 |
| `04_逐图学术分析.md` | 9 张核心图逐图五段式分析 | — |
| `05_结果与讨论.md` | 论文第 5 章初稿 | **计数为阶段 C 前口径**（263/190/81） |
| `06_交付清单.md` | 交付物/完成度 | 计数也为阶段 C 前口径 |

> 引用计数时以 `02` + `data/normalized/characteristic_domain.csv` 为准。`05`/`06` 的定性结论仍可用，但 263/190/81 不要与 276/203/68 混用。

## `reports/aoc/`

| 文件 | 内容 |
|---|---|
| `AOC_20point_accuracy_report.md` | AOC 20 点完整报告 |
| `AOC_输出特性工作总结.md` | 输出特性工作总结（GPT 评审用） |
| `AOC_control_retrofit.md` | AOC 控制改造说明 |

## `reports/accuracy_figures/`

45 张 PNG，供 `HOGA_EDF_FHA_Accuracy_Analysis.md` 显示：

- 39 张来自 `05_verification/figures/`；
- 6 张来自 `06_reports/accuracy_analysis/figures/`。

文件名保持原样，便于与原项目对照。

## 读报告的顺序

1. `audit/topology_and_assumptions.md`（先知道电路是什么）
2. `audit/HOGA_Audit_Report.md`（知道 HOGA 怎么审计）
3. `comparison/HOGA_EDF_FHA_Accuracy_Analysis.md`（主结果）
4. `normalized/02`（扫描状态）
5. `normalized/05`（论文文字，注意计数）
6. `aoc/AOC_20point_accuracy_report.md`（充电全过程）

## 没有归档的报告

以下报告与 HOGA 主线相关但未上传，避免把不同主题混在一起：

- `reports/kimi_mode_review_20261024/`：工作模态独立重建（12 联合区间、Cp 分段钳位），与 HOGA 互为交叉验证，但不是 HOGA 模型本身。
- `reports/waveform_modes_20261023/`：旧模态划分，部分结论已被 kimi 审查推翻。
- `MATLAB_PRJ/demo/magnetics_*`：磁件/损耗/硬件，不是 HOGA 精度证据。
- `thesis_*`、`doc/`：学位论文/答辩材料，未逐篇归档。

需要这些材料时，请回原工作区，不要从本仓库推断。
