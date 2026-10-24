> **归档说明**：本文是原项目报告的公开归档版；数值与结论未改，仅将本机绝对路径替换为占位符、把图片指向本仓库 `reports/accuracy_figures/`。原文中未随包迁移的内部 CSV/目录链接可能失效；可复现数据以 `data/` 与 `docs/08_文件与证据索引.md` 为准。

# HOGA修复记录

## F01：跨周期重构错误（Major）

文件：`02_HOGA/original_snapshot/lcc3v2Evaluate.m`。原函数允许任意非负tau，但分段电压积分与模式选择仅覆盖[0,1]；电流和Cs由Fourier式自动周期延拓，副边电压却在tau>1后停在周期末，整流电流变成零。这会污染多周期波形、FFT及统一窗口比较，单周期求解器不受影响。

可复现证据：`00_audit/data/stage1_run02/periodic_reconstruction_bug.json`，400 V、H31，在0.123T和1.123T处副边二维电压差[44.0193,−175.7688] V、整流二维电流差[1.32332,0] A。

修复：仅在新目录 `02_HOGA/validated_model/lcc3v2Evaluate.m` 将tau>1映射到mod(tau,1)；保留原[0,1]端点，避免把独立周期残差强制变零。核心HOGA方程、参数、守卫与求根均未修改。

验证：`00_audit/data/fix_validation.json`、`fixed_tests.csv`；新增第二周期、数组多周期、保留端点三项回归，连同17项既有测试均通过。原始源码和模型哈希保留。

## 已有版本中的历史问题

legacy有限带宽整流电流模型存在弱谱残差很小但逐点互补和功率不闭合的截断误差；其守卫本身会拒绝这些解。当前V2.3已用事件积分表示保留钳位，不能把已有修复写成本次发明。本次按同工况重算legacy与V2.3，详见审计报告。

## 本次工程脚本修正

- stage1首行struct2table需要AsArray=true；首次失败日志保留，成功数据另存stage1_run02。
- XML拓扑审计按实际Simscape端口将Current Sensor的lconn1/rconn2并为电气节点，rconn1是信号输出。重新执行接线检查通过。
- MATLAB MCP无法附着；本机R2024b沙箱内settings插件失败，按已获批准的独立批处理运行。没有替换工程环境。

## F05：全截止分支功率重采样与守卫不一致（Major）

位置：validated_model/lcc3v2Hoga.m的allBlockedResult；同源加速内核studyHoga同样适用。原分支先复制legacy候选和守卫，再用偏移均匀网格重算指标，但没有重判功率。800 V/240、260 kHz的原功率偏差为0.02308724/0.03230640 W，relative=0.91676/0.88771，却仍返回PASS。

修复复用原工程20261020脚本integrateHogaInput，逐六个门极区间解析积分有限Fourier电流的输入功率及Rin损耗。新增lcc3v2FinalizeOpen只在全截止代表解分支触发，保存before_open_metric_fix，更新功率后重算守卫。原模型和求得的谐波系数、状态、Io没有变化。历史MAT不覆盖，后处理适配器对这些系数执行相同诊断更新，见06_reports/Open_Branch_Fix.csv。

结果：两点新功率残差约−1.26e−13和−5.96e−13 W。新增3项测试验证独立quadgk积分、原系数不变和改变物理电流后必须拒绝。加上原测试、F01及EDF/FHA测试，总30项通过。此修复是将项目近期已有的精确积分用到所审计的基础版本，不是新增物理公式。

## 数值搜索、加速与可复现构建

原版系数装配的profile保留；项目已有studyHoga四点等价检查最大电流系数差约4.94e−13 A。同初值400 V暖启动快约10.98倍。它单独保存在accelerated，不用作EDF或FHA实现。

原扫描保留两条失败候选和一次人工结束的长时间尝试。300 V/280 kHz通过HOGA邻点延续恢复；800 V/320 kHz原候选有−0.141 A负二极管反作用，沿用V2.3已有release策略恢复。没有降低守卫阈值，没有把独立ODE事件作为HOGA初值。

固定Vo模型构建已合并为可重复执行脚本，并在新模型lcc3_comparison_rebuild_check从头重建通过。旧端口修复/电压日志脚本作为过程证据保留；正常入口为build_fixed_vo_model。EDF嵌套循环变量改名避免共享变量告警，不改变公式或已生成的数值。
