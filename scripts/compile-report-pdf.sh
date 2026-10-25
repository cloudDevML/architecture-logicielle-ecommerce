#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE COMPILATION DU RAPPORT EN PDF A4
# EduMarket — Module Architecture Logicielle (DIC2 2026)
# ==============================================================================

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================================================"
echo "  Compilation du Rapport d'Architecture Logicielle en PDF A4"
echo "========================================================================"

MD_FILE="rapport/RAPPORT_ARCHITECTURE_LOGICIELLE.md"
HTML_FILE="rapport/RAPPORT_ARCHITECTURE_LOGICIELLE.html"
PDF_FILE="rapport/RAPPORT_ARCHITECTURE_LOGICIELLE.pdf"

if [ ! -f "$MD_FILE" ]; then
    echo "Erreur : Fichier $MD_FILE introuvable !"
    exit 1
fi

echo "[1/3] Conversion Markdown vers HTML (via marked)..."
BODY_HTML=$(marked -i "$MD_FILE")

echo "[2/3] Application du gabarit typographique académique A4..."
cat << 'HTML_EOF' > "$HTML_FILE"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Rapport d'Architecture Logicielle - EduMarket</title>
    <style>
        @page {
            size: A4;
            margin: 12mm 12mm 12mm 12mm;
            @bottom-right {
                content: counter(page) " / " counter(pages);
                font-size: 8pt;
                color: #64748b;
            }
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            font-size: 8.8pt;
            line-height: 1.38;
            color: #1e293b;
            background-color: #ffffff;
            margin: 0;
            padding: 0;
        }
        h1, h2, h3, h4 {
            color: #0f172a;
            font-weight: 700;
            page-break-after: avoid;
        }
        h1 {
            font-size: 15pt;
            border-bottom: 2px solid #2563eb;
            padding-bottom: 4px;
            margin-top: 14px;
            margin-bottom: 8px;
        }
        h2 {
            font-size: 11.5pt;
            border-bottom: 1px solid #e2e8f0;
            padding-bottom: 3px;
            margin-top: 12px;
            margin-bottom: 6px;
        }
        h3 {
            font-size: 9.8pt;
            margin-top: 10px;
            margin-bottom: 4px;
            color: #1e40af;
        }
        p {
            margin-top: 0;
            margin-bottom: 5px;
            text-align: justify;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 8px 0;
            font-size: 8pt;
            page-break-inside: avoid;
        }
        th, td {
            border: 1px solid #cbd5e1;
            padding: 4px 6px;
            text-align: left;
        }
        th {
            background-color: #f1f5f9;
            color: #0f172a;
            font-weight: 600;
        }
        tr:nth-child(even) {
            background-color: #f8fafc;
        }
        pre {
            background-color: #f8fafc;
            border: 1px solid #e2e8f0;
            border-left: 3px solid #2563eb;
            border-radius: 3px;
            padding: 6px 8px;
            font-family: "JetBrains Mono", Menlo, Monaco, Consolas, monospace;
            font-size: 7.5pt;
            line-height: 1.25;
            overflow-x: auto;
            page-break-inside: avoid;
            margin: 6px 0;
        }
        code {
            font-family: Menlo, Monaco, Consolas, monospace;
            font-size: 8pt;
            background-color: #f1f5f9;
            color: #b91c1c;
            padding: 1px 3px;
            border-radius: 2px;
        }
        pre code {
            background-color: transparent;
            color: #1e293b;
            padding: 0;
        }
        img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 10px auto;
            page-break-inside: avoid;
        }
        blockquote {
            margin: 6px 0;
            padding: 6px 10px;
            background-color: #f0f9ff;
            border-left: 3px solid #0284c7;
            color: #0369a1;
            font-size: 8.5pt;
            font-style: italic;
        }
        hr {
            border: none;
            border-top: 1px solid #cbd5e1;
            margin: 10px 0;
        }
        ul, ol {
            margin-top: 0;
            margin-bottom: 5px;
            padding-left: 18px;
        }
        li {
            margin-bottom: 2px;
        }
    </style>
</head>
<body>
HTML_EOF

echo "$BODY_HTML" >> "$HTML_FILE"
echo "</body></html>" >> "$HTML_FILE"

echo "[3/3] Génération du PDF via Chromium/Chrome headless..."
google-chrome-stable --headless --disable-gpu --no-sandbox --print-to-pdf="$PDF_FILE" "$HTML_FILE"

echo ""
echo "✓ PDF généré avec succès dans : $PDF_FILE"
if command -v pdfinfo &> /dev/null; then
    PAGE_COUNT=$(pdfinfo "$PDF_FILE" | grep "Pages:" | awk '{print $2}')
    echo "✓ Nombre total de pages : $PAGE_COUNT / 10 max"
fi
