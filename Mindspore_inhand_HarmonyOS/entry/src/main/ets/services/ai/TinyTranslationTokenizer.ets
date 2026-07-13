const TOKENIZER_TABLE_VERSION = 'TTOK1';
const PINNED_MODEL_SHA256 = 'e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640';

export const TRANSLATION_EOS_ID: number = 0;
export const TRANSLATION_UNK_ID: number = 1;
export const TRANSLATION_PAD_ID: number = 32000;
export const TRANSLATION_TO_ENGLISH_ID: number = 32001;
export const TRANSLATION_TO_CHINESE_ID: number = 32002;
export const TRANSLATION_MAX_TOKENS: number = 128;

const TRANSLATION_PIECE_CAPACITY = TRANSLATION_MAX_TOKENS - 2;
const SENTENCEPIECE_SPACE = '\u2581';
const SENTENCEPIECE_UNKNOWN_REPLACEMENT = '\u2047';
const NORMAL_PIECE_TYPE = 1;
const UNKNOWN_PIECE_TYPE = 2;
const CONTROL_PIECE_TYPE = 3;

export type TranslationTargetLanguage = 'en' | 'zh';

export interface TranslationChunk {
  readonly normalized: string;
  readonly pieces: Array<string>;
  readonly pieceIds: Array<number>;
  readonly inputIds: Array<number>;
  readonly attentionMask: Array<number>;
  readonly separatorBefore: string;
  readonly separatorAfter: string;
}

interface NormalizationRule {
  readonly source: string;
  readonly target: string;
}

interface RuntimePiece {
  readonly id: number;
  readonly score: number;
  readonly type: number;
  readonly text: string;
}

interface EncodedPieces {
  readonly normalized: string;
  readonly pieces: Array<string>;
  readonly pieceIds: Array<number>;
}

interface PreservedTextRun {
  readonly separator: string;
  readonly content: string;
}

class TranslationTokenizerRuntime {
  readonly minimumScore: number;
  private readonly normalizationByFirstSymbol: Map<string, Array<NormalizationRule>>;
  private readonly normalPiecesByFirstSymbol: Map<string, Array<RuntimePiece>>;
  private readonly piecesById: Map<number, RuntimePiece>;

  constructor(
    minimumScore: number,
    normalizationRules: Array<NormalizationRule>,
    pieces: Array<RuntimePiece>
  ) {
    this.minimumScore = minimumScore;
    this.normalizationByFirstSymbol = new Map<string, Array<NormalizationRule>>();
    this.normalPiecesByFirstSymbol = new Map<string, Array<RuntimePiece>>();
    this.piecesById = new Map<number, RuntimePiece>();
    for (let index = 0; index < normalizationRules.length; index++) {
      const rule = normalizationRules[index];
      const first = firstUnicodeSymbol(rule.source);
      let bucket = this.normalizationByFirstSymbol.get(first);
      if (bucket === undefined) {
        bucket = [];
        this.normalizationByFirstSymbol.set(first, bucket);
      }
      bucket.push(rule);
    }
    this.normalizationByFirstSymbol.forEach((rules: Array<NormalizationRule>) => {
      rules.sort((left: NormalizationRule, right: NormalizationRule): number =>
        right.source.length - left.source.length);
    });
    for (let index = 0; index < pieces.length; index++) {
      const piece = pieces[index];
      this.piecesById.set(piece.id, piece);
      if (piece.type !== NORMAL_PIECE_TYPE) {
        continue;
      }
      const first = firstUnicodeSymbol(piece.text);
      let bucket = this.normalPiecesByFirstSymbol.get(first);
      if (bucket === undefined) {
        bucket = [];
        this.normalPiecesByFirstSymbol.set(first, bucket);
      }
      bucket.push(piece);
    }
    this.normalPiecesByFirstSymbol.forEach((runtimePieces: Array<RuntimePiece>) => {
      runtimePieces.sort((left: RuntimePiece, right: RuntimePiece): number => left.text.length - right.text.length);
    });
  }

  normalize(text: string): string {
    let mapped = '';
    let index = 0;
    while (index < text.length) {
      const symbolLength = unicodeSymbolLengthAt(text, index);
      const first = text.substring(index, index + symbolLength);
      const rules = this.normalizationByFirstSymbol.get(first);
      let selected: NormalizationRule | undefined = undefined;
      if (rules !== undefined) {
        for (let ruleIndex = 0; ruleIndex < rules.length; ruleIndex++) {
          if (text.startsWith(rules[ruleIndex].source, index)) {
            selected = rules[ruleIndex];
            break;
          }
        }
      }
      if (selected !== undefined) {
        mapped += selected.target;
        index += selected.source.length;
      } else {
        mapped += first;
        index += symbolLength;
      }
    }

    let escaped = '';
    let hasOutput = false;
    let pendingSpace = false;
    for (let mappedIndex = 0; mappedIndex < mapped.length;) {
      const symbolLength = unicodeSymbolLengthAt(mapped, mappedIndex);
      const symbol = mapped.substring(mappedIndex, mappedIndex + symbolLength);
      mappedIndex += symbolLength;
      if (symbol === ' ') {
        if (hasOutput) {
          pendingSpace = true;
        }
        continue;
      }
      if (!hasOutput) {
        escaped += SENTENCEPIECE_SPACE;
        hasOutput = true;
      } else if (pendingSpace) {
        escaped += SENTENCEPIECE_SPACE;
      }
      pendingSpace = false;
      escaped += symbol;
    }
    return escaped;
  }

