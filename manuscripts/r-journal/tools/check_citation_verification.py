#!/usr/bin/env python3
"""Check citation keys, BibTeX entries, and HTML verification evidence."""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter, defaultdict
from html.parser import HTMLParser
from pathlib import Path


PASSING_STATUS = "verified"
ALLOWED_STATUSES = {
    "verified",
    "metadata-only",
    "unsupported",
    "wrong-source",
    "needs-human-review",
}


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="latin-1")


def strip_tex_comments(text: str) -> str:
    lines = []
    for line in text.splitlines():
        out = []
        escaped = False
        for char in line:
            if char == "%" and not escaped:
                break
            out.append(char)
            escaped = char == "\\" and not escaped
            if char != "\\":
                escaped = False
        lines.append("".join(out))
    return "\n".join(lines)


def extract_citation_keys(tex_text: str) -> set[str]:
    text = strip_tex_comments(tex_text)
    pattern = re.compile(
        r"\\(?:[A-Za-z]*cite[A-Za-z]*|nocite)\*?"
        r"(?:\s*\[[^\]]*\])*"
        r"\s*\{([^{}]+)\}",
        re.MULTILINE,
    )
    keys: set[str] = set()
    for match in pattern.finditer(text):
        for raw_key in match.group(1).split(","):
            key = raw_key.strip()
            if key and key != "*":
                keys.add(key)
    return keys


def extract_bib_keys(bib_text: str) -> set[str]:
    pattern = re.compile(r"@\s*[A-Za-z]+\s*[\{\(]\s*([^,\s]+)\s*,")
    return {match.group(1).strip() for match in pattern.finditer(bib_text)}


class VerificationHTMLParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.entries: list[dict[str, object]] = []
        self._stack: list[dict[str, object]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr = {name: value or "" for name, value in attrs}
        if "data-citation-key" in attr:
            entry = {
                "key": attr["data-citation-key"].strip(),
                "status": attr.get("data-status", "").strip(),
                "source_links": [],
                "_tag": tag.lower(),
            }
            self._stack.append(entry)
            self.entries.append(entry)

        if self._stack and tag.lower() == "a" and "data-source-link" in attr:
            href = attr.get("href", "").strip()
            self._stack[-1]["source_links"].append(href)

    def handle_endtag(self, tag: str) -> None:
        if self._stack and tag.lower() == self._stack[-1].get("_tag"):
            self._stack.pop()


def parse_verification_html(html_text: str) -> list[dict[str, object]]:
    parser = VerificationHTMLParser()
    parser.feed(html_text)
    return parser.entries


def extract_log_undefined_citations(log_text: str) -> set[str]:
    keys = set(re.findall(r"Citation [`']([^`']+)' on page .* undefined", log_text))
    keys.update(re.findall(r"LaTeX Warning: Citation [`']([^`']+)' undefined", log_text))
    return keys


def check(tex_paths: list[Path], bib_path: Path, html_path: Path, log_paths: list[Path]) -> list[str]:
    errors: list[str] = []

    for path in (*tex_paths, bib_path, html_path, *log_paths):
        if not path.exists():
            errors.append(f"Missing required file: {path}")
    if errors:
        return errors

    citation_keys: set[str] = set()
    for tex_path in tex_paths:
        citation_keys.update(extract_citation_keys(read_text(tex_path)))

    bib_keys = extract_bib_keys(read_text(bib_path))
    entries = parse_verification_html(read_text(html_path))

    undefined_from_logs: set[str] = set()
    for log_path in log_paths:
        undefined_from_logs.update(extract_log_undefined_citations(read_text(log_path)))
    if undefined_from_logs:
        errors.append("Undefined citations reported by LaTeX logs: " + ", ".join(sorted(undefined_from_logs)))

    missing_bib = sorted(citation_keys - bib_keys)
    if missing_bib:
        errors.append("Citation keys missing from BibTeX: " + ", ".join(missing_bib))

    entry_keys = [str(entry["key"]) for entry in entries if str(entry["key"])]
    entry_counts = Counter(entry_keys)
    duplicate_entries = sorted(key for key, count in entry_counts.items() if count > 1)
    if duplicate_entries:
        errors.append("Duplicate verification entries: " + ", ".join(duplicate_entries))

    missing_entries = sorted(citation_keys - set(entry_keys))
    if missing_entries:
        errors.append("Citation keys missing from verification HTML: " + ", ".join(missing_entries))

    unknown_entries = sorted(set(entry_keys) - citation_keys)
    if unknown_entries:
        errors.append("Verification entries not cited in manuscript: " + ", ".join(unknown_entries))

    by_status: dict[str, list[str]] = defaultdict(list)
    missing_source_links: list[str] = []
    invalid_statuses: list[str] = []

    for entry in entries:
        key = str(entry["key"])
        status = str(entry["status"])
        source_links = [link for link in entry["source_links"] if str(link).strip()]

        if status not in ALLOWED_STATUSES:
            invalid_statuses.append(f"{key or '<blank>'}:{status or '<blank>'}")
        elif status != PASSING_STATUS:
            by_status[status].append(key)

        if key in citation_keys and not source_links:
            missing_source_links.append(key)

    if invalid_statuses:
        errors.append("Invalid verification statuses: " + ", ".join(sorted(invalid_statuses)))

    for status in sorted(by_status):
        keys = sorted(key for key in by_status[status] if key)
        if keys:
            errors.append(f"Non-passing status {status}: " + ", ".join(keys))

    if missing_source_links:
        errors.append("Verification entries missing data-source-link href: " + ", ".join(sorted(missing_source_links)))

    if not citation_keys:
        errors.append("No citation keys found in manuscript source")

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--tex",
        required=True,
        type=Path,
        action="append",
        help="Manuscript TeX file. Pass more than once for split manuscripts.",
    )
    parser.add_argument("--bib", required=True, type=Path, help="BibTeX file")
    parser.add_argument("--html", required=True, type=Path, help="Citation verification HTML file")
    parser.add_argument(
        "--log",
        type=Path,
        action="append",
        default=[],
        help="Optional LaTeX log file to scan for undefined citation warnings.",
    )
    args = parser.parse_args(argv)

    errors = check(args.tex, args.bib, args.html, args.log)
    if errors:
        print("Citation verification failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Citation verification passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
