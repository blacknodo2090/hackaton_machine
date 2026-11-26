"""Build a local Graphify graph from headings and explicit project references."""

import hashlib
import json
import re
import tempfile
from pathlib import Path

import networkx as nx
from graphify.analyze import god_nodes, suggest_questions, surprising_connections
from graphify.cluster import cluster, score_all
from graphify.export import to_html, to_json
from graphify.report import generate


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "graphify-out"
SOURCES = (
    "README.md",
    "docs/ARCHITECTURE.md",
    "docs/AI_WORKFLOW.md",
    "docs/PRODUCT_BRIEF.md",
)
HEADING = re.compile(r"^\s{0,3}#{1,6}\s+(.+?)\s*$")
ARTIFACTS = ("graph.json", "graph.html", "GRAPH_REPORT.md")


def extract(documents):
    graph = nx.Graph()
    for path in documents:
        graph.add_node(path, label=path, source_file=path, file_type="document")

    for path, content in documents.items():
        fenced = False
        for number, line in enumerate(content.splitlines(), start=1):
            if line.lstrip().startswith(("```", "~~~")):
                fenced = not fenced
                continue
            if fenced:
                continue

            location = f"L{number}"
            heading = HEADING.match(line)
            if heading:
                section = f"{path}#{number}"
                graph.add_node(section, label=heading[1], source_file=path,
                               source_location=location, file_type="document")
                graph.add_edge(path, section, relation="contains", confidence="EXTRACTED",
                               source_file=path, source_location=location)

            for target in documents:
                reference = re.escape(target)
                if target != path and re.search(rf"(?<![\w/.-]){reference}(?![\w/.-])", line):
                    graph.add_edge(path, target, relation="references", confidence="EXTRACTED",
                                   source_file=path, source_location=location)
    return graph


def main():
    documents = {path: (ROOT / path).read_text(encoding="utf-8-sig") for path in SOURCES}
    digest = hashlib.sha256(Path(__file__).read_bytes())
    digest.update(json.dumps(documents, ensure_ascii=False).encode("utf-8"))
    fingerprint = digest.hexdigest()
    stamp = OUT / ".scheduled-fingerprint"

    if not stamp.exists() and any((OUT / name).exists() for name in ARTIFACTS):
        raise SystemExit("graphify-out ya contiene un grafo generado fuera de esta tarea.")
    if (stamp.is_file() and stamp.read_text(encoding="ascii") == fingerprint
            and all((OUT / name).is_file() for name in ARTIFACTS)):
        print("Graphify: los documentos siguen al dia.")
        return

    graph = extract(documents)
    communities = cluster(graph)
    labels = {}
    for key, nodes in communities.items():
        first_document = next((node for node in nodes if node in documents), None)
        labels[key] = Path(first_document).stem if first_document else f"Secciones {key}"
    detection = {
        "total_files": len(documents),
        "total_words": sum(len(content.split()) for content in documents.values()),
        "files": {"document": list(documents)},
    }
    report = generate(
        graph, communities, score_all(graph, communities), labels, god_nodes(graph),
        surprising_connections(graph, communities), detection, {"input": 0, "output": 0},
        str(ROOT), suggested_questions=suggest_questions(graph, communities, labels),
    )
    OUT.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=OUT) as temporary:
        stage = Path(temporary)
        to_json(graph, communities, str(stage / "graph.json"), community_labels=labels)
        to_html(graph, communities, str(stage / "graph.html"), community_labels=labels)
        scope = "Actualización local basada en encabezados y referencias explícitas. Tokens usados: 0.\n\n"
        (stage / "GRAPH_REPORT.md").write_text(scope + report, encoding="utf-8")
        # Claim the output before replacing files so a partial write can be retried.
        stamp.write_text("pending", encoding="ascii")
        for name in ARTIFACTS:
            (stage / name).replace(OUT / name)
        (stage / stamp.name).write_text(fingerprint, encoding="ascii")
        (stage / stamp.name).replace(stamp)
    print(f"Graphify: {graph.number_of_nodes()} nodos y {graph.number_of_edges()} relaciones.")


if __name__ == "__main__":
    main()
