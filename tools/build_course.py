#!/usr/bin/env python3
"""Builds course.json for the Mac and web apps from the lesson files in content/.

    python3 tools/build_course.py [--deck PATH] [--strict]

content/NN_unit/_unit.txt holds the unit's @title and @summary. Every other .txt file in a
unit folder is one lesson, ordered by its numeric prefix. The lesson markup:

    @title  Lesson title                 (header)
    @summary One line                     (header)
    ## Heading / ### Sub-heading
    Plain paragraphs (blank line ends one). **bold**, *italic*. [[x]] keeps x in its script.
    - list item / 1. numbered item
    | table | header |  then  |---|---|  then rows
    > [memory|telugu|compare|sutra|warning|note] Title :: text      (more lines start with >)
    @nocards / @literal                   (modifiers for the next block)
    @ex gita:2:47 ... @end                (worked sentence or verse; see parse_example)
    @quiz ... @end                        (q: / * right / - wrong / why:)

Verse references (gita:CH:N, vs:GROUP:LABEL) take their text and meanings from the
sloka_words deck, so quotations match the texts used there. Referenced verses are cached in
content/verses.json so the course still builds without that repo.
"""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from lipi import deva_to_iast, has_deva, iast_or_none  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, 'content')
CACHE = os.path.join(CONTENT, 'verses.json')
OUTPUTS = [
    os.path.join(ROOT, 'app', 'Sources', 'Sopanam', 'Resources', 'course.json'),
    os.path.join(ROOT, 'web', 'course.json'),
]
DEFAULT_DECK = os.path.join(os.path.dirname(ROOT), 'sloka_words', 'app', 'Sources', 'SlokaWords',
                            'Resources', 'words.json')
TIP_KINDS = {'memory', 'telugu', 'compare', 'sutra', 'warning', 'note'}
NUMERALS = re.compile(r'\s*॥\s*[०-९0-9]+\s*॥\s*$')
MIXED_SCRIPT = re.compile(r'\S*(?:[\u0900-\u097F][\u0C00-\u0C7F]|[\u0C00-\u0C7F][\u0900-\u097F])\S*')

warnings = []


def warn(where, msg):
    warnings.append(f'{where}: {msg}')


def clean(s):
    return re.sub(r'\s+', ' ', s).strip()


# ---- verses ----

class Verses:
    def __init__(self, deck_path):
        self.deck = {}
        self.cache = {}
        if os.path.exists(CACHE):
            self.cache = json.load(open(CACHE, encoding='utf-8'))
        if deck_path and os.path.exists(deck_path):
            for v in json.load(open(deck_path, encoding='utf-8'))['verses']:
                self.deck[v['id']] = {
                    'label': v['label'],
                    'deva': [NUMERALS.sub(' ॥', l).strip() for l in v['deva']],
                    'te_meaning': v.get('te_meaning', ''),
                    'en_meaning': re.sub(r'^[-–\s]+', '', v.get('en_meaning') or ''),
                    'speaker': (v.get('speaker') or {}).get('deva'),
                }
        self.used = {}

    def get(self, ref):
        v = self.deck.get(ref) or self.cache.get(ref)
        if v:
            self.used[ref] = v
        return v

    def save_cache(self):
        if not self.deck:
            return
        merged = dict(sorted(self.used.items()))
        with open(CACHE, 'w', encoding='utf-8') as f:
            json.dump(merged, f, ensure_ascii=False, indent=1)
            f.write('\n')


def verse_label(ref, v):
    parts = ref.split(':')
    if parts[0] == 'gita' and parts[1] == '0':
        return f'Gītā Dhyānam {parts[2]}'
    if parts[0] == 'gita':
        return f'Gītā {parts[1]}.{parts[2]}'
    if parts[0] == 'vs':
        tail = parts[2]
        if parts[1] == 'stotram':
            return f'Viṣṇu Sahasranāmam · Stotram {tail}'
        return f'Viṣṇu Sahasranāmam · {tail}'
    return v.get('label', ref) if v else ref


def comparable(s):
    return re.sub(r'[\s।॥ऽ०-९0-9\-–—,.;:|\'’]+', '', s)


# ---- inline helpers ----

def lines_of(value):
    return [clean(l) for l in value.split(' / ') if clean(l)]


def parse_words(value):
    out = []
    for item in value.split(';'):
        if not item.strip():
            continue
        if '=' in item:
            term, meaning = item.split('=', 1)
        else:
            term, meaning = item, ''
        term, meaning = clean(term), clean(meaning)
        out.append([term, meaning, iast_or_none(term) or ''])
    return out


# ---- blocks ----

