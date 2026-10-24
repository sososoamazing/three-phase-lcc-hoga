# 数据字典

本目录只保留精选 CSV，完整原始 `.mat` 没有上传。所有 CSV 均为 UTF-8、逗号分隔、首行表头；空值或 `NaN` 表示未计算/不适用，不应擅自补零。

## `data/comparison/` — 20 点四模型比较

| 文件 | 规模 | 内容 |
|---|---|---|
| `point_results.csv` | 80 行（20 点 × 4 方法） | 每条记录的 `model, Vo, fs, Io, Po, Irms, Ipeak, time_s, residual, converged, validity, power_residual, blocked_fraction, state_size, algebraic_unknowns, origin, message` |
| `error_statistics.csv` | 按参考/范围/模型分组 | `Io_MAE_A, Io_NRMSE_1A, Io_max_abs_A, Irms_MAE_A, ... wave_NRMSE_Ibase` |
| `port_metrics.csv` | 80 行 | 分相 RMS/峰值、Cp 峰值、分相输入功率、六个门极边沿电流 |
| `harmonic_convergence.csv` | 28 行（4 电压 × 7 阶数） | `Vo, H, Io_error_A, Irms_max_error_A, peak_max_error_A, wave_NRMSE_Ibase, time_s, residual, kvl_rms_V` |
| `convergence_validation.csv` | 4 行 | 参考精化与 H31 严格验收 |
| `simulink_refinement.csv` | 3 行 | Simulink coarse/fine 与 ODE 对照 |
| `test_results.csv` | 30 项 | 回归测试结果 |
| `open_branch_fix.csv` | 2 行 | 全截止功率诊断修复前后 |
| `efficiency_statistics.csv` | — | 状态规模/计时口径 |
| `matched_benchmark.csv` | — | 400 V 暖启动计时（HOGA/EDF/FHA/ODE） |

关键列：

- `model`：`HOGA` / `EDF` / `FHA` / `REFERENCE`。
- `Io`：平均输出电流（A）；`Po = Vo * Io`（W）。
- `Irms`、`Ipeak`：三相中的最大值（A）；逐相值在 `port_metrics.csv`。
- `blocked_fraction`：整流桥全截止区间占周期比例；`≤1e-5` 视为 CCM。
- `validity`：模型自报的有效性/分支标签，不等于独立验收。
- `power_residual`：功率闭合残差（W）；不同模型的定义见报告。

## `data/normalized/` — 344 点归一化扫描

| 文件 | 规模 | 内容 |
|---|---|---|
| `characteristic_domain.csv` | **344 行** | 唯一坐标的完整记录；绘图唯一数据源 |
| `switching_validation_all.csv` | 18 行 | 18 次开关模型验证总表 |
| `switch_model_anchors.csv` | 9 行 | k=0.5/0.8/1.0 的开关锚点（不是 HOGA 点） |
| `validation_error_summary.csv` | — | 按口径汇总的验证误差 |
| `capacitance_ratio_effect.csv` | — | 六个 k 的 Io/Im/Irms |
| `crossing_brackets.csv` | 3 行 | 550–600 V 交叉的变号区间（未插值） |
| `frequency_capacitance_coverage.csv` | — | (fn,k) 粗网格覆盖 |
| `fn_output_envelope.csv` | — | 每个 fn 的输出包络 |
| `maximum_io_envelope.csv` | — | 每个电压的最大 Io 及对应 fn |
| `pareto_points.csv` | — | 有限采样的 Pareto 点 |
| `matched_requirement_tradeoffs.csv` | — | 输出/应力折中 |
| `recovery_outcome.csv` | 81 行 | 阶段 C 对 81 个未决点的逐点结果（13 通过/68 未决） |
| `phase_B_remaining_outcome.csv` | 41 行 | 阶段 B 剩余点的最终状态 |

`characteristic_domain.csv` 关键列：

- `stage`：A/B/C；
- `Vo_V`, `M`, `fn`, `fs_Hz`, `k_delta`, `k_star`, `Cp_delta_nF`；
- `accepted`, `physical`, `order_pass`：0/1；
- `status`：`ACCEPTED_CCM` / `OPEN_PERIODIC_FAMILY_NOT_REACHABILITY` / `UNRESOLVED`；
- `H`：31 或 63；
- `Io_A`, `Jo`, `Im_A`, `Jm`, `Irms_A`, `Jrms`：输出/应力及归一化值；
- `Im_a_A`, `Im_b_A`, `Im_c_A`, `Irms_a_A`, ...：逐相值；
- `Im1_A`：基波幅值（不是峰值）；
- `Pout_W`, `CCM`, `blocked_fraction`；
- `comm1_A`…`comm6_A`, `minimum_comm_margin_A`, `all_six_polarity`：六次换流电流；
- `zvs_certified`：**全为 0**（没有认证）；
- `event_residual_scaled`, `normal_max_V`, `diode_voltage_violation_V`, `power_residual_relative`, `closure_scaled`：守卫量；
- `elapsed_s`, `attempt_count`, `error`：求解记录。

**重要**：`accepted=1` 只表示本地物理守卫 + 升阶检查通过，不等于独立参考/严格验收。严格验收只有 4 个 H31 点 + H49 AOC 20 点。

## `data/aoc/` — 0→800 V AOC 20 点

| 文件 | 规模 | 内容 |
|---|---|---|
| `accuracy_10points.csv` | 60 行（20 点 × 3 模型） | 逐点 `Io/RMS/Peak/NRMSE` 与误差（文件名保留历史 `10points`） |
| `accuracy_summary.csv` | 3 行 | 三个模型的 MAPE/MAE/NRMSE 汇总 |
| `selected_points.csv` | 20 行 | 20 个点的 `t, Vo, fs, dV/周期` |
| `transient_vs_frozen.csv` | 20 行 | 真实充电周期 vs 冻结波形的 RMS/Io 差异 |
| `aoc_smooth254_59_nodes.csv` | 59 行 | AOC 频率表（Vo、fs、Io、Ipk、Icomm） |

`accuracy_10points.csv` 关键列：

- `index`：P01–P20；
- `Vo`, `fs`：该点电压/频率；
- `model`：`HOGA_H49` / `EDF` / `FHA`；
- `Io_sim`, `Io_model`, `Io_error_A`, `Io_rel_pct`；
- `RMS_sim`, `RMS_model`, `RMS_error_A`, `RMS_rel_pct`；
- `Peak_sim`, `Peak_model`, `Peak_error_A`, `Peak_rel_pct`；
- `NRMSE_pct`；
- `valid`：1/0；
- `blocked_frac_sim`：参考的全截止比例；
- `mode_H49`：HOGA 分支标签；
- `dV_per_period_rel`, `qs_valid`：准静态判据。

## 计数口径

- 归一化：**508 条原始记录 / 344 唯一点 / 276 通过（203 充电 + 73 全阻断）/ 68 未决**。
- 比较：**20 点 × 4 方法 = 80 条**；其中 16 个共同 CCM、4 个非 CCM。
- AOC：**20 点 × 3 模型 = 60 条**。
- 旧报告的 263/190/81 是阶段 C 前口径，不要与 276/203/68 混用。

## 复算示例

```python
import pandas as pd
d = pd.read_csv("data/normalized/characteristic_domain.csv")
print(d.status.value_counts())
print(d[d.accepted == 1].H.value_counts())
```

```python
import pandas as pd
e = pd.read_csv("data/comparison/error_statistics.csv")
print(e[e.scope == "CCM"][["model", "Io_MAE_A", "Irms_MAE_A", "Ipeak_MAE_A"]])
```
