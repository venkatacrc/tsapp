"""Transliteration between Devanagari, Telugu script and IAST.

Devanagari (U+0900–097F) and Telugu (U+0C00–0C7F) share one layout, so most letters
convert by a fixed offset. IAST needs the inherent-vowel rule: a consonant reads "a"
unless a vowel sign or virāma follows it.
"""
import re

OFFSET = 0x0C00 - 0x0900
DEVA_RE = re.compile('[\u0900-\u097F]')
DEVA_RUN_RE = re.compile('[\u0900-\u097F\u200c\u200d]+')

# Devanagari code points with no Telugu counterpart at the same offset.
DEVA_TO_TE_SPECIAL = {
    'ॐ': 'ఓం',
    '।': '।',
    '॥': '॥',
    '\u093C': '',      # nukta
    '\u0945': '\u0C46',  # candra e
    '\u0949': '\u0C4A',  # candra o
}

VOWELS = {
    'अ': 'a', 'आ': 'ā', 'इ': 'i', 'ई': 'ī', 'उ': 'u', 'ऊ': 'ū', 'ऋ': 'ṛ', 'ॠ': 'ṝ',
    'ऌ': 'ḷ', 'ॡ': 'ḹ', 'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au', 'ऎ': 'ĕ', 'ऒ': 'ŏ',
}
SIGNS = {
    'ा': 'ā', 'ि': 'i', 'ी': 'ī', 'ु': 'u', 'ू': 'ū', 'ृ': 'ṛ', 'ॄ': 'ṝ', 'ॢ': 'ḷ', 'ॣ': 'ḹ',
    'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au', 'ॆ': 'ĕ', 'ॊ': 'ŏ',
}
CONSONANTS = {
    'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ṅ',
    'च': 'c', 'छ': 'ch', 'ज': 'j', 'झ': 'jh', 'ञ': 'ñ',
    'ट': 'ṭ', 'ठ': 'ṭh', 'ड': 'ḍ', 'ढ': 'ḍh', 'ण': 'ṇ',
    'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
    'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm',
    'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v',
    'श': 'ś', 'ष': 'ṣ', 'स': 's', 'ह': 'h', 'ळ': 'ḻ', 'ऱ': 'ṟ', 'ऴ': 'ẓ',
}
OTHER = {
    'ं': 'ṃ', 'ः': 'ḥ', 'ँ': 'm̐', 'ऽ': "'", 'ॐ': 'oṃ', '।': '|', '॥': '||',
    '्': '', '\u093C': '', '\u200c': '', '\u200d': '',
}
DIGITS = {chr(0x0966 + i): str(i) for i in range(10)}
VIRAMA = '्'


def deva_to_telugu(text):
    out = []
    for ch in text:
        if ch in DEVA_TO_TE_SPECIAL:
            out.append(DEVA_TO_TE_SPECIAL[ch])
        elif '\u0900' <= ch <= '\u097F':
            out.append(chr(ord(ch) + OFFSET))
        else:
            out.append(ch)
    return ''.join(out)


def deva_to_iast(text):
    out = []
    chars = list(text)
    i = 0
    while i < len(chars):
        ch = chars[i]
        if ch in CONSONANTS:
            out.append(CONSONANTS[ch])
            j = i + 1
            while j < len(chars) and chars[j] == '\u093C':
                j += 1
            nxt = chars[j] if j < len(chars) else ''
            if nxt == VIRAMA:
                i = j + 1
                continue
            if nxt in SIGNS:
                out.append(SIGNS[nxt])
                i = j + 1
                continue
            out.append('a')
            i = j
            continue
        if ch in VOWELS:
            out.append(VOWELS[ch])
        elif ch in SIGNS:
            out.append(SIGNS[ch])
        elif ch in OTHER:
            out.append(OTHER[ch])
        elif ch in DIGITS:
            out.append(DIGITS[ch])
        else:
            out.append(ch)
        i += 1
    return ''.join(out)


def has_deva(text):
    return bool(text and DEVA_RE.search(text))


def iast_or_none(text):
    """IAST for text containing Devanagari; None otherwise. [[…]] markers are dropped."""
    if not has_deva(text):
        return None
    return deva_to_iast(text.replace('[[', '').replace(']]', ''))


if __name__ == '__main__':
    for s in ['कर्मण्येवाधिकारस्ते मा फलेषु कदाचन ।', 'ॐ नमो नारायणाय', 'सङ्गोऽस्त्वकर्मणि ॥ ४७॥', 'कॢप्त']:
        print(s, '|', deva_to_telugu(s), '|', deva_to_iast(s))
