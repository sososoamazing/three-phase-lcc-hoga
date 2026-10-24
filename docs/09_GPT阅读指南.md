# 09 GPT 网页端阅读指南

> 目标：让 ChatGPT / 其他网页端模型**不下载附件**也能读到本项目的具体内容，并能引用到文件与章节。

## 9.1 推荐入口（按可读性排序）

| 入口 | URL | 适合 |
|---|---|---|
| GitHub Pages 单页 | https://sososoamazing.github.io/three-phase-lcc-hoga/ | 一次抓取全部核心内容；表格/图/结论都在同一页 |
| 仓库首页 | https://github.com/sososoamazing/three-phase-lcc-hoga | 浏览目录、点开 Markdown |
| 一页式 Markdown | https://github.com/sososoamazing/three-phase-lcc-hoga/blob/main/ONE_PAGE.md | GitHub 渲染 Markdown，适合逐段引用 |
| 一页式 raw | https://raw.githubusercontent.com/sososoamazing/three-phase-lcc-hoga/main/ONE_PAGE.md | 纯文本，最容易被爬虫/模型读取 |
| 项目总览 | https://github.com/sososoamazing/three-phase-lcc-hoga/blob/main/docs/00_项目梳理总览.md | 想看“整个项目怎么梳理”的 |
| 论文笔记 | https://github.com/sososoamazing/three-phase-lcc-hoga/blob/main/docs/02_论文精读_HOGA方法.md | 想看论文方法与本项目映射的 |
| 实现细节 | https://github.com/sososoamazing/three-phase-lcc-hoga/blob/main/docs/03_三相LCC_HOGA实现.md | 想看未知量/残差/守卫的 |
| 结果 | https://github.com/sososoamazing/three-phase-lcc-hoga/blob/main/docs/04_模型对比结果.md | 想看 20 点精度表的 |
| 局限 | https://github.com/sososoamazing/three-phase-lcc-hoga/blob/main/docs/07_局限与证据等级.md | 想避免误引结论的 |
| 论文 PDF | https://github.com/sososoamazing/three-phase-lcc-hoga/blob/main/paper/HOGA_TPEL2024_Li_Wang_Fang_Chen_Yang.pdf | 需要原文；网页端不一定能解析 PDF |

> 如果 ChatGPT 只愿意读一个链接：给它 **GitHub Pages 首页**；如果它说“打不开/只看到目录”，给它 **`ONE_PAGE.md` 的 raw 链接**。

## 9.2 直接粘贴的提示词（中文）

```text
你在阅读一个公开的三相 LCC 谐振电容充电电源（50 V→800 V）HOGA 建模资料库：
https://sososoamazing.github.io/three-phase-lcc-hoga/

请先完整读取该页面，然后回答：
1. 这个项目的三相 LCC 拓扑和关键参数是什么？
2. 论文的 HOGA 方法与本项目的“事件增强 HOGA”是什么关系？哪些是论文的、哪些是项目自己的？
3. HOGA 在 20 点比较中的精度如何？请给出 HOGA/EDF/FHA 的 Io、RMS、峰值、波形误差，并说明参考是什么。
4. 344 点归一化扫描的通过/未决计数是多少？为什么不能把未决说成“无解”？
5. 列出至少 5 条不能声称的结论（红线）。

要求：
- 每个数值都注明来自哪个文件/章节；
- 区分“独立事件 ODE 参考”“Simulink 验证”“HOGA 自身验收”三种证据；
- 如果页面上没有的信息，明确说“资料库未给出”，不要猜。
```

## 9.3 直接粘贴的提示词（英文）

