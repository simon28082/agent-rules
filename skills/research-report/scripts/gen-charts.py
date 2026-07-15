#!/usr/bin/env python3
"""Generate chart PNG images with embedded data source footnotes.

Usage:
  python3 gen-charts.py <ticker> <subcommand> [args...]

Subcommands: pie, bar, line, combo, grouped_bar, table, timeline
"""

import argparse
import sys
import os
import textwrap

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import matplotlib.font_manager as fm
import numpy as np

# Use STHeiti for CJK, fall back to DejaVu Sans for Latin
_font_path = "/System/Library/Fonts/STHeiti Medium.ttc"
if os.path.exists(_font_path):
    _prop = fm.FontProperties(fname=_font_path)
    plt.rcParams["font.family"] = _prop.get_name()
    # Also add the font to finder so it gets used for tick labels etc.
    fm.fontManager.addfont(_font_path)
    plt.rcParams["font.sans-serif"] = [_prop.get_name(), "DejaVu Sans"]
plt.rcParams["axes.unicode_minus"] = False


def add_source(fig, source_text):
    """Embed data source as italic footnote at chart bottom."""
    fig.text(0.5, -0.01, source_text, ha="center", va="top",
             fontsize=8, fontstyle="italic", color="#666666",
             transform=fig.axes[0].transAxes)


def cmd_pie(args):
    fig, ax = plt.subplots(figsize=(7, 4.5))
    pairs = [x.split(":") for x in args.data.split(",")]
    labels = [p[0] for p in pairs]
    values = [float(p[1]) for p in pairs]
    colors = ["#3b82f6", "#94a3b8", "#f59e0b", "#10b981", "#ef4444",
              "#8b5cf6", "#ec4899", "#14b8a6", "#f97316", "#6366f1"]
    wedges, texts, autotexts = ax.pie(
        values, labels=None, autopct="%1.1f%%",
        colors=colors[:len(values)],
        startangle=90, pctdistance=0.75,
        textprops={"fontsize": 10})
    if labels:
        if args.amount_and_percentage:
            total = sum(values)
            if total == 0:
                raise ValueError("revenue pie chart values must not sum to zero")
            legend_labels = [
                f"{label}：${value:.1f}{args.amount_unit}（{value / total:.0%}）"
                for label, value in zip(labels, values)
            ]
        elif args.percentage:
            total = sum(values)
            if total == 0:
                raise ValueError("percentage pie chart values must not sum to zero")
            legend_labels = [
                f"{label} ({value / total:.1%})"
                for label, value in zip(labels, values)
            ]
        else:
            legend_labels = [
                f"{label} (${value:.0f}M)"
                for label, value in zip(labels, values)
            ]
        ax.legend(wedges, legend_labels, loc="lower center",
                 ncol=min(len(labels), 3), fontsize=8,
                 bbox_to_anchor=(0.5, -0.12))
    ax.set_title(args.title, fontsize=13, fontweight="bold", pad=12)
    source = f"数据来源：{args.source}"
    fig.text(0.5, -0.02 if labels else -0.01, source,
             ha="center", va="top", fontsize=7.5,
             fontstyle="italic", color="#888888")
    plt.tight_layout()
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    plt.savefig(args.output, dpi=150, bbox_inches="tight")
    print(f"Saved {args.output}")


def cmd_bar(args):
    labels = args.labels.split(",")
    values = [float(v) for v in args.values.split(",")]
    fig, ax = plt.subplots(figsize=(7, 4))
    colors = ["#3b82f6"] * len(values)
    bars = ax.bar(labels, values, color=colors, width=0.55)
    for bar, v in zip(bars, values):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(),
                f"{v:.0f}" if abs(v) >= 1 else f"{v:.1f}",
                ha="center", va="bottom", fontsize=8)
    ax.set_title(args.title, fontsize=12, fontweight="bold", pad=10)
    ax.set_ylabel(args.ylabel or "", fontsize=10)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter("%.0f"))
    if args.ymin or args.ymax:
        ax.set_ylim(bottom=float(args.ymin) if args.ymin else None,
                    top=float(args.ymax) if args.ymax else None)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.text(0.5, -0.01, f"数据来源：{args.source}",
             ha="center", va="top", fontsize=7.5,
             fontstyle="italic", color="#888888")
    plt.tight_layout()
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    plt.savefig(args.output, dpi=150, bbox_inches="tight")
    print(f"Saved {args.output}")