  encode(text: string): EncodedPieces {
    const normalized = this.normalize(text);
    if (normalized.length === 0) {
      return { normalized: '', pieces: [], pieceIds: [] };
    }
    const bestScores: Array<number> = [];
    const previousPositions: Array<number> = [];
    const previousPieces: Array<RuntimePiece | undefined> = [];
    const previousSurfaces: Array<string> = [];
    for (let index = 0; index <= normalized.length; index++) {
      bestScores.push(Number.NEGATIVE_INFINITY);
      previousPositions.push(-1);
      previousPieces.push(undefined);
      previousSurfaces.push('');
    }
    bestScores[0] = 0;

    for (let position = 0; position < normalized.length; position++) {
      if (!Number.isFinite(bestScores[position])) {
        continue;
      }
      const symbolLength = unicodeSymbolLengthAt(normalized, position);
      const first = normalized.substring(position, position + symbolLength);
      const candidates = this.normalPiecesByFirstSymbol.get(first);
      let hasSingleSymbolPiece = false;
      if (candidates !== undefined) {
        for (let candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
          const piece = candidates[candidateIndex];
          if (!normalized.startsWith(piece.text, position)) {
            continue;
          }
          if (piece.text.length === symbolLength) {
            hasSingleSymbolPiece = true;
          }
          updateBestPath(
            bestScores,
            previousPositions,
            previousPieces,
            previousSurfaces,
            position,
            position + piece.text.length,
            piece,
            piece.text
          );
        }
      }
      if (!hasSingleSymbolPiece) {
        const unknown: RuntimePiece = {
          id: TRANSLATION_UNK_ID,
          score: this.minimumScore - 10,
          type: UNKNOWN_PIECE_TYPE,
          text: '<unk>'
        };
        updateBestPath(
          bestScores,
          previousPositions,
          previousPieces,
          previousSurfaces,
          position,
          position + symbolLength,
          unknown,
          first
        );
      }
    }

    const pieces: Array<string> = [];
    const pieceIds: Array<number> = [];
    let position = normalized.length;
    while (position > 0) {
      const piece = previousPieces[position];
      const previous = previousPositions[position];
      if (piece === undefined || previous < 0 || previous >= position) {
        throw new Error('Tokenizer could not encode normalized text');
      }
      pieces.unshift(previousSurfaces[position]);
      pieceIds.unshift(piece.id);
      position = previous;
    }
    return { normalized: normalized, pieces: pieces, pieceIds: pieceIds };
  }

  decode(ids: Array<number>): string {
    let encoded = '';
    for (let index = 0; index < ids.length; index++) {
      const id = ids[index];
      if (id === TRANSLATION_EOS_ID) {
        break;
      }
      if (id === TRANSLATION_PAD_ID || id === TRANSLATION_TO_ENGLISH_ID || id === TRANSLATION_TO_CHINESE_ID) {
        continue;
      }
      if (id === TRANSLATION_UNK_ID) {
        encoded += SENTENCEPIECE_UNKNOWN_REPLACEMENT;
        continue;
      }
      const piece = this.piecesById.get(id);
      if (piece === undefined) {
        throw new Error(`Tokenizer piece ID ${id} is absent`);
      }
      if (piece.type === CONTROL_PIECE_TYPE) {
        continue;
      }
      encoded += piece.text;
    }
    let decoded = encoded.split(SENTENCEPIECE_SPACE).join(' ');
    if (decoded.startsWith(' ')) {
      decoded = decoded.substring(1);
    }
    return decoded;
  }
}

let configuredRuntime: TranslationTokenizerRuntime | undefined = undefined;

export function configureTranslationTokenizer(runtimeTable: string): void {
  configuredRuntime = parseRuntimeTable(runtimeTable);
}

export function resetTranslationTokenizerForTests(): void {
  configuredRuntime = undefined;
}