```text
Read the public repository for a three-phase LCC resonant capacitor charger (50 V → 800 V) with HOGA modeling:
https://sososoamazing.github.io/three-phase-lcc-hoga/

Then answer:
1. What is the topology and the key parameters?
2. How does the TPEL 2024 HOGA paper relate to the project's event-enriched HOGA? Which parts are from the paper and which are project-specific?
3. Report the 20-point accuracy of HOGA vs EDF vs FHA (Io, RMS, peak, waveform NRMSE), and state what the reference is.
4. What are the accepted/unresolved counts in the 344-point normalized scan? Why can't "unresolved" be called "no solution"?
5. List at least five claims that must NOT be made.

Requirements: cite the file/section for every number; distinguish independent event-ODE reference, Simulink validation, and HOGA self-acceptance; say "not provided" instead of guessing.
```

## 9.4 按主题追问的短提示词

| 你想问 | 用这个链接 + 提示 |
|---|---|
| 论文方法 | `docs/02...`：“请用 5 段概括论文第 II–IV 节，并指出它没有覆盖三相 LCC 的哪些部分。” |
| 代码实现 | `docs/03...`：“请解释事件残差的三部分，以及为什么非线性未知量只有 2+Ne 个。” |
| 20 点结果 | `docs/04...`：“请把 16 个 CCM 点的 HOGA/EDF/FHA 指标列成表，并指出两个反例。” |
| 归一化扫描 | `docs/05...`：“请解释为什么 fn=1.5 能覆盖 800 V，而 fn=1.0 不能；区分数值奇异与物理边界。” |
| AOC | `docs/06...`：“请解释 17.4 V 与 79.8 V 为什么不能计入准静态精度统计。” |
| 防误引 | `docs/07...`：“请列出 12 条红线，并给每条配一个反例。” |
| 数据字典 | `data/README.md`：“请解释 point_results.csv 的每一列。” |
| 复现 | `code/README.md`：“请给出从零复现 20 点比较的步骤，并指出哪些数据仓库没有。” |

## 9.5 ChatGPT 网页端可能遇到的限制

1. **PDF 解析不稳定**：GitHub 的 PDF 预览有时只显示下载按钮。需要原文时，让模型读 `docs/02` 的笔记，或直接给它 DOI 链接。
2. **GitHub 的 Markdown 渲染**：表格和代码块通常可读；LaTeX 公式在 GitHub 上支持，但不同客户端渲染不一致。本仓库尽量用代码块写关键公式，减少公式渲染依赖。
3. **单页太大**：`index.html` 约 20–30 KB 文本，一般可一次读完；如果模型截断，让它分段读 `docs/00`–`docs/07`。
4. **图片**：网页端模型通常不读图；本仓库的结论都在文字/表格里，图片只作辅助。
5. **私有内容**：本仓库是公开版，不含原始 `.mat`、`runtime/`、硬件实验；不要向模型索取这些。

## 9.6 引用格式

如果模型要引用本仓库：

```text
Three-Phase LCC HOGA Modeling Archive (2026).
GitHub: https://github.com/sososoamazing/three-phase-lcc-hoga
Pages: https://sososoamazing.github.io/three-phase-lcc-hoga/
```

如果引用论文：

```text
H. Li, K. Wang, J. Fang, W. Chen, and X. Yang,
“High-Order Generalized Averaging Method for Power Electronics Modeling
From DC to Above Half the Switching Frequency,”
IEEE Trans. Power Electron., vol. 40, no. 1, pp. 176–194, 2025.
DOI: 10.1109/TPEL.2024.3450712
```

## 9.7 给模型的一句“防幻觉”声明

```text
本资料库中的“未决”不等于“无解”，“全阻断族”不等于“实际充电可达”，
“换流电流为正”不等于“ZVS”，“HOGA 与参考一致”不等于“物理精度”。
如果资料没有给出某个数，请说“未给出”，不要用文献值或常识补全。
```

## 9.8 维护说明

- 如果仓库改名/迁移，请同步更新本页、`README.md`、`llms.txt`、`CITATION.cff`。
- 如果新增文档，请加入 `llms.txt` 与 `docs/08_文件与证据索引.md`。
- 如果发现计数冲突，以 `data/normalized/characteristic_domain.csv` 与 `reports/normalized/02_扫描与求解状态.md` 为准。
