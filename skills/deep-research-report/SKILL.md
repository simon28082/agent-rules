---
name: deep-research-report
description: Synthesize raw research notes about a publicly traded company into a structured, factual deep research article. Produces one Markdown file for publication (e.g. Patreon). Use when the user has research notes and wants them turned into a publishable article covering investability, business segments, management culture, and financial metrics（PE/EPS）.
disable-model-invocation: true
---

# Deep Research Report

Turn existing research notes about a company into a structured deep-dive article. The article reads as if written by a human analyst — no AI-isms, no framing filler, no price targets. **Every claim must be traceable to verifiable data.**

## Input

User supplies one or more research notes (Markdown files). Read them all first before writing.

### 数据收集规范（强制）

所有财务数据、行业数据和公司数据必须通过以下 AI Berkshire 技能获取，**不得自行通过 web search/task agent 抓取原始数据**。这些技能内部使用 `financial_rigor.py` 等脚本工具进行交叉验证和精确运算，确保数据准确性。

| Skill | 用途 | 调用方式 |
|-------|------|---------|
| `investment-research` | 公司级深度研究：财务数据、收入结构、竞争格局、管理层、估值 | `skill investment-research` |
| `industry-research` | 行业级全景扫描：产业链结构、市场规模、竞争格局、头部公司扫描 | `skill industry-research` |
| `industry-funnel` | 行业漏斗筛选：全市场扫描→粗筛→精细分析→终选 3 家 | `skill industry-funnel` |
| `management-deep-dive` | 管理层纵深研究：CEO 履历、关键决策、资本配置、企业文化 | `skill management-deep-dive` |

**数据使用规则：**
1. 始终优先调用 `investment-research` 获取公司级财务和估值数据——该 skill 会执行多源交叉验证和市值验算
2. 行业背景/市场规模/竞争格局数据来自 `industry-research`
3. 所有来源信息必须在报告中如实标注（如 "VPG FY2025 10-K"、"Macrotrends"），不得因数据通过脚本获取就省略原始来源
4. 如果调用 skill 后仍有数据缺口，在报告中明确标注"数据缺口"并附说明，不自行估算填补

## Output

One Markdown file containing the full article.

## Structure

Organize into nine sections, in this order:

1. **Industry and the company's position** — what industry is the company in (size, growth rate, value chain structure), where the company sits within it (market share, ranking, competitive positioning), why this industry matters
2. **Business overview** — revenue breakdown by segment, key financial figures (revenue, net income, FCF, market cap), 5-year trend visualized as charts (revenue+net income combo chart, gross margin+operating margin dual-line chart, ROE bar chart). Do NOT use a large data table — convert tables to charts whenever possible
3. **Core business** — what the company's main revenue driver is, its competitive position, the risks to its foundation
4. **Profit foundation** — the highest-margin, most defensible part of the business (often IP/patents, licensing, or recurring revenue)
5. **Growth businesses** — new revenue streams, their growth trajectory, competitive dynamics, and realistic assessment (distinguish pipeline/pipeline-value from realized revenue)
6. **Management & culture** — CEO track record, key strategic decisions, capital allocation, insider ownership, engineering/corporate culture
7. **Financial metrics & institutional consensus** — PE, EPS, FCF, ROE. Address GAAP vs non-GAAP distortions. Compare vs peers and vs own history. Include a dedicated sub-section for **institutional consensus estimates**: consensus EPS forecasts for the next 1-3 fiscal years, implied Forward PE at each consensus point, growth trajectory vs historical, and source (Bloomberg consensus / Yahoo Finance / Visible Alpha). Use a chart to visualize the consensus EPS path alongside historical EPS
8. **Risks** — systematic risk checklist: competitive risk, execution risk (capacity delivery / product roadmap), supply chain concentration, valuation/multiple compression risk, dilution risk (equity raises), management/key-person risk, customer concentration, regulatory/geopolitical risk. For each risk: what it is, how likely, and what would trigger it. This is the "Munger upside-down" section — list all the ways this investment could fail
9. **Investability questions** — 7 key questions that synthesize the above: (1) profit sustainability, (2) growth reality, (3) management alignment, (4) worst case, (5) best case, (6) geopolitical risks, (7) investor fit

## Tone rules

