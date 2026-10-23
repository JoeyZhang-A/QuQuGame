# 03 · 数据格式

三份数据：配置（读）、对局日志（写）、统计汇总（写）。

配置用 JSON，日志用 JSONL（一行一条，追加写），统计用 CSV（方便 Excel 看）。

## 1. 配置文件

放在 `res://data/`，运行时全部加载，不硬编码在脚本里。

### 1.1 `crickets.json`

```json
{
  "version": 1,
  "crickets": [
    { "id": "scale",  "name": "老秤砣", "A": 0.20, "R": 0.15, "E": 0.90, "S": -0.90, "P": 0.25 },
    { "id": "rush",   "name": "急先锋", "A": 0.75, "R": 0.60, "E": 0.20, "S":  0.40, "P": 0.85 },
    { "id": "abacus", "name": "算盘精", "A": 0.40, "R": 0.90, "E": 0.45, "S":  0.00, "P": 0.40 },
    { "id": "stew",   "name": "闷葫芦", "A": 0.35, "R": 0.10, "E": 0.75, "S": -0.20, "P": 0.05 },
    { "id": "fool",   "name": "愣头青", "A": 0.85, "R": 0.15, "E": 0.10, "S":  0.90, "P": 0.30 }
  ]
}
```

校验：`A R E P` 在 0..1，`S` 在 -1..1，`id` 唯一。不合法直接报错退出，不要静默钳制。

`name` 只给测试用，**游戏画面里不显示蛐蛐名字**（名字会泄题，让人从名字推性格）。

### 1.2 `actions.json`

```json
{
  "version": 1,
  "tick_ms": 450,
  "max_tick": 133,
  "grid": { "w": 5, "h": 3 },
  "center": [2, 1],
  "actions": {
    "hold":     { "windup": 0,   "active": 380, "recover": 70,  "move": [0, 0],  "stamina": 2,  "pressure": -8 },
    "retreat":  { "windup": 100, "active": 250, "recover": 100, "move": "away", "stamina": 4,  "pressure": -6 },
    "approach": { "windup": 180, "active": 220, "recover": 50,  "move": "near", "stamina": -3, "pressure": 4  },
    "flank":    { "windup": 240, "active": 160, "recover": 50,  "move": "side", "stamina": -5, "pressure": 2  },
    "bite":     { "windup": 280, "active": 120, "recover": 50,  "move": [0, 0],  "stamina": -8, "pressure": 0  }
  },
  "grapple": {
    "suppress_att": -6,  "suppress_def": -18,
    "counter_att": -14,  "counter_def": -4,
    "even_att": -8,      "even_def": -8,
    "suppress_pressure_att": 8,  "suppress_pressure_def": 25,
    "counter_pressure_att": 18,  "counter_pressure_def": 6,
    "even_pressure": 10,
    "win_ratio": 1.15, "lose_ratio": 0.87
  },
  "thresholds": { "low_stamina": 30, "stress": 60, "panic": 85, "flee_stamina": 20 },
  "scoring": { "center_bonus": 15, "flee_consecutive": 2 }
}
```

`move` 的三种字符串值是语义标记，由代码解析成具体坐标；`[x,y]` 是显式偏移。

阶段时长校验：`windup + active + recover == tick_ms`，加载时断言。

### 1.3 `weights.json`

```json
{
  "version": 1,
  "base":     { "hold": 200, "retreat": 150, "approach": 200, "flank": 200, "bite": 100 },
  "feature": {
    "hold":     { "near": 250,  "far": 100,  "face": 0,    "sta": 200,  "pre": -250, "sup": -150, "sdn": 200 },
    "retreat":  { "near": -300, "far": 100,  "face": 0,    "sta": -600, "pre": 0,    "sup": -200, "sdn": 350 },
    "approach": { "near": -250, "far": 500,  "face": 0,    "sta": 0,    "pre": 0,    "sup": 100,  "sdn": -150 },
    "flank":    { "near": 150,  "far": -100, "face": 200,  "sta": 0,    "pre": 0,    "sup": 0,    "sdn": 100 },
    "bite":     { "near": 600,  "far": -400, "face": 350,  "sta": 250,  "pre": 0,    "sup": 400,  "sdn": -300 }
  },
  "personality": {
    "hold":     { "A": -250, "R": -100, "E": 350 },
    "retreat":  { "A": -150, "R": -350, "E": 50  },
    "approach": { "A": 300,  "R": 50,   "E": -100 },
    "flank":    { "A": -100, "R": 350,  "E": 50  },
    "bite":     { "A": 400,  "R": 250,  "E": -250 }
  },
  "repeat_penalty": { "hold": 120, "retreat": 200, "approach": 150, "flank": 250, "bite": 300 },
  "action_order": ["bite", "approach", "flank", "hold", "retreat"],
  "deadlock": { "hold_chain_start": 3, "hold_chain_penalty": 120, "same_action_limit": 6 }
}
```

`action_order` 同时承担两件事：遍历顺序、平局优先序。改顺序会改变行为，调参时注意。

## 2. 对局日志

路径由启动参数 `--out=` 决定，默认 `user://logs`。批量自博弈时用 `--out=res://out`。

文件名 `match_<match_id>.jsonl`，一行一条 JSON，UTF-8，无 BOM。

### 2.1 对局头

第一行固定为头：

