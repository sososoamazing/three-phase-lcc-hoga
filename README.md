# Three-Phase LCC Capacitor Charger — HOGA Modeling Archive

**50 V → 800 V 三相 Δ/Y LCC 谐振电容充电电源的 HOGA（高阶广义平均）建模公开资料库。**

本仓库梳理了原项目中的三相 LCC HOGA 资产：理论来源（TPEL 2024 论文）、事件增强 HOGA 实现、20 点四模型精度比较、344 点归一化特性扫描、AOC 0→800 V 充电轨迹验证，以及对应的数据、图和可复现说明。

> 这不是完整项目镜像，也不是硬件实验报告。原始 508 个 `.mat` 波形、`runtime/` 缓存、内部协作记录没有上传。所有“未决/全阻断/ZVS/损耗”边界见 [`docs/07_局限与证据等级.md`](docs/07_局限与证据等级.md)。

---

## 快速入口

| 入口 | 适合 |
|---|---|
| **[一页式总览 ONE_PAGE.md](ONE_PAGE.md)** | 想一次看懂全部关键结论 |
| **[项目梳理总览](docs/00_项目梳理总览.md)** | 想看“整个项目怎么梳理”的 |
| **[论文精读](docs/02_论文精读_HOGA方法.md)** | 想看 TPEL 2024 论文与本项目的关系 |
| **[实现细节](docs/03_三相LCC_HOGA实现.md)** | 想看事件增强 HOGA 的未知量/残差/守卫 |
| **[20 点结果](docs/04_模型对比结果.md)** | 想看 HOGA/EDF/FHA 精度表 |
| **[344 点扫描](docs/05_归一化特性扫描.md)** | 想看 fn/k 工作域 |
| **[AOC 充电轨迹](docs/06_充电轨迹_AOC.md)** | 想看 0→800 V 全过程精度 |
| **[GPT 阅读指南](docs/09_GPT阅读指南.md)** | 想让 ChatGPT 网页端读取/提问 |
| **[论文 PDF](paper/HOGA_TPEL2024_Li_Wang_Fang_Chen_Yang.pdf)** | 需要原文 |

网页版（GitHub Pages）：**https://sososoamazing.github.io/three-phase-lcc-hoga/**

---

## 30 秒结论

| 问题 | 结论 |
|---|---|
| HOGA 比 EDF/FHA 准吗？ | 在本电路、本参数、20 点内整体明显更准；有逐点反例 |
| 16 个共同 CCM 点的 `Io MAE` | **HOGA 15.579 μA** / EDF 4.284 mA / FHA 90.874 mA |
| 波形 NRMSE | **HOGA 0.0566%** / EDF 1.906% / FHA 22.208% |
| AOC 20 点 `Io` MAPE | **HOGA-H49 0.00566%**（20/20 有效） |
| 344 点扫描 | **276 通过 / 203 充电 / 73 全阻断 / 68 未决** |
| 证据等级 | 独立事件 ODE + 3 点 Simulink；**没有硬件实验** |

---

## 研究对象

```
Vin(50 V) → 三相三桥臂（120°）→ 每相 Ls 4.7 μH / Cs 135 nF
→ Δ 接 Cp 27 nF/边 + 三台 1:4 变压器（一次 Δ / 二次 Y 浮空）
→ 共用六二极管桥 → Co 6.25 μF × 2 串联 = 3.125 μF → Vo 0–800 V
```

| 量 | 值 |
|---|---:|
| `Vin` | 50 V |
| `Ls` / `Cs` | 4.7 μH / 135 nF（每馈线） |
| `Cp_delta` | 27 nF / Δ 边 |
| `n = Ns/Np` | 4 |
| `fs` | 280 kHz（基准） |
| `fr` / `Z0` | 199.804 kHz / 5.9004 Ω |
| `Vf` | 0.6 V/二极管 |
| `Co` | 3.125 μF |

参数与易错点见 [`docs/01_拓扑与参数.md`](docs/01_拓扑与参数.md)。

---

## 仓库结构

```
.
├─ ONE_PAGE.md                 # 一页式总览（LLM 友好）
├─ index.html                  # GitHub Pages 单页
├─ llms.txt                    # 给 LLM/爬虫的 URL 索引
├─ docs/                       # 00–09 深度文档
├─ paper/                      # TPEL 2024 论文 PDF + 引用/许可
├─ reports/                    # 原项目报告归档（已清洗路径）
├─ data/                       # 精选 CSV（comparison / normalized / aoc）
├─ figures/                    # 精选图
├─ code/                       # HOGA/EDF/FHA/验证代码
├─ models/                     # 关键 SLX 模型
├─ tools/                      # 站点构建 + 仓库校验
├─ SHA256SUMS.txt              # 文件哈希
├─ CITATION.cff
├─ LICENSE                     # 代码 MIT
└─ LICENSE_DOCS.md             # 原创文档 CC BY 4.0
```

