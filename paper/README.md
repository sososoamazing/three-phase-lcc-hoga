# 论文：High-Order Generalized Averaging（TPEL 2024）

## 文件

- `HOGA_TPEL2024_Li_Wang_Fang_Chen_Yang.pdf`（4.89 MB）
- SHA-256：`569d906f6d1b4d9fcd707e767e20f6ebeda7cd52fc85481226bcc9e802c357bb`

## 引用

```bibtex
@article{Li2025HOGA,
  author  = {Li, Hongchang and Wang, Kangping and Fang, Jingyang and Chen, Wenjie and Yang, Xu},
  title   = {High-Order Generalized Averaging Method for Power Electronics Modeling From {DC} to Above Half the Switching Frequency},
  journal = {IEEE Transactions on Power Electronics},
  year    = {2025},
  volume  = {40},
  number  = {1},
  pages   = {176--194},
  doi     = {10.1109/TPEL.2024.3450712}
}
```

- DOI: [10.1109/TPEL.2024.3450712](https://doi.org/10.1109/TPEL.2024.3450712)
- 出版时间：2025 年 1 月（vol. 40, no. 1）；Online 2024-08-27。

## 许可

PDF 页脚标注：

> This work is licensed under a Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 License. For more information, see https://creativecommons.org/licenses/by-nc-nd/4.0/

因此：

- 本仓库**原样分发、未修改**该 PDF；
- 不得用于商业用途；
- 不得分发修改版；
- 引用/转载请保留作者、标题、出处、DOI 与许可声明。

PDF 同时是“作者接受版”（accepted for publication），与 IEEE 正式排版版本可能有细微差异；正式引用以 DOI 为准。

## 怎么读

1. 先读 [`docs/02_论文精读_HOGA方法.md`](../docs/02_论文精读_HOGA方法.md)，建立“移动 Fourier 系数 → 卷积/Toeplitz → 稳态/小信号 → 开关信号模型”的框架。
2. 再读 PDF 的第 II–IV 节（性质、电路模型、开关信号模型）。
3. 第 V–VII 节是 Boost/Buck/LLC 三个实例；重点看 LLC 的 PFM 处理，但注意它是**单相**。
4. 第 VIII 节结论列出三条假设和“截断误差无定量上界”的局限。

## 与项目的关系

论文提供一般理论；本项目的三相 Δ/Y LCC、共用六管桥、事件增强 HOGA 是独立推导/实现。不要把论文的 Boost/Buck/LLC 公式直接套到本拓扑。详见 [`docs/02`](../docs/02_论文精读_HOGA方法.md) 的 2.7 节映射表。
