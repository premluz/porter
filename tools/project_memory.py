#!/usr/bin/env python3
"""Local Markdown registry. Python 3.10+, standard library only; not an MCP server."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROOT_DOCS = {'README.md', 'AGENTS.md', 'CLAUDE.md', 'CONSTITUTION.md',
             'PROJECT_STATE.md', 'PLANS.md', 'TASKS.md', 'PROGRESS.md'}
DOC_DIRS = ('docs', 'memory', 'decisions', 'plans', 'templates')
AREAS = {'product', 'ux', 'macos', 'browser', 'ios', 'identity', 'security',
         'sync', 'quality', 'memory', 'mcp', 'release'}
TAGS = {f'area/{s}' for s in AREAS} | {f'phase/{s}' for s in
        ('foundation', 'r0', 'r1', 'r2', 'r3', 'r4', 'r5')}
TYPES = {'index', 'instructions', 'constitution', 'state', 'spec', 'plan',
         'tasks', 'log', 'memory', 'questions', 'handoff', 'decision', 'template', 'sources'}
STATUSES = {'active', 'draft', 'proposed', 'accepted', 'superseded', 'complete',
            'template', 'archived'}
REQUIRED = {'id', 'type', 'title', 'status', 'updated', 'owner', 'tags', 'summary', 'related'}


def confined(path: Path) -> Path:
    resolved = path.resolve()
    if not resolved.is_relative_to(ROOT):
        raise ValueError(f'Path escapes project root: {path.name}')
    return resolved


def without_fences(text: str) -> str:
    """Keep line count; omit fenced examples when checking real links and tasks."""
    lines, fence = [], None
    for line in text.splitlines():
        marker = re.match(r'^\s*(`{3,}|~{3,})', line)
        if marker and (fence is None or marker.group(1)[0] == fence[0]):
            fence = marker.group(1) if fence is None else None
            lines.append('')
        else:
            lines.append('' if fence else line)
    return '\n'.join(lines)


def documents() -> list[dict]:
    paths = [ROOT / name for name in sorted(ROOT_DOCS) if (ROOT / name).exists()]
    for directory in DOC_DIRS:
        paths.extend(sorted((ROOT / directory).rglob('*.md')))
    result = []
    for path in sorted(paths):
        confined(path)
        raw = path.read_text(encoding='utf-8')
        if not raw.startswith('---\n') or '\n---\n' not in raw[4:]:
            raise ValueError(f'Missing frontmatter: {path.relative_to(ROOT)}')
        front, body = raw[4:].split('\n---\n', 1)
        meta = {}
        for line in front.splitlines():
            if not line.strip():
                continue
            key, sep, value = line.partition(':')
            if not sep or key in meta:
                raise ValueError(f'Invalid/duplicate frontmatter key: {path.name}: {line}')
            meta[key] = json.loads(value.strip())
        missing = REQUIRED - set(meta)
        if missing:
            raise ValueError(f'Missing metadata in {path.name}: {sorted(missing)}')
        for field in REQUIRED - {'tags', 'related'}:
            if not isinstance(meta[field], str) or not meta[field]:
                raise ValueError(f'{path.name}: {field} must be a nonempty string')
        for field in ('tags', 'related'):
            if not isinstance(meta[field], list) or not all(isinstance(x, str) for x in meta[field]):
                raise ValueError(f'{path.name}: {field} must be a string array')
        date.fromisoformat(meta['updated'])
        result.append(dict(meta, path=path.relative_to(ROOT).as_posix(),
                           revision='sha256:' + hashlib.sha256(raw.encode()).hexdigest(),
                           line_count=len(raw.splitlines()), content=raw, body=body))
    ids = [r['id'] for r in result]
    if len(ids) != len(set(ids)):
        raise ValueError('Duplicate document ID')
    return result


def index_text(records: list[dict]) -> str:
    records = [r for r in records if r['id'] != 'DOC-INDEX']
    updated = max(r['updated'] for r in records)
    meta = dict(id='DOC-INDEX', type='index', title='Generated project memory index',
                status='active', updated=updated, owner='project-maintainer',
                tags=['area/memory', 'phase/foundation'],
                summary='Generated entry points and topic map; rebuild with the local utility.',
                related=['DOC-README', 'DOC-MEMORY'])
    text = '---\n' + '\n'.join(f'{k}: {json.dumps(v)}' for k, v in meta.items()) + '\n---\n\n'
    text += '# Project memory index\n\nGenerated from current document metadata. Do not edit this table by hand.\n\n'
    text += 'Start with [current state](../PROJECT_STATE.md) and [handoff](HANDOFF.md). '
    text += 'Use [task status](../TASKS.md) to select work. Read deeper documents only as needed.\n\n'
    text += '| ID | Document | Status | Tags | Purpose |\n| --- | --- | --- | --- | --- |\n'
    for r in sorted(records, key=lambda d: d['id']):
        relative = '../' + r['path']
        vals = [r['id'], f"[{r['title']}]({relative})", r['status'], ', '.join(r['tags']), r['summary']]
        text += '| ' + ' | '.join(v.replace('|', '\\|') for v in vals) + ' |\n'
    text += '\nThe JSON catalog also records content hashes and line counts. '
    text += 'Neither index is a replacement for current source files. The MCP interface is proposed, not installed.\n'
    return text


def catalog(records: list[dict]) -> dict:
    return {'schema_version': 1, 'project': 'conversation-switcher',
            'documents': [{k: v for k, v in r.items() if k not in ('content', 'body')}
                          for r in sorted(records, key=lambda x: x['id'])]}


def rebuild() -> dict:
    records = documents()
    index = ROOT / 'memory/INDEX.md'
    confined(index)
    index.write_text(index_text(records), encoding='utf-8')
    records = documents()
    target = ROOT / 'memory/catalog.json'
    confined(target)
    target.write_text(json.dumps(catalog(records), indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    return {'ok': True, 'documents': len(records), 'generated': ['memory/INDEX.md', 'memory/catalog.json']}


def check() -> dict:
    records = documents()
    by_id = {r['id']: r for r in records}
    errors = []
    for name in ROOT_DOCS:
        if not (ROOT / name).is_file():
            errors.append(f'Missing root document: {name}')
    for r in records:
        if r['type'] not in TYPES or r['status'] not in STATUSES:
            errors.append(f"{r['path']}: invalid type/status")
        if not re.fullmatch(r'(DOC-[A-Z0-9-]+|ADR-\d{3}|PLAN-\d{3})', r['id']):
            errors.append(f"{r['path']}: invalid document ID")
        if not r['tags'] or len(r['tags']) != len(set(r['tags'])) or set(r['tags']) - TAGS:
            errors.append(f"{r['path']}: invalid or duplicate tags")
        for ref in r['related']:
            if ref not in by_id:
                errors.append(f"{r['path']}: unknown related ID {ref}")
        body = without_fences(r['body'])
        for target in re.findall(r'\[[^\]\n]*\]\(([^)\s]+)\)', body):
            if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target) or target.startswith('#'):
                continue
            target = target.split('#')[0]
            if target:
                try:
                    linked = confined((ROOT / r['path']).parent / target)
                    if not linked.is_file():
                        errors.append(f"{r['path']}: missing local link {target}")
                except ValueError as exc:
                    errors.append(str(exc))
    tasks, dependencies = {}, {}
    task_body = by_id.get('DOC-TASKS', {}).get('body', '')
    for line in task_body.splitlines():
        if not re.match(r'^\| TASK-\d{3} \|', line):
            continue
        cols = [s.strip() for s in line.strip('|').split('|')]
        if len(cols) != 7:
            errors.append(f'Invalid task row: {line[:30]}')
            continue
        ident, _, _, state, _, deps, _ = cols
        if ident in tasks:
            errors.append(f'Duplicate task ID: {ident}')
        tasks[ident] = state
        dependencies[ident] = re.findall(r'TASK-\d{3}', deps)
        if state not in {'todo', 'in_progress', 'blocked', 'done', 'deferred', 'cancelled'}:
            errors.append(f'Invalid task status: {ident}')
    for ident, deps in dependencies.items():
        for dep in deps:
            if dep not in tasks:
                errors.append(f'{ident}: unknown dependency {dep}')
            elif tasks[ident] == 'done' and tasks[dep] != 'done':
                errors.append(f'{ident}: done before dependency {dep}')
    def visit(node, trail, done):
        if node in trail:
            errors.append('Task dependency cycle: ' + ' -> '.join(trail + [node]))
            return
        if node in done:
            return
        for dep in dependencies.get(node, []):
            visit(dep, trail + [node], done)
        done.add(node)
    visited = set()
    for node in tasks:
        visit(node, [], visited)
    for name in ('AGENTS.md', 'CLAUDE.md'):
        p = ROOT / name
        if p.exists() and len(p.read_text().splitlines()) >= 200:
            errors.append(f'{name}: exceeds project instruction-size target')
    if 'DOC-INDEX' not in by_id or by_id['DOC-INDEX']['content'] != index_text(records):
        errors.append('Missing/stale memory/INDEX.md; run index')
    path = ROOT / 'memory/catalog.json'
    confined(path)
    if not path.exists() or json.loads(path.read_text()) != catalog(records):
        errors.append('Missing/stale memory/catalog.json; run index')
    return {'ok': not errors, 'documents': len(records), 'tasks': len(tasks), 'errors': errors}


def search(args) -> dict:
    terms = args.query.casefold().split()
    results = []
    for r in documents():
        if r['id'] == 'DOC-INDEX':
            continue
        if any(tag not in r['tags'] for tag in args.tag):
            continue
        if args.type and r['type'] not in args.type:
            continue
        if args.status and r['status'] not in args.status:
            continue
        title = (r['id'] + ' ' + r['title']).casefold()
        summary = (r['summary'] + ' ' + ' '.join(r['tags'])).casefold()
        body = r['body'].casefold()
        if terms and not all(t in title + ' ' + summary + ' ' + body for t in terms):
            continue
        score = sum(10 * (t in title) + 4 * (t in summary) + (t in body) for t in terms)
        excerpts = [{'line': n, 'text': line[:260]} for n, line in enumerate(r['content'].splitlines(), 1)
                    if terms and any(t in line.casefold() for t in terms)][:3]
        results.append({k: r[k] for k in ('id', 'path', 'title', 'summary', 'tags', 'status', 'revision')} |
                       {'score': score, 'excerpts': excerpts})
    results.sort(key=lambda r: (-r['score'], r['id']))
    return {'total': len(results), 'results': results[:args.limit]}


def read(args) -> dict:
    record = next((r for r in documents() if r['id'] == args.id), None)
    if record is None:
        raise ValueError('Unknown document ID; paths are not accepted')
    lines = record['content'].splitlines()
    if args.start > len(lines):
        raise ValueError('start exceeds document line count')
    end = min(len(lines), args.start - 1 + args.limit)
    return {'id': record['id'], 'path': record['path'], 'revision': record['revision'],
            'start_line': args.start, 'end_line': end, 'has_more': end < len(lines),
            'content': '\n'.join(lines[args.start - 1:end])}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('index')
    sub.add_parser('check')
    s = sub.add_parser('search')
    s.add_argument('query', nargs='?', default='')
    s.add_argument('--tag', action='append', default=[], choices=sorted(TAGS))
    s.add_argument('--type', action='append', default=[], choices=sorted(TYPES))
    s.add_argument('--status', action='append', default=[], choices=sorted(STATUSES))
    s.add_argument('--limit', type=int, default=5)
    r = sub.add_parser('read')
    r.add_argument('id')
    r.add_argument('--start', type=int, default=1)
    r.add_argument('--limit', type=int, default=160)
    args = parser.parse_args()
    if hasattr(args, 'limit') and not 1 <= args.limit <= (50 if args.command == 'search' else 500):
        parser.error('limit must be 1–50 for search or 1–500 for read')
    if hasattr(args, 'start') and args.start < 1:
        parser.error('start must be positive')
    try:
        result = {'index': rebuild, 'check': check,
                  'search': lambda: search(args), 'read': lambda: read(args)}[args.command]()
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0 if result.get('ok', True) else 1
    except (ValueError, OSError, KeyError) as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