def cmd_line(args):
    labels = args.labels.split(",")
    series_list = args.series.split(";")
    fig, ax = plt.subplots(figsize=(7, 4))
    line_colors = ["#3b82f6", "#ef4444", "#10b981", "#f59e0b", "#8b5cf6"]
    for i, series in enumerate(series_list):
        parts = series.split(":")
        name = parts[0]
        values = [float(v) for v in parts[1].split(",")]
        ax.plot(labels[:len(values)], values, marker="o", markersize=4,
                linewidth=1.5, color=line_colors[i % len(line_colors)],
                label=name)
    ax.legend(fontsize=8, loc="best")
    ax.set_title(args.title, fontsize=12, fontweight="bold", pad=10)
    ax.set_ylabel(args.ylabel or "", fontsize=10)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter("%.1f"))
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    for label in ax.get_xticklabels():
        label.set_fontsize(7.5)
        label.set_rotation(0)
    fig.text(0.5, -0.01, f"数据来源：{args.source}",
             ha="center", va="top", fontsize=7.5,
             fontstyle="italic", color="#888888")
    plt.tight_layout()
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    plt.savefig(args.output, dpi=150, bbox_inches="tight")
    print(f"Saved {args.output}")


def cmd_combo(args):
    # bar + line combo
    labels = args.labels.split(",")
    bar_values = [float(v) for v in args.bar_values.split(",")]
    line_values = [float(v) for v in args.line_values.split(",")]
    fig, ax1 = plt.subplots(figsize=(7, 4))
    colors = ["#3b82f6"] * len(labels)
    bars = ax1.bar(labels, bar_values, color=colors, width=0.5, alpha=0.75,
                   label=args.bar_label or "Bar")
    ax1.set_ylabel(args.ylabel or "", fontsize=10, color="#3b82f6")
    ax1.yaxis.set_major_formatter(mticker.FormatStrFormatter("%.0f"))
    ax2 = ax1.twinx()
    ax2.plot(labels, line_values, marker="o", markersize=4,
             linewidth=1.5, color="#ef4444", label=args.line_label or "Line")
    ax2.set_ylabel(args.ylabel2 or "", fontsize=10, color="#ef4444")
    ax2.yaxis.set_major_formatter(mticker.FormatStrFormatter("%.0f"))
    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax1.legend(lines1 + lines2, labels1 + labels2, fontsize=8, loc="upper left")
    ax1.set_title(args.title, fontsize=12, fontweight="bold", pad=10)
    ax1.spines["top"].set_visible(False)
    ax2.spines["top"].set_visible(False)
    for label in ax1.get_xticklabels():
        label.set_fontsize(7.5)
    fig.text(0.5, -0.01, f"数据来源：{args.source}",
             ha="center", va="top", fontsize=7.5,
             fontstyle="italic", color="#888888")
    plt.tight_layout()
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    plt.savefig(args.output, dpi=150, bbox_inches="tight")
    print(f"Saved {args.output}")


def cmd_grouped_bar(args):
    series_raw = args.series.split(";")
    data = {}
    for s in series_raw:
        parts = s.split(":")
        name = parts[0]
        data[name] = [float(v) for v in parts[1].split(",")]
    n_groups = max(len(v) for v in data.values())
    labels = (args.labels or "").split(",")
    if len(labels) < n_groups:
        labels = [str(i + 1) for i in range(n_groups)]
    fig, ax = plt.subplots(figsize=(7, 4))
    n_series = len(data)
    bar_width = 0.8 / n_series
    x = np.arange(n_groups)
    colors = ["#3b82f6", "#ef4444", "#10b981", "#f59e0b"]
    for i, (name, vals) in enumerate(data.items()):
        offset = (i - (n_series - 1) / 2) * bar_width
        bars = ax.bar(x + offset, vals, bar_width, label=name,
                       color=colors[i % len(colors)])
    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=8)
    ax.legend(fontsize=8)
    ax.set_title(args.title, fontsize=12, fontweight="bold", pad=10)
    ax.set_ylabel(args.ylabel or "", fontsize=10)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter("%.0f"))
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.text(0.5, -0.01, f"数据来源：{args.source}",
             ha="center", va="top", fontsize=7.5,
             fontstyle="italic", color="#888888")
    plt.tight_layout()
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    plt.savefig(args.output, dpi=150, bbox_inches="tight")
    print(f"Saved {args.output}")


def cmd_table(args):
    if not args.headers or not args.rows:
        raise ValueError("table requires --headers and --rows")

    headers = args.headers.split(",")
    rows = [
        [cell.replace("\\n", "\n") for cell in row.split("|")]
        for row in args.rows.split(";")
    ]
    if any(len(row) != len(headers) for row in rows):
        raise ValueError("each table row must contain one cell per header")

    height = min(max(2.4, 0.48 * (len(rows) + 2)), 8)
    fig, ax = plt.subplots(figsize=(8, height))
    ax.axis("off")
    fig.subplots_adjust(left=0.02, right=0.98, top=0.82, bottom=0.13)
    table = ax.table(
        cellText=rows,
        colLabels=headers,
        cellLoc="left",
        colLoc="left",
        bbox=[0, 0, 1, 1],
    )
    table.auto_set_font_size(False)
    table.set_fontsize(8.5)
    table.scale(1, 1.45)

    for (row_index, _), cell in table.get_celld().items():
        cell.set_edgecolor("#e5e7eb")
        if row_index == 0:
            cell.set_facecolor("#1e3a5f")
            cell.set_text_props(color="white", weight="bold")
        elif row_index % 2 == 0:
            cell.set_facecolor("#f8fafc")

    ax.set_title(args.title, fontsize=12, fontweight="bold", pad=7)
    fig.text(0.5, 0.045, f"数据来源：{args.source}",
             ha="center", va="top", fontsize=7.5,
             fontstyle="italic", color="#888888")
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    plt.savefig(args.output, dpi=150, bbox_inches="tight")
    print(f"Saved {args.output}")


