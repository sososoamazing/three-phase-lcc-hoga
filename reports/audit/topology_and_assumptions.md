> **归档说明**：本文是原项目报告的公开归档版；数值与结论未改，仅将本机绝对路径替换为占位符、把图片指向本仓库 `reports/accuracy_figures/`。原文中未随包迁移的内部 CSV/目录链接可能失效；可复现数据以 `data/` 与 `docs/08_文件与证据索引.md` 为准。

# 实际拓扑与假设

审计对象：`MATLAB_PRJ/three_phase/simulink/three_phase_LCC.slx`，SHA-256 为 `807db96a073d18972c1fe0242bf7576570b5e862bdfc8a61c8d03aff8e28faa0`。这是清理后实际存在的 50 V→800 V 三相工程。未恢复旧 three_par、LCC_LowPower_Prototype 或500 V研究。

## 接线证据与参数

`audit_sources.py` 重新解析 SLX Connection XML，以并查集合并物理连线，并按真实端口定义将电流传感器 p/n 短接；电流测量信号端不当作电气节点。`data/fresh_topology.json` 保存每个块参数和全部网络。原边三绕组及Cp分别跨接 x→y、y→z、z→x；副边三个负端接同一个浮动中性点，正端接六二极管桥。桥后两个6.25 μF电容串联，等效3.125 μF。中性点不接地，也不接输出电容中点。

| 参数 | 值 | 原SLX来源 |
|---|---:|---|
| Vin | 50 V | InitFcn、Voltage Source |
| fs | 280 kHz | InitFcn、驱动子系统32 |
| Ls | 4.7 μH/馈线 | InitFcn、SID280–282 |
| Cs | 135 nF/馈线 | InitFcn、SID286–288 |
| Cp | 27 nF/Δ边 | InitFcn Cp=0.2Cs、SID289/292/293 |
| Ns/Np | 4 | InitFcn、三个理想变压器参数1/n |
| Rin | 1 mΩ，共用直流母线 | SID270 |
| Vf | 0.6 V/整流二极管 | SID273–278 |
| Co实际等效 | 3.125 μF | SID279/294串联 |

上管门控为 dA=1 (0≤τ<1/2)、dB=1 (0≤τ<1/6 或2/3≤τ<1)、dC=1 (1/3≤τ<5/6)；正相移0/+120/+240°，下管互补。原SLX td、Ron等为eps量级，不是旧单相demo的100 ns死区。对照的共同基准为零死区、理想变压器、固定Vo、Rin和恒定Vf保留，省略器件电容、反恢复、漏感、励磁电感、微小ESR/漏电。Simscape正则化另行记录。

## 状态、参考方向及耦合

令 i 为逆变器流向三条Ls/Cs馈线的电流，vs为沿馈线的串联电容压降；u为Δ原边电压，e=nu为副边相对浮动中性点的电压；j为副边流向整流桥的电流，原边绕组电流为nj。

\[
B=\begin{bmatrix}1&0&-1\\-1&1&0\\0&-1&1\end{bmatrix},\quad
U=\begin{bmatrix}1/\sqrt2&1/\sqrt6\\-1/\sqrt2&1/\sqrt6\\0&-2/\sqrt6\end{bmatrix},\quad C=U^TBU.
\]

完整端口约束：u=Bᵀvx，i=B(nj+Cp·du/dt)，Σi=Σj=Σu=0。定义i=Uq，vs=Us+b1，e=Ur，j=Uw；b为守恒公共偏置，选b=0。六个独立差模状态为x=[qα,qβ,sα,sβ,rα,rβ]。

\[
L_s\dot q=V_{in}p-R_{in}pp^Tq-s-Cr/(3n),\quad C_s\dot s=q,
\quad (C_p/n^2)\dot r=C^Tq/(3n)-w,\quad p=U^Td.
\]

公共电阻项ppᵀ包含跨相耦合；Δ/Y的C矩阵不能删除。平衡星等效电容为3Cp，而不是Cp。不得将一个独立单相结果乘3或额外乘√3变比。

## 必须保留的整流非线性

Vd=Vo+2Vf，A的六行是Ua−Ub (a≠b)。可行域Ar≤Vd1是六边形。二极管电流w属于该域在r处的法锥，等价于六只二极管各自非负电流、非负反压间隙及互补乘积为零。允许全截止、两管、三管导通；浮动中性点由导通条件决定，全截止时其绝对电位可不唯一。真实输出电流为所有上管电流之和，满足约束后才等于Σ|j|/2。

瞬时能量恒等式：W=Ls‖q‖²/2+Cs‖s‖²/2+Cp‖r‖²/(2n²)，dW/dt=Vin·idc−Rin·idc²−eᵀj。周期稳态平均输入功率=Vo·Io+2Vf·Io+Rin·mean(idc²)。

CCM定义为整流器无有限时间全截止区间，不以谐振电流过零分类。100 V有三管重叠，400/700 V为连续两管主导，800 V存在全截止区间，不能把800 V点冒写成目标CCM。所有固定Vo结果仅为准静态端口特性，不能证明真实3.125 μF充电瞬态、停充、ZVS、磁件损耗或硬件性能。

来源：原SLX、本次XML审计、保留的V2.3源码及其六维方程；数学关系由本次独立功率/能量测试复核。与旧单相200 kHz、30 μH demo严格分开。