def parse_example(head, body, where, verses):
    """@ex [ref] then fields, one per line:
    sa: line / line       the Sanskrit (omit for a verse ref to use the deck text)
    split: …              pada-ccheda (sandhi undone)
    anvaya: …             prose order
    w: term = meaning; term = meaning   (word by word, repeatable)
    te: … / en: …         Telugu / English meaning (deck meanings used when omitted)
    note: …               grammar notes (repeatable)
    src: …                label override; meter: … metre name
    """
    ref = head.strip() or None
    ex = {'t': 'ex', 'ref': ref, 'sa': [], 'words': [], 'notes': []}
    for raw in body:
        if not raw.strip():
            continue
        m = re.match(r'(\w+):\s?(.*)$', raw.strip())
        if not m:
            warn(where, f'unreadable @ex line: {raw!r}')
            continue
        key, value = m.group(1), m.group(2).strip()
        if key == 'sa':
            ex['sa'] += lines_of(value)
        elif key == 'w':
            ex['words'] += parse_words(value)
        elif key == 'note':
            ex['notes'].append(value)
        elif key in ('split', 'anvaya', 'te', 'en', 'src', 'meter', 'title'):
            ex[key] = value
        else:
            warn(where, f'unknown @ex field {key}')
    if ref:
        v = verses.get(ref)
        if not v:
            warn(where, f'verse {ref} not found in deck or cache')
        else:
            if ex['sa']:
                if comparable(''.join(ex['sa'])) != comparable(''.join(v['deva'])):
                    warn(where, f'{ref} text differs from the deck:\n    mine: {" / ".join(ex["sa"])}'
                                f'\n    deck: {" / ".join(v["deva"])}')
            else:
                ex['sa'] = v['deva']
            ex.setdefault('te', v.get('te_meaning') or '')
            ex.setdefault('en', v.get('en_meaning') or '')
            ex.setdefault('src', verse_label(ref, v))
            if v.get('speaker'):
                ex['speaker'] = v['speaker']
    if not ex['sa']:
        warn(where, '@ex without Sanskrit text')
    ex['iast'] = [deva_to_iast(l) for l in ex['sa']]
    for key in ('split', 'anvaya'):
        if ex.get(key):
            ex[key + '_iast'] = deva_to_iast(ex[key])
    return ex


def parse_quiz(body, where):
    items, cur = [], None

    def flush():
        nonlocal cur
        if cur:
            if cur['answer'] is None or len(cur['options']) < 2:
                warn(where, f'quiz item needs one * answer and 2+ options: {cur["q"][:40]}')
            else:
                items.append(cur)
        cur = None

    for raw in body:
        line = raw.strip()
        if not line:
            continue
        if line.startswith('q:'):
            flush()
            cur = {'q': clean(line[2:]), 'options': [], 'answer': None, 'why': ''}
        elif cur is None:
            warn(where, f'quiz line before q: {line!r}')
        elif line.startswith('* '):
            cur['answer'] = len(cur['options'])
            cur['options'].append(clean(line[2:]))
        elif line.startswith('- '):
            cur['options'].append(clean(line[2:]))
        elif line.startswith('why:'):
            cur['why'] = clean(line[4:])
        else:
            cur['q'] += ' ' + clean(line)
    flush()
    return items


def split_row(line):
    line = line.strip()
    if line.startswith('|'):
        line = line[1:]
    if line.endswith('|'):
        line = line[:-1]
    return [clean(c) for c in line.split('|')]


def parse_table(rows, where, literal):
    head = split_row(rows[0])
    body = []
    for r in rows[1:]:
        cells = split_row(r)
        if all(re.fullmatch(r':?-{2,}:?', c) for c in cells if c):
            continue
        if len(cells) < len(head):
            cells += [''] * (len(head) - len(cells))
        elif len(cells) > len(head):
            warn(where, f'table row has {len(cells)} cells, header {len(head)}: {r[:50]}')
            cells = cells[:len(head)]
        body.append(cells)
    t = {'t': 'table', 'head': head, 'rows': body}
    if literal:
        t['lit'] = True
    else:
        iast = [[iast_or_none(c) for c in row] for row in body]
        if any(any(x for x in row) for row in iast):
            t['iast'] = iast
    return t