```json
{"type":"match_start","match_id":0,"tick_ms":450,"max_tick":133,"seed":0,
 "crickets":[{"id":"scale","A":0.20,"R":0.15,"E":0.90,"S":-0.90,"P":0.25},
             {"id":"rush","A":0.90,"R":0.75,"E":0.20,"S":0.90,"P":0.85}],
 "start_pos":[[1,1],[3,1]],"start_facing":[[1,0],[-1,0]],
 "hud":"off","version":"demo1"}
```

### 2.2 每拍记录

每个可决策的虫各写一条。被锁定（角力、硬直）的虫不写决策记录。

```json
{"type":"tick","match_id":0,"tick":17,"actor":"rush","action":"bite",
 "from":[3,1],"to":[3,1],"facing":[-1,0],
 "stamina":72,"pressure":34,
 "feat":{"near":0,"far":50,"face":100,"sta":72,"pre":34,"sup":0,"sdn":0},
 "scores":{"bite":1280,"approach":640,"flank":410,"hold":190,"retreat":60},
 "event":null}
```

字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `tick` | int | 从 0 开始 |
| `actor` | string | 蛐蛐 id |
| `action` | string | 本拍动作 |
| `from` / `to` | [int,int] | 移动前后的槽位 |
| `facing` | [int,int] | 本拍结束朝向 |
| `stamina` / `pressure` | int | 本拍结束值 |
| `feat` | object | 7 个特征，调试用 |
| `scores` | object | 5 个动作最终分（含惩罚） |
| `event` | string\|null | 见 2.3 |

`scores` 必须写，它是调参与复盘归因的唯一依据。别为了省字节删掉。

### 2.3 关键事件

单独一条，`type` 不为 `tick`：

```json
{"type":"grapple","match_id":0,"tick":17,"att":"rush","def":"scale",
 "result":"suppressed","att_sta_before":72,"def_sta_before":58,
 "att_sta_after":66,"def_sta_after":40,
 "att_pressure_after":42,"def_pressure_after":83,
 "att_push":false,"def_push":true}
```

```json
{"type":"whiff","match_id":0,"tick":24,"actor":"rush","target":"scale",
 "reason":"out_of_range"}
```

`reason` 取值：`out_of_range`（距离不够）/ `facing`（朝向偏了）/ `retreated`（对手后撤走了）。

```json
{"type":"clash","match_id":0,"tick":38,"a":"fool","b":"rush",
 "a_sta_after":46,"b_sta_after":52,
 "a_pressure_after":61,"b_pressure_after":58,
 "a_push":true,"b_push":true}
```

`clash` 是双方同拍互咬，不进角力、不锁定下一拍。它和 `grapple` 是两种事件，统计时要分开算。

```json
{"type":"stress_trigger","match_id":0,"tick":31,"actor":"scale","pressure":61,"S":-0.9,"mode":"shrink"}
```

`mode` 取值：`rage`（S>0）/ `shrink`（S<0）。

```json
{"type":"threshold","match_id":0,"tick":44,"actor":"rush","which":"low_stamina","value":29}
```

`which` 取值：`low_stamina` / `panic`。

```json
{"type":"match_end","match_id":0,"tick":88,"winner":"rush","loser":"scale",
 "reason":"stamina_zero",
 "final":[{"id":"rush","stamina":42},{"id":"scale","stamina":0}]}
```

`reason` 取值：`stamina_zero` / `flee` / `timeout` / `draw_tiebreak`。

### 2.4 写盘策略

- 每局一个文件，开局创建，结束关闭
- 逐行 flush（`FileAccess.flush()`），中途崩溃也能留下数据
- 不写二进制、不压缩，纯文本便于 `grep` 与 `diff`

## 3. 统计汇总

批量跑完后由 `tools/summarize.gd` 生成，路径为 `--in=` 指定目录下的 `summary.csv` 与 `dist.csv`。

`summary.csv` 一行一场：

```
match_id,cricket_a,cricket_b,winner,loser,reason,ticks,
a_hold,a_retreat,a_approach,a_flank,a_bite,
b_hold,b_retreat,b_approach,b_flank,b_bite,
a_whiff,b_whiff,a_grapple_win,a_grapple_lose,
a_avg_pressure,a_max_pressure,a_stress_triggers,
b_avg_pressure,b_max_pressure,b_stress_triggers
```

`a_hold` 等是**该动作占总拍数的比例**，保留 3 位小数，和为 1。

另出一份按蛐蛐汇总的分布表 `dist.csv`：

```
id,matches,hold,retreat,approach,flank,bite,win_rate,avg_ticks,avg_pressure
```

`dist.csv` 是判断可分性的直接依据，见 `05-verification.md`。

## 4. 目录约定

```
QUQU FIGHT2/
├── data/                  # 三份配置 JSON
├── src/
│   ├── core/              # 规则与决策，零 Node 依赖
│   │   ├── match.gd       # 单局主循环
│   │   ├── cricket.gd     # 蛐蛐状态
│   │   ├── rules.gd       # 动作、结算、判定
│   │   ├── decision.gd    # 打分
│   │   └── logger.gd      # 日志写入
│   └── view/              # 表现层，只在有窗口时加载
│       ├── arena_view.gd
│       ├── cricket_view.gd
│       └── hud.gd
├── scenes/
│   └── main.tscn
├── tools/
│   ├── batch_runner.gd    # 批量自博弈
│   └── summarize.gd       # 汇总统计
└── tests/
    └── test_*.gd
```

`src/core/` 下任何文件都不允许 `extends Node`、不允许 `preload` 场景、不允许引用 `src/view/`。

这条是硬边界。违反后 headless 跑不起来，整条验证链断掉。
