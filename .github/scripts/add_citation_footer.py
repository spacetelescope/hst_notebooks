#!/usr/bin/env python3
"""
add_citation_footer.py

Append (or refresh) a templated citation footer in every Jupyter notebook
under a given path. In --html-dir mode, append only missing citations to
generated notebook HTML and preserve source notebooks and existing citations.
Both modes are idempotent.

Usage:
    python add_citation_footer.py --config citation.toml [--path .] [--dry-run]
    python add_citation_footer.py --config citation.toml --path . --html-dir _site

Configuration is read from a TOML file. See citation.toml for the schema.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from string import Template
from typing import Any

import nbformat

try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:  # pragma: no cover
    import tomli as tomllib  # type: ignore


# An HTML comment we hide inside the footer cell so we can find and replace
# our own previous output on subsequent runs. Invisible when rendered.
FOOTER_MARKER = "<!-- CITATION_FOOTER:DO_NOT_EDIT -->"


# --------------------------------------------------------------------------- #
# Config
# --------------------------------------------------------------------------- #

@dataclass
class Config:
    template: str
    variables: dict[str, str]           # static values from the config
    date_source: str                    # "git", "mtime", or "today"
    date_format: str                    # strftime format
    exclude_dirs: list[str]
    exclude_globs: list[str]

    @classmethod
    def load(cls, path: Path) -> "Config":
        with path.open("rb") as fh:
            raw = tomllib.load(fh)

        try:
            template = raw["template"]
        except KeyError as e:
            raise SystemExit(f"Config missing required key: {e}") from e

        return cls(
            template=template,
            variables=raw.get("variables", {}),
            date_source=raw.get("date", {}).get("source", "git"),
            date_format=raw.get("date", {}).get("format", "%Y-%m-%d"),
            exclude_dirs=raw.get("exclude", {}).get("dirs",
                                                    [".ipynb_checkpoints", ".git"]),
            exclude_globs=raw.get("exclude", {}).get("globs", []),
        )


# --------------------------------------------------------------------------- #
# Per-notebook variable resolution
# --------------------------------------------------------------------------- #

def resolve_date(nb_path: Path, source: str, fmt: str) -> str:
    """Determine the 'released on' date for a notebook."""
    if source == "today":
        return datetime.now(timezone.utc).strftime(fmt)

    if source == "mtime":
        ts = nb_path.stat().st_mtime
        return datetime.fromtimestamp(ts, tz=timezone.utc).strftime(fmt)

    if source == "git":
        # Last commit that touched this file. %cs gives short ISO date (YYYY-MM-DD).
        try:
            result = subprocess.run(
                ["git", "log", "-1", "--format=%cI", "--", str(nb_path)],
                capture_output=True, text=True, check=True,
                cwd=nb_path.parent,
            )
            iso = result.stdout.strip()
            if iso:
                # %cI is strict ISO 8601; reformat to the requested format.
                dt = datetime.fromisoformat(iso)
                return dt.strftime(fmt)
        except (subprocess.CalledProcessError, FileNotFoundError, ValueError):
            pass
        # Fall back to mtime if the file isn't tracked or git isn't available.
        ts = nb_path.stat().st_mtime
        return datetime.fromtimestamp(ts, tz=timezone.utc).strftime(fmt)

    raise ValueError(f"Unknown date source: {source!r}")


def build_variables(nb_path: Path, repo_root: Path, config: Config) -> dict[str, str]:
    """Combine static config variables with per-notebook computed ones."""
    variables: dict[str, str] = dict(config.variables)  # copy

    # Per-notebook computed variables. These override config-level ones with
    # the same name, which is usually what you want.
    variables["notebook_name"] = nb_path.name
    variables["notebook_stem"] = nb_path.stem
    variables["notebook_path"] = nb_path.relative_to(repo_root).as_posix()
    variables["release_date"] = resolve_date(nb_path, config.date_source,
                                             config.date_format)
    return variables


# --------------------------------------------------------------------------- #
# Footer rendering & application
# --------------------------------------------------------------------------- #

def render_footer(template: str, variables: dict[str, str]) -> str:
    """Render the template with ${var} substitution, then prepend the marker."""
    try:
        body = Template(template).substitute(variables)
    except KeyError as e:
        raise SystemExit(
            f"Template references unknown variable {e}. "
            f"Available: {sorted(variables)}"
        ) from e
    return f"{FOOTER_MARKER}\n{body}"


def apply_footer(nb_path: Path, footer_source: str, dry_run: bool) -> str:
    """
    Update the notebook in place. Returns one of:
      "added"    – no footer existed, we appended one
      "updated"  – existing footer was replaced (content differed)
      "unchanged" – existing footer already matched
    """
    nb = nbformat.read(nb_path, as_version=4)

    existing_idx = None
    for i, cell in enumerate(nb.cells):
        if cell.cell_type == "markdown" and FOOTER_MARKER in cell.source:
            existing_idx = i
            break

    new_cell = nbformat.v4.new_markdown_cell(footer_source)

    if existing_idx is None:
        nb.cells.append(new_cell)
        status = "added"
    elif nb.cells[existing_idx].source.strip() == footer_source.strip():
        return "unchanged"
    else:
        nb.cells[existing_idx] = new_cell
        # If the footer wasn't already the last cell, move it there.
        if existing_idx != len(nb.cells) - 1:
            nb.cells.append(nb.cells.pop(existing_idx))
        status = "updated"

    if not dry_run:
        nbformat.write(nb, nb_path)
    return status


# --------------------------------------------------------------------------- #
# Discovery
# --------------------------------------------------------------------------- #

def find_notebooks(root: Path, config: Config) -> list[Path]:
    excluded_dirs = set(config.exclude_dirs)
    notebooks: list[Path] = []
    for p in root.rglob("*.ipynb"):
        if any(part in excluded_dirs for part in p.parts):
            continue
        if any(p.match(g) for g in config.exclude_globs):
            continue
        notebooks.append(p)
    return sorted(notebooks)


def apply_html_footer(html_path: Path, footer_source: str, dry_run: bool) -> str:
    """Append missing citations and refresh styling of generated footers."""
    from bs4 import BeautifulSoup, Comment
    from markdown_it import MarkdownIt

    original = html_path.read_text(encoding="utf-8")
    soup = BeautifulSoup(original, "html.parser")
    footer = soup.find(id="citation-footer")
    status = "updated"

    if footer is None:
        if soup.find(
            string=lambda value: isinstance(value, Comment)
            and "CITATION_FOOTER:DO_NOT_EDIT" in value
        ):
            return "unchanged"
        rendered = MarkdownIt("commonmark").render(footer_source)
        fragment = BeautifulSoup(rendered, "html.parser")
        # Preserve citations already supplied by the notebook or builder.
        text = " ".join(fragment.stripped_strings)
        if text and text in " ".join(soup.stripped_strings):
            return "unchanged"
        article = soup.select_one("article.bd-article") or soup.find("main")
        if article is None:
            raise ValueError(f"No article/main container found in {html_path}")
        footer = soup.new_tag("section", id="citation-footer")
        footer["aria-label"] = "Notebook citation"
        for node in list(fragment.contents):
            footer.append(node)
        article.append(footer)
        status = "added"

    css = """#citation-footer {
  font-size: 0.8rem !important;
  line-height: 1.4;
}
#citation-footer * {
  font-size: inherit !important;
  line-height: inherit;
}"""
    style = soup.find("style", id="citation-footer-style")
    if style is not None and style.string == css:
        if status != "added":
            return "unchanged"
    else:
        if style is None:
            style = soup.new_tag("style", id="citation-footer-style")
            if soup.head is not None:
                soup.head.append(style)
            else:
                soup.insert(0, style)
        style.string = css

    if not dry_run:
        html_path.write_text(str(soup), encoding="utf-8")
    return status

def process_html(root: Path, html_dir: Path, config: Config, dry_run: bool) -> int:
    """Map notebook source paths to Jupyter Book HTML, leaving other pages alone."""
    if not html_dir.is_dir() or not any(html_dir.rglob("*.html")):
        raise ValueError(f"No generated HTML found under {html_dir}")
    counts = {"added": 0, "updated": 0, "unchanged": 0, "not-built": 0}
    for notebook in find_notebooks(root, config):
        page = html_dir / notebook.relative_to(root).with_suffix(".html")
        if not page.is_file():
            counts["not-built"] += 1
            continue
        variables = build_variables(notebook, root, config)
        footer = render_footer(config.template, variables)
        status = apply_html_footer(page, footer, dry_run)
        counts[status] += 1
        print(f"  [{status:>9}] {page.relative_to(html_dir)}")
    if counts["added"] + counts["updated"] + counts["unchanged"] == 0:
        raise ValueError("No generated notebook pages matched the source notebooks")
    print(f"HTML citations: {counts}")
    return 0


# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", type=Path, required=True,
                    help="Path to a TOML config file.")
    ap.add_argument("--path", type=Path, default=Path("."),
                    help="Repo root to scan (default: current directory).")
    ap.add_argument("--dry-run", action="store_true",
                    help="Report what would change without writing files.")
    ap.add_argument("--html-dir", type=Path,
                    help="Generated Jupyter Book HTML directory; append missing citations without changing notebooks.")
    args = ap.parse_args(argv)

    config = Config.load(args.config)
    root = args.path.resolve()
    if args.html_dir is not None:
        return process_html(root, args.html_dir.resolve(), config, args.dry_run)
    notebooks = find_notebooks(root, config)

    if not notebooks:
        print(f"No notebooks found under {root}")
        return 0

    counts = {"added": 0, "updated": 0, "unchanged": 0}
    for nb_path in notebooks:
        variables = build_variables(nb_path, root, config)
        footer = render_footer(config.template, variables)
        status = apply_footer(nb_path, footer, dry_run=args.dry_run)
        counts[status] += 1
        rel = nb_path.relative_to(root)
        print(f"  [{status:>9}] {rel}")

    verb = "would " if args.dry_run else ""
    print(f"\n{verb}added: {counts['added']}, "
          f"{verb}updated: {counts['updated']}, "
          f"unchanged: {counts['unchanged']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
