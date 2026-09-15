#!/usr/bin/env python3
"""Check generated local pages, fragments, and export coverage before publication."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
import re

root = Path('docs').resolve()
site = 'https://pgajer.github.io/geosmooth/'

class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.links, self.ids = [], set()
        self.feed(path.read_text())
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            self.ids.add(attrs['id'])
        for key in ('href', 'src'):
            if key in attrs:
                self.links.append(attrs[key])

pages = {p.resolve(): Page(p) for p in root.rglob('*.html')}
errors = []
for path, page in pages.items():
    for link in page.links:
        if link.startswith(site):
            target = urlsplit(link[len(site):])
            resolved = (root / unquote(target.path)).resolve()
        else:
            target = urlsplit(link)
            if target.scheme or target.netloc or target.path.startswith('/'):
                continue
            resolved = (path.parent / unquote(target.path)).resolve() if target.path else path
        if resolved.is_dir():
            resolved = resolved / 'index.html'
        if not resolved.exists():
            errors.append(f'{path.relative_to(root)}: missing {link}')
        elif target.fragment and resolved in pages and unquote(target.fragment) not in pages[resolved].ids:
            errors.append(f'{path.relative_to(root)}: missing fragment {link}')

exports = re.findall(r'^export\(([^)]+)\)', Path('NAMESPACE').read_text(), re.M)
aliases = {}
for rd in Path('man').glob('*.Rd'):
    for alias in re.findall(r'\\alias\{([^}]+)\}', rd.read_text()):
        aliases[alias] = rd.stem
for name in exports:
    expected = f'reference/{aliases[name]}.html'
    for index in ('reference/index.html', 'reference/alphabetical.html', 'articles/function-guide.html'):
        html = (root / index).read_text()
        if f'{aliases[name]}.html' not in html:
            errors.append(f'{index}: missing help link for {name} ({expected})')
if errors:
    raise SystemExit('\n'.join(errors))
print(f'Validated {len(pages)} HTML pages and reference links for all {len(exports)} exports.')
