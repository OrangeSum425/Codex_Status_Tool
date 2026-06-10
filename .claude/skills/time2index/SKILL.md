---
name: time2index
description: Run the JUNO time2index event-list workflow on the IHEP lxlogin cluster. Use this skill whenever the user asks to "执行 time2index", "跑 time2index", "run time2index", "提交 time2index", submit time2index jobs, or regenerate the time2index JSON / timestamp event lists. It edits env.sh, sources the environment, and submits the time2index batch jobs.
---

# time2index 工作流 (JUNO @ IHEP lxlogin)

这个 skill 把在 IHEP `lxlogin` 上运行 time2index 的标准流程固化下来。它必须在能访问
`/scratchfs/juno/...` 的环境（即 IHEP lxlogin）里运行——本地/远程沙箱无法访问该路径。

## 关键文件

`/scratchfs/juno/yaoqicao/Event_List/DSNB/env.sh`，标准内容如下：

```bash
export TIME2INDEX_TIMESTAMPS_BASE_DIR=/scratchfs/juno/yaoqicao/Event_List/DSNB/timestamp
export TIME2INDEX_OUTPUT_DIR=/scratchfs/juno/yaoqicao/Event_List/DSNB/time2index_json
export TIME2INDEX_EDM_LIST=/scratchfs/juno/yaoqicao/Event_List/DSNB/rtraw_list

cd /scratchfs/juno/yaoqicao/GenCalibPDF/gen-calib-pdf
source setup.sh

cd share/time2index
export TIME2INDEX_RUNTIME_SETUP=0
source setup.sh

export TIME2INDEX_WORKER_RUNTIME_SETUP=1
```

一般情况下，**只有前两行的两个路径需要改动**：
- `TIME2INDEX_TIMESTAMPS_BASE_DIR` — 输入 timestamp 目录
- `TIME2INDEX_OUTPUT_DIR` — 输出 time2index_json 目录

`TIME2INDEX_EDM_LIST` 和其余行通常保持不变（除非用户明确要求修改）。

## 完整流程概览

1. **步骤 0（数据准备）**：把一个汇总 csv/txt 按 run 切成一个个可读的 per-run timestamp
   txt 文件 → 这些文件就是 time2index 的输入（即 `TIME2INDEX_TIMESTAMPS_BASE_DIR` 指向的目录）。
2. **步骤 1–5（提交 time2index）**：改 env.sh、source、提交作业。

如果用户只说"执行 time2index"且 timestamp 文件已经切好，可以直接从步骤 1 开始；
如果用户要从头跑（包括切分），先做步骤 0。拿不准时问一句。

## 步骤 0：切分 per-run timestamp 文件

参考脚本：
`/scratchfs/juno/yaoqicao/GenCalibPDF/gen-calib-pdf/share/time2index/split_run_timestamps.py`

**先读这个脚本**确认它的命令行参数（输入文件、输出目录、列名等）——不要凭记忆假设参数。

### 输入数据来源（csv）

`/lustrefs/juno26/users/yaoqicao/ReProd26B_Selection/Dataset/ibd_summary_by_phase/merged/`
目录下，**文件名在 12–100 区间、且名字里带 `multi` 的那个 csv**。

用之前**先看 header**（`head -1` 或读前几行）确认列名，再据此设置 split_run_timestamps.py
的列参数。**列名/格式未经确认前不要硬编码。**

（历史上还有一个 txt 来源 `selected_data_info_E12_30.txt`，现已弃用，不要再用。）

### 操作

1. 在 lxlogin 上 `head -1` 看上面那个 csv 的 header，确认列名。
2. 读 `split_run_timestamps.py`，按其参数把该 csv 切成 per-run txt，
   输出目录应与步骤 1 里要填的 `TIME2INDEX_TIMESTAMPS_BASE_DIR` 一致。
3. 抽查输出：切出了多少个 run 文件、抽一个文件看格式是否正确，再进入步骤 1。

## 执行步骤（提交 time2index）

### 1. 必须先询问两个路径

每次执行前，**始终**用 `AskUserQuestion` 询问用户这两个地址要改成什么。不要自己猜，也不要
沿用上次的值——这是用户的硬性要求。问清楚：

- `TIME2INDEX_TIMESTAMPS_BASE_DIR` 改成什么？
- `TIME2INDEX_OUTPUT_DIR` 改成什么？

在选项里把当前 env.sh 里的现值作为「保持不变」选项列出来，方便用户只改一个。
如果用户在请求里已经明确给出了这两个路径，可以跳过提问直接用，但要在回复里复述一遍确认。

### 2. 更新 env.sh

读取 `/scratchfs/juno/yaoqicao/Event_List/DSNB/env.sh`，只替换那两行 `export`，其它行原样保留。
改完后把改动后的两行回显给用户确认。

### 3. source 环境

```bash
source /scratchfs/juno/yaoqicao/Event_List/DSNB/env.sh
```

注意 env.sh 里有 `cd`，所以 source 之后工作目录会变到 `share/time2index`，这是预期行为。

### 4. 提交作业

```bash
bash /scratchfs/juno/yaoqicao/GenCalibPDF/gen-calib-pdf/share/time2index/submit/submit_time2index.sh --runs-per-job 5
```

`--runs-per-job` 默认为 5；如果用户指定了不同的值，用用户给的值。

### 5. 汇报结果

把提交脚本的输出（提交了多少作业、job id、有没有报错）如实回报给用户。如果脚本报错，
原样贴出错误，不要隐藏。

## 注意事项

- 这一切发生在 IHEP lxlogin。如果当前环境访问不到 `/scratchfs/juno/...`，先告诉用户需要在
  lxlogin 上运行，不要假装成功。
- 只改用户要求改的东西。除非明确要求，否则不要动 `TIME2INDEX_EDM_LIST`、`source setup.sh`
  或那两个 `RUNTIME_SETUP` 变量。
- 步骤 0 的 csv 来源会随项目演进变化：每次跑都重新确认目标 csv 的真实 header，
  不要沿用本文里记的旧路径/旧列名当成事实。
