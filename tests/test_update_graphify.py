import unittest

from scripts.update_graphify import extract


class GraphifyExtractionTest(unittest.TestCase):
    def test_indexes_headings_and_in_scope_references(self):
        graph = extract({
            "README.md": "# Inicio\nConsulta `docs/ARQUITECTURA.md` y `otro.md`.",
            "docs/ARQUITECTURA.md": "## Componentes",
        })

        self.assertEqual(graph.nodes["README.md#1"]["label"], "Inicio")
        self.assertEqual(graph["README.md"]["docs/ARQUITECTURA.md"]["source_location"], "L2")
        self.assertNotIn("otro.md", graph)

    def test_ignores_examples_in_fenced_blocks(self):
        graph = extract({"README.md": "```md\n# Ejemplo\n```\n# Inicio"})

        self.assertNotIn("README.md#2", graph)
        self.assertEqual(graph.nodes["README.md#4"]["label"], "Inicio")
