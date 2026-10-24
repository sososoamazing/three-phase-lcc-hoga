# 代码地图与复现边界

## 0. 先读这一句

本目录是**审计代码的公开归档**，不是“一键复现包”。原项目的完整扫描数据（508 个 `.mat`、`validation/` 波形）没有上传；`model_config.m` 里的 `cfg.root` 仍假设原项目目录结构。因此：

- 可以读代码、对照公式、移植函数；
- 不能直接在本仓库从零重跑 20 点/344 点扫描，除非补回原始数据并调整路径；
- 没有在本仓库重新运行 MATLAB/Simulink；所有数值来自原项目已保存结果。

## 1. 目录

```
code/
├─ matlab/
│  ├─ core/          # V2.3 主求解器 + 几何/参数/指标/参考/验收 + legacy 物理
│  ├─ accelerated/   # 向量化 studyHoga.m（与 V2.3 四点等价）
│  ├─ h49/           # H49 固定阶求解 + 十项验收
│  ├─ comparison/    # 统一参数、HOGA/EDF/FHA 接口、峰值/谐波工具
│  ├─ verification/  # 20 点比较、Simulink、回归、加速验证
│  ├─ normalized/    # A/B/C 扫描、精化、恢复、单点求解
│  └─ plotting/      # 论文图、精度图
└─ python/           # 归一化统计、精度复核、来源审计
```

## 2. 关键文件

| 文件 | 作用 |
|---|---|
| `core/lcc3v2Params.m` | 物理参数 + 数值设置（`Nfourier=1536`、`hoga_tol=1e-9` 等） |
| `core/lcc3v2Geometry.m` | `B`、`U`、`C`、六面 `A`、`pairs` |
| `core/lcc3v2Hoga.m` | 事件增强 HOGA 主求解器（V2.3） |
| `core/lcc3v2Discover.m` | 从 legacy 候选提取事件 schedule |
| `core/lcc3v2Metrics.m` | Io/RMS/峰值/功率/二极管诊断 |
| `core/lcc3v2Reference.m` | 独立事件 ODE 参考 |
| `core/lcc3v2Accept.m` | 三层验收（守卫、阶数、参考） |
| `core/lcc3_physics.m` | 门控 Fourier 激励、Δ 子空间、整流可行域 |
| `accelerated/studyHoga.m` | 向量化等价实现；扫描用 |
| `h49/h49Solve.m` | 固定 H49 |
| `h49/h49_accept.m` | H49 十项验收 |
| `comparison/model_config.m` | 统一参数入口（原项目路径假设） |
| `comparison/solve_model.m` | `HOGA/EDF/FHA/REFERENCE` 统一接口 |
| `verification/run_comparison.m` | 20 点四模型比较 |
| `verification/run_final_tests.m` | 30 项回归 |
| `normalized/runNormalizedStudy.m` | A/B 扫描入口 |
| `normalized/runRecoveryStudy.m` | 阶段 C 恢复扫描 |
| `plotting/plotPaperFigures.m` | 归一化论文图 |
| `plotting/plot_accuracy_analysis.m` | 精度报告补图 |

## 3. 环境

- MATLAB R2024b（原项目用 `D:/MATLAB R2024B`；本仓库不绑定路径）。
- Optimization Toolbox（`lsqnonlin`）。
- Simulink + Simscape + Simscape Electrical：仅运行 `models/` 里的 SLX 时需要。
- Python 3.10+：`pandas`、`numpy`、`matplotlib`（原项目用托管 Python；无 scipy 依赖）。

## 4. 调用关系（HOGA 主链）

```
model_config()
  └─ lcc3v2Params()
      └─ lcc3v2Hoga(p, Vo, H, seed)
          ├─ lcc3v2Discover()        % 无 seed 时
          ├─ lcc3v2Geometry()
          ├─ lcc3_physics('fourier_drive', H, U)
          ├─ lsqnonlin(@eventResidual, ...)
          ├─ lcc3v2Metrics()
          └─ lcc3v2FinalizeOpen()    % 全截止分支
              └─ lcc3v2Accept(hoga, refFine, refCoarse, refChange, orderChange, p)
```

`studyHoga.m` 与 `h49Solve.m` 复用同一套 `lcc3v2*` 函数；不要把同名函数同时加入 MATLAB path。原项目用独立目录 + `addpath` 控制。

## 5. 路径设置

```matlab
repo = pwd;  % 仓库根目录
addpath(fullfile(repo,'code','matlab','core'));
addpath(fullfile(repo,'code','matlab','accelerated'));
addpath(fullfile(repo,'code','matlab','h49'));
addpath(fullfile(repo,'code','matlab','comparison'));
addpath(fullfile(repo,'code','matlab','verification'));
addpath(fullfile(repo,'code','matlab','normalized'));
```

注意：

- `model_config.m` 用 `fileparts(mfilename('fullpath'))` 推 `cfg.root`，在原项目里指向 `model_comparison_HOGA_EDF_FHA`；在本仓库里会指向 `code/matlab`，因此 **`cfg.source_slx` 和 `cfg.root/06_reports` 不再成立**。
- 若要复现，建议把本仓库代码复制回原项目对应目录，或手动改 `cfg.root` / `cfg.source_slx`，并补回 `data/`。
- `verification/build_fixed_vo_model.m` 等三个脚本原本依赖本机 MATLAB agentic toolkit；公开版已把私有 `addpath` 注释掉，不能直接用于重建 SLX。

## 6. 代码来源与等价性

| 文件 | 来源 | 验证 |
|---|---|---|
| `core/lcc3v2Hoga.m` | 原 `hoga_audit_v2_20261014/src/core/` | 审计报告；四点 H31 严格验收 |
| `accelerated/studyHoga.m` | 原 `scripts/studyHoga.m` | 与 V2.3 四点等价，电流系数最大差约 4.94e-13 A |
| `h49/h49Solve.m` | 原 `H49_comparison/model/HOGA_H49/` | 20 点 AOC 十项验收 |
| `core/solve_three_phase_lcc_hoga.m` | legacy | 仅历史候选；400 V 法锥失败，不作当前精度 |
| `core/lcc3v2Reference.m` | 原 V2.3 | 独立事件 ODE；与 HOGA 共享物理假设 |

## 7. 不能从代码直接得到的东西

- 508 个原始 `.mat` 波形（`data/A|B|C`）。
- 18 个 `validation/*.mat` 完整波形。
- `runtime/` 的日志、PID、MATLAB prefs。
- 原项目 `06_reports/` 的完整统计中间件（本仓库只保留精选 CSV）。
- 硬件实验、损耗/温升、闭环充电。

## 8. Python 工具

| 文件 | 作用 |
|---|---|
| `python/analyzeNormalizedStudy.py` | 从 A/B/C MAT 重建唯一点、覆盖、Pareto、交叉、误差表 |
| `python/analyze_accuracy_data.py` | 从 80 条记录复算统计 |
| `python/verify_accuracy_analysis.py` | 独立复核报告数字与图 |
| `python/audit_sources.py` | 解析 SLX XML，重建接线/参数审计 |

这些脚本也假设原项目目录结构；在本仓库中只能读逻辑，不能直接跑完整数据链。

## 9. 许可

代码 MIT，见仓库根 `LICENSE`。原项目报告/数据的权利归原作者；本仓库只做公开归档。
