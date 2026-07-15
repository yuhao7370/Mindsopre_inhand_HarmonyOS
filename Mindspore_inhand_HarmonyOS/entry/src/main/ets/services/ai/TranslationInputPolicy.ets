export type TranslationInputSegmentKind = 'model' | 'protected';

export interface TranslationInputSegment {
  readonly kind: TranslationInputSegmentKind;
  readonly text: string;
}

interface OcrMatch {
  readonly end: number;
  readonly normalized: string;
}

interface ProtectedRange {
  readonly start: number;
  readonly end: number;
}

const URL_TRAILING_PUNCTUATION: string = '.,;!?)]}';

export function normalizeOcrLetterSpacing(text: string): string {
  let normalized = '';
  let index = 0;
  while (index < text.length) {
    const match = matchOcrSequence(text, index);
    if (match === undefined) {
      normalized += text[index];
      index++;
    } else {
      normalized += match.normalized;
      index = match.end;
    }
  }
  return normalized;
}

export function prepareTranslationInput(text: string): Array<TranslationInputSegment> {
  const normalized = normalizeOcrLetterSpacing(text);
  const ranges = protectedRanges(normalized);
  const segments: Array<TranslationInputSegment> = [];
  let cursor = 0;
  for (let index = 0; index < ranges.length; index++) {
    appendSegment(segments, 'model', normalized.substring(cursor, ranges[index].start));
    appendSegment(segments, 'protected', normalized.substring(ranges[index].start, ranges[index].end));
    cursor = ranges[index].end;
  }
  appendSegment(segments, 'model', normalized.substring(cursor));
  return segments;
}

export function isTranslatableTranslationText(text: string): boolean {
  for (let index = 0; index < text.length; index++) {
    const code = text.charCodeAt(index);
    if (isAsciiLetter(code) || (code >= 0x3400 && code <= 0x4DBF) ||
      (code >= 0x4E00 && code <= 0x9FFF) || (code >= 0xF900 && code <= 0xFAFF)) {
      return true;
    }
  }
  return false;
}

function matchOcrSequence(text: string, start: number): OcrMatch | undefined {
  if (start > 0 && isAsciiLetter(text.charCodeAt(start - 1))) {
    return undefined;
  }
  const first = matchOcrWord(text, start);
  if (first === undefined) {
    return undefined;
  }
  let end = first.end;
  let normalized = first.normalized;
  while (end < text.length) {
    let afterSpaces = end;
    while (afterSpaces < text.length && text[afterSpaces] === ' ') {
      afterSpaces++;
    }
    const spaceCount = afterSpaces - end;
    if (spaceCount < 2) {
      break;
    }
    const next = matchOcrWord(text, afterSpaces);
    if (next !== undefined) {
      normalized += ` ${next.normalized}`;
      end = next.end;
      continue;
    }
    if (afterSpaces < text.length && !isWhitespace(text.charCodeAt(afterSpaces))) {
      normalized += ' ';
      end = afterSpaces;
    }
    break;
  }
  return { end: end, normalized: normalized };
}

function matchOcrWord(text: string, start: number): OcrMatch | undefined {
  if (start >= text.length || !isAsciiLetter(text.charCodeAt(start))) {
    return undefined;
  }
  let normalized = text[start];
  let count = 1;
  let cursor = start + 1;
  while (cursor + 1 < text.length && text[cursor] === ' ' &&
    isAsciiLetter(text.charCodeAt(cursor + 1))) {
    normalized += text[cursor + 1];
    count++;
    cursor += 2;
  }
  if (count < 3 || (cursor < text.length && isAsciiLetter(text.charCodeAt(cursor)))) {
    return undefined;
  }
  return { end: cursor, normalized: normalized };
}

function protectedRanges(text: string): Array<ProtectedRange> {
  const ranges: Array<ProtectedRange> = [];
  let index = 0;
  while (index < text.length) {
    let end = matchUrlEnd(text, index);
    if (end < 0) {
      end = matchEmailEnd(text, index);
    }
    if (end < 0) {
      end = matchCodeEnd(text, index);
    }
    if (end > index) {
      ranges.push({ start: index, end: end });
      index = end;
    } else {
      index++;
    }
  }
  return ranges;
}

function matchUrlEnd(text: string, start: number): number {
  let prefixLength = 0;
  if (startsWithAsciiIgnoreCase(text, start, 'http://')) {
    prefixLength = 7;
  } else if (startsWithAsciiIgnoreCase(text, start, 'https://')) {
    prefixLength = 8;
  } else {
    return -1;
  }
  let end = start + prefixLength;
  while (end < text.length && !isWhitespace(text.charCodeAt(end)) && text[end] !== '<' && text[end] !== '>') {
    end++;
  }
  while (end > start + prefixLength && URL_TRAILING_PUNCTUATION.indexOf(text[end - 1]) >= 0) {
    end--;
  }
  return end > start + prefixLength ? end : -1;
}