- **Fact-based:** every claim must be supported by a verifiable data point. No opinions without evidence. When uncertainty exists, state the range of possibilities and why — don't guess a single answer
- No AI-isms: no confidence ratings, no "research bias" disclosure statements, no structured analysis tables with scoring, no commentary on information availability
- No framing filler: remove phrases like "需要指出的是", "先看好的部分", "但有一件事不能说谎", "用事实说话", "这组数字需要正确理解", "理解某某的关键就在这里"
- No price discussion: no buy/sell recommendations, no price targets, no "what price to buy at" guidance
- Each paragraph starts with a fact or a direct judgment, not a lead-in sentence
- Let the facts carry the weight; don't wrap them in introductory packaging
- **Financial units:** all monetary values must use American units ($M, $B, $K). Never convert to Chinese units (万, 亿). Examples: $318M not $3.18亿, $20.2M not $2020万, $1.5B not $15亿
- **No inline verification language:** do not mention tool names (`financial_rigor.py`, `cross-validate`, etc.), validation results, or bias/disclaimer statements within the article body. All data sourcing and validation notes must be consolidated into a single section at the end of the document, titled with the format: `*数据验证说明：...*`

## Charts

**Embed charts at every section where data can be visualized.** Charts are the primary communication tool for financial data — use them before prose when possible.

All charts must be generated as **standalone PNG images** via `scripts/gen-charts.py`, not as inline text diagrams. This ensures:

1. Data source footnotes are **embedded inside the image** — they never get separated from the chart
2. Charts have consistent visual style (font, color, layout)
3. Modifying data means re-running the script, not hand-editing text

### Mandatory charts

| # | Section | Chart function | Data span |
|---|---------|---------------|-----------|
| 1 | Revenue breakdown | `pie` | Latest fiscal year |
| 2 | Core business trend | `bar` or `line` | 3+ years, by fiscal quarter |
| 3 | Growth business trend | `bar` | 3+ years, by fiscal year |
| 4 | **PE history (TTM)** | `line` | **Last 12 fiscal quarters, one data point per quarter-end** |
| 5 | **Forward PE** | `line` | **Last 12 fiscal quarters, one data point per quarter-end** |
| 6 | **EPS history (GAAP & Non-GAAP)** | `line` (dual lines) | **Last 12 fiscal quarters, one data point per quarter-end** |
| 7 | **Institutional consensus EPS path** | `line` | Historical (last 4 FY) + consensus (next 1-3 FY), one data point per fiscal year |
| 8a | Peer PE comparison (TTM vs Forward) | `grouped_bar` (dual series) | Current snapshot |
| 8b | Peer margin & ROE comparison | `grouped_bar` (dual series) | Current snapshot |
| 8c | Peer EV/Sales comparison | `bar` | Current snapshot |
| 9 | Financial quality (FCF vs NI) | `bar` + `line` combo | 3+ years by fiscal year |

**For PE, Forward PE, and EPS:** 以财报季度为单位展示，每个季度末一个数据点，覆盖最近 12 个季度。X 轴标注使用短格式避免拥挤：`23Q1`、`23Q2` 而非 `FY23Q1`、`FY23Q2`。若数据点 ≥ 10 个且渲染后标签重叠，拆分为多张图表（如 FY2023-FY2024 一张、FY2025-FY2026 一张）。不展示月度数据或年化数据。

### Chart generation script

`scripts/gen-charts.py` — 利用 matplotlib 生成所有图表，每条命令输出一张 PNG，数据来源作为 footnote 嵌入图片底部。

支持的子命令：

| 子命令 | 说明 |
|--------|------|
| `pie` | 饼图：`--data "Label1:val1,Label2:val2" --source "..."` |
| `bar` | 柱状图：`--labels "A,B,C" --values "1,2,3"` |
| `line` | 折线图：同上 |
| `combo` | 柱+线组合图：`--bar-values "..." --line-values "..."` |
| `grouped_bar` | 分组柱状图：`--series "S1:1,2,3;S2:4,5,6"` |

所有子命令共享参数：`--title`, `--ylabel`, `--source`, `--output`。

数据来源在图片底部以灰色斜体 8pt 文字呈现，格式：`数据来源：StockAnalysis, SEC 10-K`。URL 以完整链接形式写入图片底部。

### 嵌入报告

