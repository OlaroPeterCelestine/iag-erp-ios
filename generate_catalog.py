#!/usr/bin/env python3
"""Build erp-ios/IAG/systems.json from ../SYSTEMS.md."""

import json
import re
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "SYSTEMS.md"
OUTPUT = Path(__file__).resolve().parent / "IAG" / "systems.json"

SKIP_APPS = {"admin", "erp-api", "pos"}


def slug(value: str) -> str:
    text = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return text or "item"


def unique(base: str, used: set[str]) -> str:
    name = base
    index = 2
    while name in used:
        name = f"{base}-{index}"
        index += 1
    used.add(name)
    return name


def prose(lines: list[str]) -> str:
    kept: list[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("|") or stripped.startswith("#"):
            continue
        if stripped.startswith("- "):
            kept.append(stripped[2:].strip())
        else:
            kept.append(stripped)
    return "\n".join(kept).strip()


def parse_fields(lines: list[str]) -> list[dict]:
    fields: list[dict] = []
    used: set[str] = set()
    for line in lines:
        if not line.startswith("|") or line.startswith("| Field") or line.startswith("| ---"):
            continue
        columns = [part.strip() for part in line.strip().strip("|").split("|")]
        if len(columns) < 3:
            continue
        kind_raw = columns[1].lower()
        if kind_raw in {"folder"} or kind_raw.startswith("`"):
            continue
        base = kind_raw.split(",", 1)[0].strip()
        if base not in {"text", "number", "date", "textarea", "select", "email", "attachments"}:
            base = "text"
        choices: list[str] = []
        if len(columns) > 3:
            seen: set[str] = set()
            for choice in columns[3].split(","):
                choice = choice.strip()
                if choice and choice not in seen:
                    seen.add(choice)
                    choices.append(choice)
        label = columns[0]
        fields.append(
            {
                "id": unique(slug(label), used),
                "label": label,
                "kind": base,
                "required": columns[2].lower() == "yes",
                "readOnly": "read only" in kind_raw,
                "choices": choices,
            }
        )
    return fields


def parse_form(name: str, body: str, used_ids: set[str]) -> dict:
    lines = body.splitlines()
    table_at = next((index for index, line in enumerate(lines) if line.startswith("| Field |")), None)
    if table_at is None:
        return {
            "id": unique(slug(name), used_ids),
            "name": name,
            "note": prose(lines),
            "fields": [],
        }
    table_end = table_at + 1
    while table_end < len(lines) and lines[table_end].startswith("|"):
        table_end += 1
    note = prose(lines[:table_at] + lines[table_end:])
    return {
        "id": unique(slug(name), used_ids),
        "name": name,
        "note": note,
        "fields": parse_fields(lines[table_at:table_end]),
    }


def parse_groups(body: str) -> tuple[str, list[dict]]:
    marker = re.search(r"(?m)^### ", body)
    summary = body if marker is None else body[: marker.start()]
    groups: list[dict] = []
    if marker is None:
        return prose(summary.splitlines()), groups
    sections = re.split(r"(?m)^### ", body[marker.start() :])
    form_ids: set[str] = set()
    group_ids: set[str] = set()
    for section in sections:
        if not section.strip():
            continue
        title, _, section_body = section.partition("\n")
        title = title.strip()
        form_marker = re.search(r"(?m)^#### ", section_body)
        if form_marker:
            before = section_body[: form_marker.start()]
            forms = []
            chunks = re.split(r"(?m)^#### ", section_body[form_marker.start() :])
            for chunk in chunks:
                if not chunk.strip():
                    continue
                form_name, _, form_body = chunk.partition("\n")
                forms.append(parse_form(form_name.strip(), form_body, form_ids))
            groups.append(
                {
                    "id": unique(slug(title), group_ids),
                    "name": title,
                    "summary": prose(before.splitlines()),
                    "forms": forms,
                }
            )
        else:
            form = parse_form(title, section_body, form_ids)
            groups.append(
                {
                    "id": unique(slug(title), group_ids),
                    "name": title,
                    "summary": "",
                    "forms": [form],
                }
            )
    return prose(summary.splitlines()), groups


def split_systems(text: str) -> list[tuple[str, str]]:
    systems = []
    for part in re.split(r"(?m)^## ", text)[1:]:
        title, _, body = part.partition("\n")
        systems.append((title.strip(), body))
    return systems


def patch_pos_locations(system: dict) -> None:
    for group in system["groups"]:
        for form in group["forms"]:
            if form["name"] != "POS Locations":
                continue
            for field in form["fields"]:
                if field["label"] == "Type" and field["kind"] == "select":
                    field["choices"] = ["store", "kiosk", "counter", "stall", "branch", "market", "other"]


def main() -> None:
    text = SOURCE.read_text()
    parsed = {title: body for title, body in split_systems(text)}
    documents_summary, document_groups = parse_groups(parsed["Documents"])
    documents = {
        "id": "documents",
        "name": "Documents",
        "summary": documents_summary,
        "forms": [form for group in document_groups for form in group["forms"]],
    }

    catalog = []
    for title, body in split_systems(text):
        if title in {"Systems", "Documents"}:
            continue
        summary, groups = parse_groups(body)
        system_id = slug(title)
        folder_match = re.search(r"Folder `([^`]+)`", summary)
        port_match = re.search(r"port (\d+)", summary)
        system = {
            "id": system_id,
            "name": title,
            "folder": folder_match.group(1) if folder_match else "",
            "port": int(port_match.group(1)) if port_match else None,
            "summary": summary,
            "groups": groups,
        }
        if system_id == "erp":
            finance = next(item for item in catalog if item["id"] == "finance")
            system["groups"] = deepcopy(finance["groups"])
            system["summary"] = summary
            patch_pos_locations(system)
        elif system_id not in SKIP_APPS:
            copied = deepcopy(documents)
            taken = {form["id"] for group in system["groups"] for form in group["forms"]}
            for form in copied["forms"]:
                if form["id"] in taken:
                    form["id"] = unique(f"documents-{form['id']}", taken)
            system["groups"].append(copied)
        catalog.append(system)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps({"systems": catalog}, indent=2, ensure_ascii=False) + "\n")
    for system in catalog:
        forms = [form for group in system["groups"] for form in group["forms"]]
        with_fields = sum(1 for form in forms if form["fields"])
        print(f"{system['name']}: {with_fields} forms, {len(forms) - with_fields} screens")


if __name__ == "__main__":
    main()