def parse_lesson(path, verses):
    where = os.path.relpath(path, ROOT)
    lines = open(path, encoding='utf-8').read().split('\n')
    for n, line in enumerate(lines, 1):
        for word in MIXED_SCRIPT.findall(line):
            warn(f'{where}:{n}', f'Devanagari and Telugu letters in one word: {word}')
    meta = {'title': '', 'summary': ''}
    blocks, quiz = [], []
    para, items, tip, table = [], None, None, []
    mods = set()
    lesson_literal = False

    def take_mods():
        nonlocal mods
        m, mods = mods, set()
        return m

    def flush():
        nonlocal para, items, tip, table
        if para:
            m = take_mods()
            b = {'t': 'p', 'text': clean(' '.join(para))}
            if 'literal' in m or lesson_literal:
                b['lit'] = True
            blocks.append(b)
            para = []
        if items is not None:
            kind, entries = items
            m = take_mods()
            b = {'t': kind, 'items': [clean(e) for e in entries]}
            if 'literal' in m or lesson_literal:
                b['lit'] = True
            blocks.append(b)
            items = None
        if tip is not None:
            m = take_mods()
            paras = [clean(p) for p in tip['text'] if clean(p)]
            b = {'t': 'tip', 'kind': tip['kind'], 'title': tip['title'], 'text': paras}
            if 'literal' in m or lesson_literal:
                b['lit'] = True
            if 'nocards' in m:
                b['nocards'] = True
            blocks.append(b)
            tip = None
        if table:
            m = take_mods()
            t = parse_table(table, where, 'literal' in m or lesson_literal)
            if 'nocards' in m:
                t['nocards'] = True
            blocks.append(t)
            table = []

    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.rstrip()
        s = line.strip()
        i += 1
        if s.startswith('@title '):
            meta['title'] = clean(s[7:])
            continue
        if s.startswith('@summary '):
            meta['summary'] = clean(s[9:])
            continue
        if s == '@lesson-literal':
            lesson_literal = True
            continue
        if s in ('@nocards', '@literal'):
            flush()
            mods.add(s[1:])
            continue
        if s.startswith('@ex') or s == '@quiz':
            flush()
            body = []
            while i < len(lines) and lines[i].strip() != '@end':
                body.append(lines[i])
                i += 1
            if i >= len(lines):
                warn(where, f'{s} without @end')
            i += 1
            if s == '@quiz':
                quiz += parse_quiz(body, where)
            else:
                ex = parse_example(s[3:], body, where, verses)
                if 'nocards' in take_mods():
                    ex['nocards'] = True
                blocks.append(ex)
            continue
        if s.startswith('#'):
            flush()
            m = re.match(r'(#{2,3})\s+(.*)', s)
            if not m:
                warn(where, f'bad heading {s!r}')
                continue
            blocks.append({'t': 'h2' if len(m.group(1)) == 2 else 'h3', 'text': clean(m.group(2))})
            take_mods()
            continue
        if s.startswith('|'):
            if not table and (para or items is not None or tip is not None):
                flush()
            table.append(s)
            continue
        if table:
            flush()
        if s.startswith('>'):
            content = s[1:].strip()
            m = re.match(r'\[(\w+)\]\s*(.*)$', content)
            if m and m.group(1) in TIP_KINDS:
                if para or items is not None or tip is not None:
                    flush()
                rest = m.group(2)
                title, text = (rest.split('::', 1) + [''])[:2] if '::' in rest else ('', rest)
                tip = {'kind': m.group(1), 'title': clean(title), 'text': [text]}
            elif tip is not None:
                if content:
                    tip['text'][-1] += ' ' + content
                else:
                    tip['text'].append('')
            else:
                warn(where, f'> line outside a tip: {s[:40]}')
            continue
        if tip is not None and s:
            flush()
        if not s:
            flush()
            continue
        m = re.match(r'(-|\d+\.)\s+(.*)$', s)
        if m:
            kind = 'ul' if m.group(1) == '-' else 'ol'
            if para:
                flush()
            if items is None or items[0] != kind:
                if items is not None:
                    flush()
                items = (kind, [])
            items[1].append(m.group(2))
            continue
        if items is not None and raw.startswith('  '):
            items[1][-1] += ' ' + s
            continue
        if items is not None:
            flush()
        para.append(s)
    flush()
    if not meta['title']:
        warn(where, 'missing @title')
    return meta, blocks, quiz


# ---- cards ----

def cell(head, text):
    c = {'head': head, 'text': text}
    iast = iast_or_none(text)
    if iast:
        c['iast'] = iast
    return c


