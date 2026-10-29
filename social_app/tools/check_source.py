"""Syntax, local-import, SQL and platform XML checks. Does not replace flutter analyze/test.
Install: python -m pip install tree-sitter tree-sitter-dart tree-sitter-typescript pglast
"""
from pathlib import Path
import sys, xml.etree.ElementTree as ET, re
from tree_sitter import Language, Parser
import tree_sitter_dart, tree_sitter_typescript, pglast
root=Path(__file__).resolve().parents[1]
parser=Parser(Language(tree_sitter_dart.language()))
issues=[]
files=list((root/'lib').rglob('*.dart'))+list((root/'test').rglob('*.dart'))
for f in files:
    tree=parser.parse(f.read_bytes())
    if tree.root_node.has_error: issues.append(f'Dart syntax: {f.relative_to(root)}')
    for target in re.findall(r"import\s+['\"]([^'\"]+)['\"]",f.read_text()):
        if ':' not in target and not (f.parent/target).is_file():issues.append(f'Missing import: {f.name} -> {target}')
ts_parser=Parser(Language(tree_sitter_typescript.language_typescript()))
ts_files=list((root/'supabase/functions').rglob('*.ts'))
for f in ts_files:
    if ts_parser.parse(f.read_bytes()).root_node.has_error:
        issues.append(f'TypeScript syntax: {f.relative_to(root)}')
for f in (root/'supabase').rglob('*.sql'):
    try:pglast.parse_sql(f.read_text())
    except Exception as e:issues.append(f'SQL syntax: {f.name}: {e}')
for f in [root/'android/app/src/main/AndroidManifest.xml',root/'ios/Runner/Info.plist']:
    try:ET.parse(f)
    except Exception as e:issues.append(f'XML syntax: {f.name}: {e}')
print(f'Checked {len(files)} Dart files, {len(ts_files)} TypeScript files, SQL files, local imports, Android/iOS XML.')
for issue in issues:print(issue)
print('PASS' if not issues else 'FAIL')
sys.exit(bool(issues))
