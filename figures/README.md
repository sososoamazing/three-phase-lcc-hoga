# 图目录

所有图都来自原项目已保存的 PNG；没有在本仓库重新绘图。图题尽量保留原报告编号，便于回溯。

## `figures/comparison/` — 20 点比较

| 文件 | 图题 | 来源 |
|---|---|---|
| `fig3-1_Io_vs_Vo.png` | 280 kHz 下平均输出电流—输出电压（ODE/HOGA/EDF/FHA） | `05_verification/figures/voltage_Io.png` |
| `fig3-2_Io_error.png` | 输出电流有符号误差（参考 ODE） | `voltage_Io_error.png` |
| `fig_Irms_vs_Vo.png` | 三相 RMS 随输出电压 | `voltage_Irms.png` |
| `fig_Po_vs_Vo.png` | 输出功率随输出电压 | `voltage_Po.png` |
| `fig4-1_wave_A_100V.png` | 100 V/280 kHz 相 A 电流 | `wave_i_A_V100_phase1.png` |
| `fig4-4_wave_A_400V.png` | 400 V/280 kHz 相 A 电流 | `wave_i_A_V400_phase1.png` |
| `fig4-7_wave_A_800V.png` | 800 V/280 kHz 相 A 电流（非 CCM） | `wave_i_A_V800_phase1.png` |
| `fig4-13_spectrum_400V.png` | 400 V 相 A 正阶峰值频谱 | `spectrum_V400.png` |
| `fig5-2_order_error_400V.png` | 400 V 阶数误差 | `hoga_order_error_V400.png` |
| `fig5-7_order_time_400V.png` | 400 V 阶数求解时间 | `hoga_order_time_V400.png` |

## `figures/accuracy/` — 补充误差图

| 文件 | 图题 | 来源 |
|---|---|---|
| `fig3-3_freq_error_100V.png` | 100 V 频率—电流绝对误差 | `accuracy_analysis/figures/frequency_error_V100.png` |
| `fig3-4_freq_error_400V.png` | 400 V 频率—电流绝对误差 | `frequency_error_V400.png` |
| `fig3-5_freq_error_800V.png` | 800 V 频率—电流绝对误差 | `frequency_error_V800.png` |
| `fig4-10_rms_error.png` | 三相 RMS 平均绝对误差 | `voltage_rms_error.png` |
| `fig4-11_peak_error.png` | 三相峰值平均绝对误差 | `voltage_peak_error.png` |
| `fig5-5_order_rms_error.png` | 四工况 RMS 最大误差随 H | `order_rms_error.png` |

## `figures/normalized/` — 344 点归一化扫描

| 文件 | 图题 | 来源 |
|---|---|---|
| `fig01_Io_vs_M_by_fn.png` | k=0.2 下 Io–M 随 fn | `Fig01_Io_vs_Vo_by_fn.png` |
| `fig02_Im_vs_M_by_fn.png` | k=0.2 下 Im–M 随 fn（含全阻断族） | `Fig02_Im_vs_Vo_by_fn.png` |
| `fig03_k_effect.png` | 六个 k 的 Io/Im 对比（fn=1.4） | `Fig03_capacitance_ratio.png` |
| `fig04_Io_operating_map.png` | M–fn 二维 Io 工作域 | `Fig04_Io_operating_map.png` |
| `fig05_Im_stress_map.png` | M–fn 二维 Im 应力图 | `Fig05_Im_stress_map.png` |
| `fig06_Irms_vs_M_by_fn.png` | Irms–M 随 fn | `Fig06_Irms_vs_Vo_by_fn.png` |
| `fig08_crossing_check.png` | 550 V 附近交叉核验 | `Fig08_crossing_check.png` |

原图同时提供 PDF/SVG/600 dpi PNG/FIG；本仓库只保留 PNG，矢量版在原项目 `figures/`。

## `figures/aoc/` — AOC 20 点

| 文件 | 图题 | 来源 |
|---|---|---|
| `fig_aoc1_RMS.png` | 三相平均 RMS 误差沿充电轨迹 | `fig1_RMS_comparison.png` |
| `fig_aoc2_Io.png` | 平均输出电流误差沿充电轨迹 | `fig2_Io_comparison.png` |
| `fig_aoc3_Peak.png` | 三相峰值误差沿充电轨迹 | `fig3_Peak_comparison.png` |
| `fig_aoc4_NRMSE.png` | 波形 NRMSE 沿充电轨迹 | `fig4_NRMSE_comparison.png` |

## 读图注意

- 800 V 的 280 kHz 点是非 CCM；不要把 800 V 所有频点都当 CCM。
- 图中曲线连接只是视觉引导，不表示点间已计算。
- 全阻断族的 `Io=0` 点不能进入对数轴；原图有文字标注。
- 归一化图横轴是 `M = Vo/(nVin)`，不是 `Vo`；`M=4` 对应 800 V。
- `Im` 是三相馈线电流绝对峰值的最大值，不是基波幅值；`Im1_A` 才是基波幅值。