def cards_for(lesson, unit_id):
    cards, ids = [], set()
    context = ''

    def add(prompt, answer, kind, lit=False):
        base = lesson['id'] + ':' + clean(prompt['text'])[:48]
        cid, n = base, 2
        while cid in ids:
            cid = f'{base}#{n}'
            n += 1
        ids.add(cid)
        card = {'id': cid, 'unit': unit_id, 'lesson': lesson['id'], 'context': context,
                'kind': kind, 'prompt': prompt, 'answer': answer}
        if lit:
            card['lit'] = True
        cards.append(card)

    for b in lesson['blocks']:
        if b['t'] in ('h2', 'h3'):
            context = b['text']
        elif b['t'] == 'table' and not b.get('nocards'):
            for row in b['rows']:
                first = next((k for k, v in enumerate(row) if v and v not in ('—', '-', '–')), None)
                if first is None:
                    continue
                answer = [cell(b['head'][k], v) for k, v in enumerate(row)
                          if k != first and v and v not in ('—', '-', '–')]
                if answer:
                    add(cell(b['head'][first], row[first]), answer, 'table', b.get('lit', False))
        elif b['t'] == 'ex' and not b.get('nocards'):
            answer = []
            if b.get('split'):
                answer.append(cell('పదచ్ఛేదం · word split', b['split']))
            if b.get('te'):
                answer.append(cell('తెలుగు భావం', b['te']))
            if b.get('en'):
                answer.append(cell('English', b['en']))
            if b['words']:
                answer.append(cell('ప్రతిపదార్థం · word by word',
                                   '; '.join(f'{t} = {m}' if m else t for t, m, _ in b['words'])))
            for note in b['notes'][:3]:
                answer.append(cell('వ్యాకరణం · grammar', note))
            if answer:
                prompt = cell(b.get('src') or b.get('title') or 'సంస్కృతం', ' / '.join(b['sa']))
                add(prompt, answer, 'example')
        elif b['t'] == 'tip' and b['kind'] == 'memory' and b['title'] and not b.get('nocards'):
            add(cell('జ్ఞాపకం · memory aid', b['title']), [cell('', ' '.join(b['text']))], 'memory',
                b.get('lit', False))
    return cards


# ---- course ----

def number_prefix(name):
    m = re.match(r'(\d+)', name)
    return int(m.group(1)) if m else 9999


def read_meta(path):
    meta = {'title': '', 'summary': ''}
    if os.path.exists(path):
        for line in open(path, encoding='utf-8'):
            line = line.strip()
            for key in meta:
                if line.startswith(f'@{key} '):
                    meta[key] = clean(line[len(key) + 2:])
    return meta


def build(deck_path):
    verses = Verses(deck_path)
    course = read_meta(os.path.join(CONTENT, 'course.txt'))
    units, cards = [], []
    lesson_ids = set()
    unit_dirs = sorted((d for d in os.listdir(CONTENT)
                        if os.path.isdir(os.path.join(CONTENT, d)) and re.match(r'\d+_', d)),
                       key=number_prefix)
    for unit_num, d in enumerate(unit_dirs):
        udir = os.path.join(CONTENT, d)
        umeta = read_meta(os.path.join(udir, '_unit.txt'))
        uid = re.sub(r'^\d+_', '', d)
        unit = {'id': uid, 'num': unit_num, 'title': umeta['title'], 'summary': umeta['summary'],
                'lessons': []}
        files = sorted((f for f in os.listdir(udir) if f.endswith('.txt') and not f.startswith('_')),
                       key=number_prefix)
        for lnum, f in enumerate(files, 1):
            lid = re.sub(r'^\d+_', '', f[:-4])
            if lid in lesson_ids:
                warn(f, f'duplicate lesson id {lid}')
            lesson_ids.add(lid)
            meta, blocks, quiz = parse_lesson(os.path.join(udir, f), verses)
            lesson = {'id': lid, 'num': f'{unit_num}.{lnum}', 'title': meta['title'],
                      'summary': meta['summary'], 'blocks': blocks, 'quiz': quiz}
            unit['lessons'].append(lesson)
            cards += cards_for(lesson, uid)
        if unit['lessons']:
            units.append(unit)
    course['units'] = units
    course['cards'] = cards
    verses.save_cache()
    return course


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--deck', default=DEFAULT_DECK, help='sloka_words words.json (verse texts)')
    ap.add_argument('--strict', action='store_true', help='fail on any warning')
    args = ap.parse_args()
    course = build(args.deck)
    data = json.dumps(course, ensure_ascii=False, separators=(',', ':'))
    for out in OUTPUTS:
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, 'w', encoding='utf-8') as f:
            f.write(data)
    lessons = [l for u in course['units'] for l in u['lessons']]
    blocks = [b for l in lessons for b in l['blocks']]
    print(f"{len(course['units'])} units, {len(lessons)} lessons, {len(blocks)} blocks, "
          f"{sum(b['t'] == 'ex' for b in blocks)} worked examples, {sum(b['t'] == 'table' for b in blocks)} tables, "
          f"{len(course['cards'])} cards, {sum(len(l['quiz']) for l in lessons)} quiz questions, "
          f"{len(data) // 1024} KB")
    for w in warnings:
        print('warning:', w, file=sys.stderr)
    if args.strict and warnings:
        sys.exit(1)


if __name__ == '__main__':
    main()
