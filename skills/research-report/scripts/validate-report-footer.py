#!/usr/bin/env python3
"""Validate the required data note and disclaimer at report end."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


FOOTER_REFERENCE = Path(__file__).resolve().parents[1] / "references" / "publication-footer.md"
REQUIRED_DATA_FIELDS = ("来源：", "数据截至：", "口径差异：", "数据缺口：")


def extract_disclaimer(reference_path: Path) -> str:
    reference = reference_path.read_text(encoding="utf-8")
    match = re.search(
        r"<!-- disclaimer:start -->\s*(.*?)\s*<!-- disclaimer:end -->",
        reference,
        flags=re.DOTALL,
    )
    if match is None:
        raise ValueError(f"免责声明标记缺失：{reference_path}")
    return match.group(1).strip()


def markdown_paragraphs(markdown: str) -> list[str]:
    return [
        paragraph.strip()
        for paragraph in re.split(r"\n\s*\n", markdown.strip())
        if paragraph.strip()
    ]


def validate_footer(report_path: Path, disclaimer: str) -> list[str]:
    paragraphs = markdown_paragraphs(report_path.read_text(encoding="utf-8"))
    errors: list[str] = []

    if len(paragraphs) < 2:
        return ["报告至少需要数据说明和免责声明两段文末内容。"]

    data_note, report_disclaimer = paragraphs[-2:]
    if report_disclaimer != disclaimer:
        errors.append("免责声明不是最后一段，或与公共模板不完全一致。")

    if not (data_note.startswith("*数据说明：") and data_note.endswith("*")):
        errors.append("倒数第二段必须是斜体“数据说明：”段落。")

    missing_fields = [
        field for field in REQUIRED_DATA_FIELDS if field not in data_note
    ]
    if missing_fields:
        errors.append(f"数据说明缺少字段：{'、'.join(missing_fields)}。")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate a report's required publication footer."
    )
    parser.add_argument("report", type=Path, help="Markdown report path")
    args = parser.parse_args()

    try:
        disclaimer = extract_disclaimer(FOOTER_REFERENCE)
        errors = validate_footer(args.report, disclaimer)
    except (OSError, ValueError) as error:
        print(f"校验失败：{error}")
        return 1

    if errors:
        for error in errors:
            print(f"校验失败：{error}")
        return 1

    print("文末校验通过。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