在报告中以 Markdown 图片引用嵌入，图表目录统一为 `charts/`（与报告 Markdown 同目录）：

```markdown
![收入结构](charts/revenue-pie.png)
```

### 渲染流程

```bash
# 1. 确保 matplotlib 和 numpy 已安装
pip install matplotlib numpy

# 2. 复制脚本到项目目录
cp -r <skill-dir>/scripts/ ./

# 3. 为每个必需图表生成 PNG
python3 scripts/gen-charts.py CRCL pie \
  --data "储备收益:2647,其他收入:110" \
  --source "SEC 10-K FY2025" \
  --title "FY2025 收入结构" \
  --output charts/revenue-pie.png
```

## Writing workflow

1. **读取输入**：读所有原始笔记
2. **数据收集**：按本 skill 的"数据收集规范"，调用 `investment-research` 获取公司级财务和估值数据，调用 `industry-research`（如需行业背景）。不得自行通过 web search 抓取原始数据。**额外收集**：主流机构的一致预期 EPS/远期 PE（Yahoo Finance 共识 / Bloomberg / Visible Alpha），至少获取最近 1-3 个财年的预测
3. **询问输出路径**：问用户保存位置
4. **确定读者前置知识**：假设读者已了解该公司的基本业务
5. **按节撰写**（Section 1→9，逐节写完，用户批准后再继续下一节）
6. **语调去违和**：全部写完后，通篇清除 AI-isms、填充语、价格指导
7. **生成图表**：最后一步用 `scripts/gen-charts.py` 批量生成所有图表的 PNG，来源已在脚本调用时嵌入图片内部，报告中通过 Markdown 图片引用嵌入

## Cover 封面

报告必须附带一张封面图片，位于标题与 Section 1 之间。

### 模板

`templates/cover.html`，使用 `{{PLACEHOLDER}}` 占位符替换：

| 占位符 | 说明 | 示例 |
|--------|------|------|
| `{{COMPANY}}` | 英文公司全称 | `DigitalOcean Holdings, Inc.` |
| `{{TICKER}}` | 股票代码 | `DOCN` |
| `{{TITLE_CN}}` | 中文标题（代码后） | `深度研究` |
| `{{SUBTITLE}}` | 副标题 | `AI-Native Cloud 的 SMB 突围战` |
| `{{TICKER_FULL}}` | 交易所+代码 | `NYSE: DOCN` |
| `{{DATE}}` | 报告日期 | `2026.07.12` |
| `{{M1_LABEL}}` / `{{M1_VAL}}` | 指标1 | `Market Cap` / `$13.6B` |
| `{{M2_LABEL}}` / `{{M2_VAL}}` | 指标2 | `Revenue` / `$901M` |
| `{{M3_LABEL}}` / `{{M3_VAL}}` | 指标3 | `Customers` / `640K` |
| `{{PRIMARY_COLOR}}` | 品牌主色（十六进制） | `#0066FF` |
| `{{TAG1}}`~`{{TAG3}}` | 底部标签（3个） | `AI ARR $170M` |

### 设计规范

- **字体**：标题 `Noto Sans SC 900`（42px），英文 `Inter 400-600`，标签 `Inter 500`（11px）
- **布局**：白底（`#fcfcfc` 卡片 `#ffffff` 背景），全部居中，无边框无分割线
- **间距**：顶部56px、左右64px、底部40px；两条透明1px 分割线保持间距（防止 margin collapsing）
- **meta 区域**：5项指标，flex 居中，`gap: 32px`
- **tags 区域**：3项，flex 居中，`gap: 12px`，圆角边框

### 渲染流程

从模板目录复制到项目，用占位符替换生成公司封面，Chrome headless 截图 + PIL 裁剪。

```bash
# 1. 复制模板和脚本到项目
SKILL_DIR="<path-to-this-skill>"
cp "$SKILL_DIR/templates/cover.html" ./
cp "$SKILL_DIR/scripts/gen-covers.sh" ./

# 2. 按示例编写公司封面生成脚本
#    参见 scripts/gen-covers.sh 中的 generate() 和 render_and_crop() 函数
```

### 嵌入报告

在标题和 Section 1 之间插入 Markdown 图片引用：

```markdown
![${TICKER} 深度研究报告封面](cover.png)
```