function startsWithAsciiIgnoreCase(text: string, start: number, expected: string): boolean {
  if (start + expected.length > text.length) {
    return false;
  }
  for (let index = 0; index < expected.length; index++) {
    let code = text.charCodeAt(start + index);
    if (code >= 0x41 && code <= 0x5A) {
      code += 0x20;
    }
    if (code !== expected.charCodeAt(index)) {
      return false;
    }
  }
  return true;
}

function matchEmailEnd(text: string, start: number): number {
  let cursor = start;
  while (cursor < text.length && isEmailLocalCharacter(text.charCodeAt(cursor))) {
    cursor++;
  }
  if (cursor === start || cursor >= text.length || text[cursor] !== '@') {
    return -1;
  }
  cursor++;
  const firstLabelEnd = matchDomainLabelEnd(text, cursor);
  if (firstLabelEnd < 0) {
    return -1;
  }
  cursor = firstLabelEnd;
  let dotCount = 0;
  while (cursor < text.length && text[cursor] === '.') {
    const nextLabelEnd = matchDomainLabelEnd(text, cursor + 1);
    if (nextLabelEnd < 0) {
      break;
    }
    dotCount++;
    cursor = nextLabelEnd;
  }
  return dotCount > 0 ? cursor : -1;
}

function matchDomainLabelEnd(text: string, start: number): number {
  if (start >= text.length || !isAsciiAlphanumeric(text.charCodeAt(start))) {
    return -1;
  }
  let cursor = start + 1;
  while (cursor < text.length &&
    (isAsciiAlphanumeric(text.charCodeAt(cursor)) || text[cursor] === '-')) {
    cursor++;
  }
  const length = cursor - start;
  if (length > 63 || !isAsciiAlphanumeric(text.charCodeAt(cursor - 1))) {
    return -1;
  }
  return cursor;
}

function matchCodeEnd(text: string, start: number): number {
  if ((start > 0 && isAsciiAlphanumeric(text.charCodeAt(start - 1))) ||
    start >= text.length || !isAsciiAlphanumeric(text.charCodeAt(start))) {
    return -1;
  }
  let cursor = start;
  let hasLetter = false;
  let hasDigit = false;
  let hasUnderscore = false;
  while (cursor < text.length && isAsciiAlphanumeric(text.charCodeAt(cursor))) {
    hasLetter = hasLetter || isAsciiLetter(text.charCodeAt(cursor));
    hasDigit = hasDigit || isAsciiDigit(text.charCodeAt(cursor));
    cursor++;
  }
  let separatorCount = 0;
  while (cursor + 1 < text.length && isCodeSeparator(text[cursor]) &&
    isAsciiAlphanumeric(text.charCodeAt(cursor + 1))) {
    hasUnderscore = hasUnderscore || text[cursor] === '_';
    separatorCount++;
    cursor++;
    while (cursor < text.length && isAsciiAlphanumeric(text.charCodeAt(cursor))) {
      hasLetter = hasLetter || isAsciiLetter(text.charCodeAt(cursor));
      hasDigit = hasDigit || isAsciiDigit(text.charCodeAt(cursor));
      cursor++;
    }
  }
  if (separatorCount === 0 || (cursor < text.length && isAsciiAlphanumeric(text.charCodeAt(cursor))) ||
    (!hasUnderscore && !(hasLetter && hasDigit))) {
    return -1;
  }
  return cursor;
}

function appendSegment(
  segments: Array<TranslationInputSegment>,
  kind: TranslationInputSegmentKind,
  text: string
): void {
  if (text.length === 0) {
    return;
  }
  if (segments.length > 0 && segments[segments.length - 1].kind === kind) {
    const previous = segments[segments.length - 1];
    segments[segments.length - 1] = { kind: kind, text: previous.text + text };
  } else {
    segments.push({ kind: kind, text: text });
  }
}

function isAsciiLetter(code: number): boolean {
  return (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
}

function isAsciiDigit(code: number): boolean {
  return code >= 0x30 && code <= 0x39;
}

function isAsciiAlphanumeric(code: number): boolean {
  return isAsciiLetter(code) || isAsciiDigit(code);
}

function isCodeSeparator(character: string): boolean {
  return character === '-' || character === '_' || character === '.' || character === '/' || character === ':';
}

function isEmailLocalCharacter(code: number): boolean {
  if (isAsciiAlphanumeric(code)) {
    return true;
  }
  return code === 0x21 || code === 0x23 || code === 0x24 || code === 0x25 || code === 0x26 ||
    code === 0x27 || code === 0x2A || code === 0x2B || code === 0x2D || code === 0x2E || code === 0x2F ||
    code === 0x3D || code === 0x3F || code === 0x5E || code === 0x5F || code === 0x60 || code === 0x7B ||
    code === 0x7C || code === 0x7D || code === 0x7E;
}

function isWhitespace(code: number): boolean {
  return code === 0x09 || code === 0x0A || code === 0x0B || code === 0x0C || code === 0x0D ||
    code === 0x20 || code === 0x85 || code === 0xA0 || code === 0x1680 ||
    (code >= 0x2000 && code <= 0x200A) || code === 0x2028 || code === 0x2029 ||
    code === 0x202F || code === 0x205F || code === 0x3000;
}
