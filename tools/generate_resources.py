#!/usr/bin/env python3
"""Generate learning resource links for every node in The Math Universe.

Reads all domain JSON files from data/, constructs search-based URLs from
reliable educational platforms, and writes data/resources.json.

Usage:
    python3 tools/generate_resources.py
"""

import json
import os
import urllib.parse
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
DATA_DIR = PROJECT_DIR / "data"

DOMAIN_FILES = [
    "algebra.json",
    "analysis.json",
    "geometry.json",
    "number-theory.json",
    "probability.json",
    "topology.json",
    "combinatorics.json",
    "logic.json",
    "discrete-math.json",
    "differential-equations.json",
    "optimization.json",
    "applied-math.json",
    "category-theory.json",
]


def encode(query: str) -> str:
    """URL-encode a search query."""
    return urllib.parse.quote_plus(query)


# ---------------------------------------------------------------------------
# Resource generators per level
# ---------------------------------------------------------------------------

def beginner_resources(query: str, name: str) -> list[dict]:
    """Beginner-level resources (elementary school)."""
    return [
        {
            "title": f"{name} - Khan Academy",
            "url": f"https://www.khanacademy.org/search?referer=%2F&page_search_query={encode(query)}",
            "level": "beginner",
        },
        {
            "title": f"{name} - Math is Fun",
            "url": f"https://www.mathsisfun.com/search/google-search.html?cx=&q={encode(query)}",
            "level": "beginner",
        },
        {
            "title": f"{name} - YouTube",
            "url": f"https://www.youtube.com/results?search_query={encode(query + ' math explained')}",
            "level": "beginner",
        },
    ]


def intermediate_resources(query: str, name: str) -> list[dict]:
    """Intermediate-level resources (high school)."""
    return [
        {
            "title": f"{name} - Brilliant",
            "url": f"https://brilliant.org/wiki/{encode(query.lower().replace(' ', '-'))}/",
            "level": "intermediate",
        },
        {
            "title": f"{name} - Wolfram MathWorld",
            "url": f"https://mathworld.wolfram.com/search/?query={encode(query)}",
            "level": "intermediate",
        },
        {
            "title": f"{name} - Paul's Online Notes",
            "url": f"https://tutorial.math.lamar.edu/search.aspx?q={encode(query)}",
            "level": "intermediate",
        },
        {
            "title": f"{name} - CK-12",
            "url": f"https://www.ck12.org/search/?q={encode(query)}",
            "level": "intermediate",
        },
    ]


def profi_resources(query: str, name: str) -> list[dict]:
    """Professional/university-level resources."""
    # Build a Wikipedia-style article name
    wiki_title = name.replace(" ", "_")
    return [
        {
            "title": f"{name} - Wikipedia",
            "url": f"https://en.wikipedia.org/wiki/{encode(wiki_title)}",
            "level": "profi",
        },
        {
            "title": f"{name} - MIT OCW",
            "url": f"https://ocw.mit.edu/search/?q={encode(query)}",
            "level": "profi",
        },
        {
            "title": f"{name} - nLab",
            "url": f"https://ncatlab.org/nlab/search?query={encode(query)}",
            "level": "profi",
        },
    ]


def build_resources_for_node(
    node_id: str, name: str, domain: str, difficulty: int, keywords: list[str]
) -> list[dict]:
    """Build a resource list for a single node, weighted by difficulty."""
    # Build a contextual search query: domain + node name
    domain_label = domain.replace("-", " ")
    query = f"{domain_label} {name}"

    all_beginner = beginner_resources(query, name)
    all_intermediate = intermediate_resources(query, name)
    all_profi = profi_resources(query, name)

    # Distribute by difficulty (1-5):
    #   difficulty 1 → 3 beginner, 2 intermediate, 1 profi
    #   difficulty 2 → 2 beginner, 3 intermediate, 1 profi
    #   difficulty 3 → 1 beginner, 3 intermediate, 2 profi
    #   difficulty 4 → 1 beginner, 2 intermediate, 3 profi
    #   difficulty 5 → 0 beginner, 2 intermediate, 3 profi
    difficulty = max(1, min(5, difficulty))

    slices = {
        1: (3, 2, 1),
        2: (2, 3, 1),
        3: (1, 3, 2),
        4: (1, 2, 3),
        5: (0, 2, 3),
    }
    nb, ni, np_ = slices[difficulty]

    resources = []
    resources.extend(all_beginner[:nb])
    resources.extend(all_intermediate[:ni])
    resources.extend(all_profi[:np_])

    return resources


def extract_nodes() -> list[dict]:
    """Read all domain JSON files and extract node info."""
    nodes = []

    for filename in DOMAIN_FILES:
        filepath = DATA_DIR / filename
        if not filepath.exists():
            print(f"  Warning: {filepath} not found, skipping")
            continue

        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)

        domain_id = data["domain"]

        # Domain node itself
        nodes.append({
            "id": domain_id,
            "name": domain_id.replace("-", " ").title(),
            "domain": domain_id,
            "difficulty": 0,
            "keywords": [],
        })

        # Subdomains and topics
        for sub in data.get("subdomains", []):
            sub_id = sub["id"]
            nodes.append({
                "id": sub_id,
                "name": sub["name"],
                "domain": domain_id,
                "difficulty": sub.get("difficulty", 1),
                "keywords": [],
            })

            for topic in sub.get("topics", []):
                nodes.append({
                    "id": topic["id"],
                    "name": topic["name"],
                    "domain": domain_id,
                    "difficulty": topic.get("difficulty", 1),
                    "keywords": topic.get("keywords", []),
                })

    return nodes


def main():
    print("Generating learning resources...")

    nodes = extract_nodes()
    print(f"  Found {len(nodes)} nodes across {len(DOMAIN_FILES)} domain files")

    resources = {}
    for node in nodes:
        node_resources = build_resources_for_node(
            node["id"],
            node["name"],
            node["domain"],
            node["difficulty"],
            node["keywords"],
        )
        resources[node["id"]] = node_resources

    output_path = DATA_DIR / "resources.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(resources, f, indent=2, ensure_ascii=False)

    print(f"  Wrote {len(resources)} entries to {output_path}")

    # Summary stats
    total_links = sum(len(v) for v in resources.values())
    levels = {}
    for entries in resources.values():
        for entry in entries:
            levels[entry["level"]] = levels.get(entry["level"], 0) + 1
    print(f"  Total links: {total_links}")
    for level, count in sorted(levels.items()):
        print(f"    {level}: {count}")


if __name__ == "__main__":
    main()