export function encodeTranslationText(text: string, targetLanguage: string): Array<TranslationChunk> {
  const runtime = requireRuntime();
  const target = normalizeTargetLanguage(targetLanguage);
  const directionId = target === 'en' ? TRANSLATION_TO_ENGLISH_ID : TRANSLATION_TO_CHINESE_ID;
  const chunks: Array<TranslationChunk> = [];
  const runs = splitPreservedNewlines(text);
  let pendingSeparator = '';
  for (let runIndex = 0; runIndex < runs.length; runIndex++) {
    pendingSeparator += runs[runIndex].separator;
    if (runs[runIndex].content.length === 0) {
      continue;
    }
    const encoded = runtime.encode(runs[runIndex].content);
    if (encoded.pieceIds.length === 0) {
      continue;
    }
    for (let offset = 0; offset < encoded.pieceIds.length; offset += TRANSLATION_PIECE_CAPACITY) {
      const end = Math.min(offset + TRANSLATION_PIECE_CAPACITY, encoded.pieceIds.length);
      const pieceIds = encoded.pieceIds.slice(offset, end);
      const pieces = encoded.pieces.slice(offset, end);
      chunks.push(createChunk(
        pieces.join(''),
        pieces,
        pieceIds,
        directionId,
        pendingSeparator,
        ''
      ));
      pendingSeparator = '';
    }
  }
  if (pendingSeparator.length > 0 && chunks.length > 0) {
    const last = chunks[chunks.length - 1];
    chunks[chunks.length - 1] = createChunk(
      last.normalized,
      last.pieces,
      last.pieceIds,
      last.inputIds[0],
      last.separatorBefore,
      pendingSeparator
    );
  }
  return chunks;
}

export function decodeTranslationTokens(ids: Array<number>): string {
  return requireRuntime().decode(ids);
}

export function translationTargetLanguageForText(text: string): TranslationTargetLanguage {
  for (let index = 0; index < text.length; index++) {
    const code = text.charCodeAt(index);
    if ((code >= 0x4E00 && code <= 0x9FA5) ||
      (code >= 0xFF00 && code <= 0xFFEF) ||
      (code >= 0x2E80 && code <= 0x2EFF) ||
      (code >= 0x3000 && code <= 0x303F) ||
      (code >= 0x31C0 && code <= 0x31EF)) {
      return 'en';
    }
  }
  return 'zh';
}

function updateBestPath(
  bestScores: Array<number>,
  previousPositions: Array<number>,
  previousPieces: Array<RuntimePiece | undefined>,
  previousSurfaces: Array<string>,
  start: number,
  end: number,
  piece: RuntimePiece,
  surface: string
): void {
  const score = bestScores[start] + piece.score;
  if (score > bestScores[end]) {
    bestScores[end] = score;
    previousPositions[end] = start;
    previousPieces[end] = piece;
    previousSurfaces[end] = surface;
  }
}

function createChunk(
  normalized: string,
  pieces: Array<string>,
  pieceIds: Array<number>,
  directionId: number,
  separatorBefore: string,
  separatorAfter: string
): TranslationChunk {
  const inputIds: Array<number> = [directionId];
  const attentionMask: Array<number> = [1];
  for (let index = 0; index < pieceIds.length; index++) {
    inputIds.push(pieceIds[index]);
    attentionMask.push(1);
  }
  inputIds.push(TRANSLATION_EOS_ID);
  attentionMask.push(1);
  while (inputIds.length < TRANSLATION_MAX_TOKENS) {
    inputIds.push(TRANSLATION_PAD_ID);
    attentionMask.push(0);
  }
  return {
    normalized: normalized,
    pieces: pieces,
    pieceIds: pieceIds,
    inputIds: inputIds,
    attentionMask: attentionMask,
    separatorBefore: separatorBefore,
    separatorAfter: separatorAfter
  };
}

