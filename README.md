# సంస్కృత సోపానం · Sanskrit Sopanam

A complete Sanskrit course for native Telugu speakers. It starts from the letters, using the Telugu script you already read, then builds a bridge from Telugu grammar to Sanskrit grammar. From there it teaches every part of Classical Sanskrit grammar, and ends with graded readings: everyday sentences, subhāṣitas, the daily prayers, the Bhagavad Gītā, the Viṣṇu Sahasranāmam, the great stotras and Bhaja Govindam.

The same course runs in two apps:

- **Mac:** a SwiftUI app (`app/`), built into `build/Sopanam.app`.
- **Pixel and other phones:** an offline web app (`web/`) that installs to the home screen like a native app.

Both apps read one file, `course.json`, which is compiled from the plain-text lessons in `content/`.

## What is in the course

| Unit | Topic |
|---|---|
| 0 | How to use the course; the Sanskrit you already know through Telugu |
| 1 | Script and sounds: Telugu ↔ Devanagari ↔ IAST, pronunciation, syllable weight, Māheśvara sūtras |
| 2 | The Telugu–Sanskrit bridge: genders, cases, verbs, sentences; what only Telugu has and what only Sanskrit has |
| 3 | First sentences: greetings, daily routine, commands, past and future, dialogues |
| 4 | Nouns: every declension class, irregular nouns, adjectives |
| 5 | Pronouns and numbers |
| 6 | Verbs: the ten gaṇas, all ten lakāras, passive, derived verbs, the 22 prefixes |
| 7 | Participles, absolutives, infinitives, gerundives, kṛt suffixes |
| 8 | Sandhi: vowel, consonant, nasal, visarga, and how to split a verse |
| 9 | Compounds, from two words to Sahasranāma names |
| 10 | Taddhita suffixes and indeclinables |
| 11 | Syntax: kārakas, case government, absolute constructions, anvaya |
| 12 | Metre: anuṣṭubh, triṣṭubh and the classical metres of the stotras |
| 13 | Readers: subhāṣitas, prayers, three Gītā readers, Gītā Dhyānam, Viṣṇu Sahasranāmam (opening, names, closing), stotras, Bhaja Govindam |
| 14 | Memory: techniques, anchor verses, cheat sheets, a twelve-month study plan |

Every lesson includes the following:

- tables
- worked verses with word split, prose order and word-by-word Telugu meanings
- Telugu comparisons
- memory aids
- a quiz

Every table row, worked verse and memory aid also becomes a flash card, scheduled by spaced repetition.

## Building

You need Python 3. The Mac app also needs Xcode or the Command Line Tools (Swift 5.9 or later) on macOS 14 or later.

```sh
python3 tools/build_course.py      # content/ → app/…/Resources/course.json and web/course.json
scripts/build_app.sh               # also builds build/Sopanam.app
open build/Sopanam.app
```

`build_course.py` prints a warning for each problem it finds and still writes the output, unless you pass `--strict`. The checks include:

- unknown fields and unclosed blocks
- table rows with the wrong number of cells
- quiz items without exactly one right answer
- a word that mixes Devanagari and Telugu letters
- a quoted verse that differs from the deck

Verse references such as `gita:2:47` take their text from the sloka_words deck at `../sloka_words`. They are also cached in `content/verses.json`, so the course builds without that repository.

## Running the web app locally

```sh
python3 -m http.server 8765 -d web
```

Then open <http://localhost:8765>.

## Installing on a Pixel phone

The web app is published as the `sopanam/` folder of the bhakti GitHub Pages site.

1. Run `scripts/publish_web.sh` (or `scripts/publish_web.sh path/to/bhakti`). It rebuilds the course, copies the app into `bhakti/sopanam/`, and gives the service worker a new cache version.
2. Commit and push the bhakti repository.
3. On the phone, open <https://venkatacrc.github.io/bhakti/sopanam/> in Chrome.
4. Open the Chrome menu and choose **Add to Home screen**, then **Install**.

The app then opens full screen from its icon and works offline. Progress (flash card boxes, quiz scores, settings) is kept on the device. After a new publish, the app updates itself the next time it is opened online.

## Writing lessons

Each unit is a folder `content/NN_slug/`. It holds a `_unit.txt` with the unit's `@title` and `@summary`, and one `.txt` file per lesson, ordered by the numeric prefix. Lesson IDs come from the file name and must be unique across the course.

```text
@title తెలుగు శీర్షిక · English title
@summary One line shown in the lesson list.

## Heading
A paragraph with **bold** and *italic*.

| Header | Header |
|---|---|
| row | row |

> [memory] Title :: The memory aid. Kinds: memory, telugu, compare, sutra, warning, note.

@nocards
| A table that should not become flash cards |
|---|

@ex gita:2:47
split: कर्मणि एव अधिकारः ते
anvaya: ते कर्मणि एव अधिकारः …
w: कर्मणि = కర్మయందు; एव = మాత్రమే; …
note: A grammar note. Repeat note: lines as needed.
@end

@ex
title: A sentence of your own
sa: रामः वनं गच्छति ।
te: రాముడు అడవికి వెళ్తున్నాడు.
en: Rāma goes to the forest.
@end

@quiz
q: The question?
* the right answer
- a wrong answer
- another wrong answer
why: The explanation shown after answering.
@end
```

The full markup, with every `@ex` field, is documented at the top of `tools/build_course.py`.

## Project layout

```text
content/            lesson sources, one folder per unit; verses.json caches quoted verses
tools/              build_course.py (the compiler) and lipi.py (script conversion)
app/                Swift package for the Mac app (SwiftUI, macOS 14)
web/                the phone app: index.html, app.js, app.css, lipi.js, sw.js, manifest
scripts/            build_app.sh, publish_web.sh, make_icon.swift
build/              build output (not committed)
```