完整文件映射见 [`docs/08_文件与证据索引.md`](docs/08_文件与证据索引.md)。

---

## 论文

**H. Li, K. Wang, J. Fang, W. Chen, X. Yang**, “High-Order Generalized Averaging Method for Power Electronics Modeling From DC to Above Half the Switching Frequency,” *IEEE Transactions on Power Electronics*, vol. 40, no. 1, pp. 176–194, Jan. 2025.

- DOI: [10.1109/TPEL.2024.3450712](https://doi.org/10.1109/TPEL.2024.3450712)
- 本仓库 PDF：`paper/HOGA_TPEL2024_Li_Wang_Fang_Chen_Yang.pdf`
- 许可：论文页脚标注 **CC BY-NC-ND 4.0**；PDF 原样分发，不改动。
- 方法笔记：`docs/02_论文精读_HOGA方法.md`

---

## 如何阅读（人类 / GPT）

### 人类

1. [`ONE_PAGE.md`](ONE_PAGE.md)（10 分钟）
2. [`docs/00_项目梳理总览.md`](docs/00_项目梳理总览.md)（20 分钟）
3. [`docs/04_模型对比结果.md`](docs/04_模型对比结果.md) + [`docs/05_归一化特性扫描.md`](docs/05_归一化特性扫描.md)（40 分钟）
4. 需要细节时再看 `reports/` 与 `data/`。

### ChatGPT 网页端

- 直接给它 **GitHub Pages**：https://sososoamazing.github.io/three-phase-lcc-hoga/
- 如果它只看到目录，给它 **raw ONE_PAGE**：
  `https://raw.githubusercontent.com/sososoamazing/three-phase-lcc-hoga/main/ONE_PAGE.md`
- 现成提示词见 [`docs/09_GPT阅读指南.md`](docs/09_GPT阅读指南.md)。

---

## 复现

本仓库保留了核心 MATLAB 代码和精选 CSV，但没有完整原始 `.mat`。因此：

- **能做的**：读代码、对照公式、用 CSV 复算统计、用 `tools/build_site.py` 重建站点。
- **不能直接做的**：从零重跑 20 点/344 点扫描（需要原工作区的 `data/A|B|C` 与 `validation/` 原始 MAT）。

```matlab
% 代码路径（示例）
addpath('code/matlab/core');
addpath('code/matlab/accelerated');
addpath('code/matlab/comparison');
```

```text
python tools/build_site.py     # 重建 index.html
python tools/verify_package.py # 校验链接与 SHA256SUMS
```

详见 [`code/README.md`](code/README.md)、[`reports/README.md`](reports/README.md)。

---

## 边界（必读）

- 这是**冻结周期稳态**比较，不是连续充电动态；AOC 是逐点冻结的准静态验证。
- 68 个未决点不能写成“物理无解”；`k=0.5` 的 9 点已被开关模型证明存在导通解。
- 全阻断族不是“实际充电可达”；换流电流为正不是“ZVS”。
- 20 点里只有 3 点有 Simulink 对照；其余是独立事件 ODE。
- HOGA 的 0.004% 已接近参考数值平台（15 μA / 0.2 mA），不是物理精度。
- 没有硬件实验、损耗/温升、闭环充电、器件级 ZVS、磁件验证。

完整红线见 [`docs/07_局限与证据等级.md`](docs/07_局限与证据等级.md)。

---

## 许可

- 代码：MIT，见 [`LICENSE`](LICENSE)。
- 本仓库原创文档/图/表：CC BY 4.0，见 [`LICENSE_DOCS.md`](LICENSE_DOCS.md)。
- 论文 PDF：CC BY-NC-ND 4.0，版权归作者/IEEE；见 [`paper/README.md`](paper/README.md)。
- 原项目报告/数据：按原项目约定；本仓库只做公开归档，不改变原作者权利。

---

## 引用

```bibtex
@misc{LCC3HOGA2026,
  title  = {Three-Phase LCC Capacitor Charger: HOGA Modeling Archive},
  year   = {2026},
  note   = {GitHub repository},
  url    = {https://github.com/sososoamazing/three-phase-lcc-hoga}
}
```

论文引用见 [`CITATION.cff`](CITATION.cff) 与 [`docs/02_论文精读_HOGA方法.md`](docs/02_论文精读_HOGA方法.md)。