function parseRuntimeTable(runtimeTable: string): TranslationTokenizerRuntime {
  const lines = runtimeTable.split('\n');
  if (lines.length < 3) {
    throw new Error('Tokenizer runtime table is incomplete');
  }
  const header = lines[0].split('\t');
  if (header.length !== 8 || header[0] !== TOKENIZER_TABLE_VERSION || header[1] !== PINNED_MODEL_SHA256) {
    throw new Error('Tokenizer runtime table header is invalid');
  }
  const vocabularySize = parseDecimalInteger(header[2], 'vocabulary size');
  const unknownId = parseDecimalInteger(header[3], 'unknown ID');
  const minimumScore = Number(header[4]);
  if (vocabularySize !== 32000 || unknownId !== TRANSLATION_UNK_ID || !Number.isFinite(minimumScore) ||
    header[5] !== '1' || header[6] !== '1' || header[7] !== '1') {
    throw new Error('Tokenizer runtime table contract is invalid');
  }

  const normalizationRules: Array<NormalizationRule> = [];
  const normalizationSources = new Set<string>();
  const pieces: Array<RuntimePiece> = [];
  const pieceIds = new Set<number>();
  for (let lineIndex = 1; lineIndex < lines.length; lineIndex++) {
    if (lines[lineIndex].length === 0) {
      continue;
    }
    const fields = lines[lineIndex].split('\t');
    if (fields[0] === 'N' && fields.length === 3) {
      const source = decodeCodepoints(fields[1]);
      const target = decodeCodepoints(fields[2]);
      if (source.length === 0 || normalizationSources.has(source)) {
        throw new Error('Tokenizer normalization rule is invalid');
      }
      normalizationSources.add(source);
      normalizationRules.push({ source: source, target: target });
      continue;
    }
    if (fields[0] === 'P' && fields.length === 5) {
      const id = parseDecimalInteger(fields[1], 'piece ID');
      const score = Number(fields[2]);
      const type = parseDecimalInteger(fields[3], 'piece type');
      const text = decodeCodepoints(fields[4]);
      if (id < 0 || id >= vocabularySize || pieceIds.has(id) || !Number.isFinite(score) || text.length === 0 ||
        (type !== NORMAL_PIECE_TYPE && type !== UNKNOWN_PIECE_TYPE && type !== CONTROL_PIECE_TYPE)) {
        throw new Error('Tokenizer piece is invalid');
      }
      pieceIds.add(id);
      pieces.push({ id: id, score: score, type: type, text: text });
      continue;
    }
    throw new Error(`Tokenizer runtime table line ${lineIndex + 1} is invalid`);
  }
  if (!pieceIds.has(TRANSLATION_EOS_ID) || !pieceIds.has(TRANSLATION_UNK_ID)) {
    throw new Error('Tokenizer runtime table lacks required pieces');
  }
  return new TranslationTokenizerRuntime(minimumScore, normalizationRules, pieces);
}

function parseDecimalInteger(value: string, label: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    throw new Error(`Tokenizer ${label} is invalid`);
  }
  return parsed;
}

function decodeCodepoints(encoded: string): string {
  if (encoded === '-') {
    return '';
  }
  const values = encoded.split(',');
  let decoded = '';
  for (let index = 0; index < values.length; index++) {
    const codepoint = Number.parseInt(values[index], 16);
    if (!Number.isInteger(codepoint) || codepoint < 0 || codepoint > 0x10FFFF ||
      (codepoint >= 0xD800 && codepoint <= 0xDFFF)) {
      throw new Error('Tokenizer codepoint is invalid');
    }
    decoded += stringFromCodepoint(codepoint);
  }
  return decoded;
}

function stringFromCodepoint(codepoint: number): string {
  if (codepoint <= 0xFFFF) {
    return String.fromCharCode(codepoint);
  }
  const offset = codepoint - 0x10000;
  return String.fromCharCode(0xD800 + (offset >> 10), 0xDC00 + (offset & 0x3FF));
}

function firstUnicodeSymbol(text: string): string {
  return text.substring(0, unicodeSymbolLengthAt(text, 0));
}

function unicodeSymbolLengthAt(text: string, index: number): number {
  const first = text.charCodeAt(index);
  if (first >= 0xD800 && first <= 0xDBFF && index + 1 < text.length) {
    const second = text.charCodeAt(index + 1);
    if (second >= 0xDC00 && second <= 0xDFFF) {
      return 2;
    }
  }
  return 1;
}

function splitPreservedNewlines(text: string): Array<PreservedTextRun> {
  const runs: Array<PreservedTextRun> = [];
  let separator = '';
  let start = 0;
  let index = 0;
  while (index < text.length) {
    if (text[index] !== '\r' && text[index] !== '\n') {
      index++;
      continue;
    }
    if (start < index) {
      runs.push({ separator: separator, content: text.substring(start, index) });
      separator = '';
    }
    if (text[index] === '\r' && index + 1 < text.length && text[index + 1] === '\n') {
      separator += '\r\n';
      index += 2;
    } else {
      separator += text[index];
      index++;
    }
    start = index;
  }
  if (start < text.length) {
    runs.push({ separator: separator, content: text.substring(start) });
    separator = '';
  }
  if (separator.length > 0) {
    runs.push({ separator: separator, content: '' });
  }
  return runs;
}

function normalizeTargetLanguage(targetLanguage: string): TranslationTargetLanguage {
  const normalized = targetLanguage.trim().toLowerCase();
  if (normalized === 'en') {
    return 'en';
  }
  if (normalized === 'zh') {
    return 'zh';
  }
  throw new Error(`Unsupported translation target ${targetLanguage}`);
}

function requireRuntime(): TranslationTokenizerRuntime {
  if (configuredRuntime === undefined) {
    throw new Error('Translation tokenizer is not configured');
  }
  return configuredRuntime;
}
