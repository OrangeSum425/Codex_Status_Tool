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

## 执行步骤

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