def cmd_timeline(args):
    if not args.events:
        raise ValueError("timeline requires --events")

    events = [event.split("|") for event in args.events.split(";")]
    if not 3 <= len(events) <= 5:
        raise ValueError("timeline requires three to five events")
    if any(len(event) != 4 for event in events):
        raise ValueError(
            "each event must contain date|event|metric-or-reaction|what-changed"
        )

    positions = np.arange(len(events))
    fig, ax = plt.subplots(figsize=(max(9, len(events) * 2.5), 5.5))
    ax.hlines(0, positions[0], positions[-1], color="#94a3b8", linewidth=2)
    ax.scatter(positions, np.zeros(len(events)), color="#2563eb", s=70, zorder=3)

    for index, (date, event, metric, change) in enumerate(events):
        direction = 1 if index % 2 == 0 else -1
        text = "\n".join(
            (
                date,
                textwrap.fill(event, width=13),
                textwrap.fill(metric, width=16),
                textwrap.fill(change, width=16),
            )
        )
        ax.annotate(
            text,
            xy=(index, 0),
            xytext=(index, direction * 0.72),
            ha="center",
            va="bottom" if direction > 0 else "top",
            fontsize=8,
            arrowprops={"arrowstyle": "-", "color": "#94a3b8", "lw": 1},
        )

    ax.set_title(args.title, fontsize=13, fontweight="bold", pad=16)
    ax.set_xlim(positions[0] - 0.5, positions[-1] + 0.5)
    ax.set_ylim(-1.6, 1.6)
    ax.axis("off")
    fig.text(0.5, -0.01, f"数据来源：{args.source}",
             ha="center", va="top", fontsize=7.5,
             fontstyle="italic", color="#888888")
    plt.tight_layout()
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    plt.savefig(args.output, dpi=150, bbox_inches="tight")
    print(f"Saved {args.output}")


def main():
    parser = argparse.ArgumentParser(description="Generate chart PNGs with embedded sources")
    parser.add_argument("ticker", help="Stock ticker")
    parser.add_argument("subcommand", choices=["pie", "bar", "line", "combo", "grouped_bar", "table", "timeline"],
                        help="Chart type")
    parser.add_argument("--title", default="", help="Chart title")
    parser.add_argument("--ylabel", default="", help="Y-axis label")
    parser.add_argument("--ylabel2", default="", help="Secondary Y-axis label (combo only)")
    parser.add_argument("--source", default="SEC filings", help="Data source text")
    parser.add_argument("--output", required=True, help="Output PNG path")
    # pie
    parser.add_argument("--data", help="Pie data: 'Label1:val1,Label2:val2'")
    pie_display = parser.add_mutually_exclusive_group()
    pie_display.add_argument(
        "--percentage",
        action="store_true",
        help="Display pie-chart legend values as shares instead of $M",
    )
    pie_display.add_argument(
        "--amount-and-percentage",
        action="store_true",
        help="Display pie-chart legend values as USD amounts and shares",
    )
    parser.add_argument(
        "--amount-unit",
        choices=["M", "B"],
        default="M",
        help="Unit for --amount-and-percentage values",
    )
    # bar / pie
    parser.add_argument("--labels", help="X-axis labels: 'A,B,C'")
    parser.add_argument("--values", help="Bar values: '1,2,3'")
    parser.add_argument("--ymin", help="Y-axis min")
    parser.add_argument("--ymax", help="Y-axis max")
    # line
    parser.add_argument("--series", help="Line series: 'Name:1,2,3;Name2:4,5,6'")
    # table
    parser.add_argument("--headers", help="Table headers: 'Header1,Header2'")
    parser.add_argument("--rows", help="Table rows: 'Cell1|Cell2;Cell3|Cell4'")
    # timeline
    parser.add_argument(
        "--events",
        help="Timeline events: 'Date|Event|Metric or reaction|What changed;...'",
    )
    # combo
    parser.add_argument("--bar-values", help="Combo bar values: '1,2,3'")
    parser.add_argument("--line-values", help="Combo line values: '1,2,3'")
    parser.add_argument("--bar-label", default="", help="Combo bar legend label")
    parser.add_argument("--line-label", default="", help="Combo line legend label")

    a = parser.parse_args()
    cmds = {"pie": cmd_pie, "bar": cmd_bar, "line": cmd_line,
            "combo": cmd_combo, "grouped_bar": cmd_grouped_bar,
            "table": cmd_table, "timeline": cmd_timeline}
    cmds[a.subcommand](a)


if __name__ == "__main__":
    main()
