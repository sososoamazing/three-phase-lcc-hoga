# 模型文件

本目录保存 5 个 SLX。它们是二进制文件，GitHub 不能预览；请用 MATLAB R2024b + Simulink/Simscape Electrical 打开。

| 文件 | SHA-256 | 大小 | 用途 |
|---|---|---:|---|
| `three_phase_LCC.slx` | `807db96a073d18972c1fe0242bf7576570b5e862bdfc8a61c8d03aff8e28faa0` | 543,955 | 主电路源模型（审计基准） |
| `ideal_three_phase_LCC.slx` | `70f0cdba4bc21c6e2c8b8722ee0408d7214c54cbcae104e3cb6cbddbcec8e1cc` | 559,398 | 近理想副本；**二极管 `Vf=eps`，与 0.6 V 数学基准不同** |
| `lcc3_comparison.slx` | `8491e14f7397fabbe370a0127b23c74e5ca228fa6986f8baefdf8d8dbbffa4c23` | 580,624 | 冻结输出电压的 Simulink 比较模型（Co 换成两个 `Vo/2` 电压源） |
| `AOC_charge.slx` | `2f510c31c6ba1e55a59bf2d20da7733c0b3c74161c2c06ff9f577ca3c3a9c937` | 577,336 | AOC 0→800 V 充电模型 |
| `lcc3_frozen_aoc.slx` | `8491e14f7397fabbe370a0127b23c74e5ca228fa6986f8baefdf8d8dbbffa4c23` | 580,624 | AOC 冻结点模型；与 `lcc3_comparison.slx` **字节相同**（同哈希） |

## 打开前

1. 确认 MATLAB R2024b、Simulink、Simscape、Simscape Electrical 已安装。
2. 不要直接改原模型；原项目约定“先复制到 `work/` 再改，`close_system(mdl,0)` 不保存”。
3. `ideal_three_phase_LCC.slx` 的 `Vf=eps` 与比较基准 0.6 V 不同；不要把旧三点结果归到它。
4. `lcc3_comparison.slx` 的输出电容已被两个 `Vo/2` 理想电压源替代，只用于冻结 `Vo` 的周期稳态；不是真实 3.125 μF 充电。
5. `AOC_charge.slx` 是 AOC 充电模型；`lcc3_frozen_aoc.slx` 是逐点冻结参考模型。
6. 本仓库没有 `slprj/`、`slxc` 缓存；首次打开/仿真会重新生成，属正常现象。

## 模型与证据的关系

- 20 点比较的 **主参考是独立事件 ODE**，不是 Simulink；Simulink 只做 3 点交叉验证。
- AOC 20 点的参考是 `lcc3_frozen_aoc.slx`（冻结 `Vo`、24 周期、末周期 8192 点）。
- 18 次开关验证用 `three_phase_LCC.slx` 的近冻结副本（`output_Co_scale=10000`），不是直接改原模型。
- 模型不能替代报告中的数值；打开模型前先读 `docs/01`、`docs/03`、`docs/04`。

## 校验

```powershell
Get-FileHash models\three_phase_LCC.slx -Algorithm SHA256
```

应与上表一致。完整清单见仓库根 `SHA256SUMS.txt`。
