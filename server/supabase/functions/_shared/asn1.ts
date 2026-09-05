export interface Node {
  tag: number;
  headerLength: number;
  contentStart: number;
  contentEnd: number;
  start: number;
  end: number;
}

export function readNode(bytes: Uint8Array, offset: number): Node {
  if (offset + 2 > bytes.length) throw new Error("asn1 truncated");
  const tag = bytes[offset];
  const first = bytes[offset + 1];
  let length: number;
  let headerLength: number;
  if (first < 0x80) {
    length = first;
    headerLength = 2;
  } else {
    const count = first & 0x7f;
    if (count === 0 || count > 4) throw new Error("asn1 length unsupported");
    length = 0;
    for (let i = 0; i < count; i++) length = (length << 8) | bytes[offset + 2 + i];
    headerLength = 2 + count;
  }
  const contentStart = offset + headerLength;
  const contentEnd = contentStart + length;
  if (contentEnd > bytes.length) throw new Error("asn1 truncated");
  return { tag, headerLength, contentStart, contentEnd, start: offset, end: contentEnd };
}

export function children(bytes: Uint8Array, node: Node): Node[] {
  const result: Node[] = [];
  let offset = node.contentStart;
  while (offset < node.contentEnd) {
    const child = readNode(bytes, offset);
    result.push(child);
    offset = child.end;
  }
  return result;
}

export function slice(bytes: Uint8Array, node: Node): Uint8Array {
  return bytes.subarray(node.start, node.end);
}

export function content(bytes: Uint8Array, node: Node): Uint8Array {
  return bytes.subarray(node.contentStart, node.contentEnd);
}

export function objectIdentifier(bytes: Uint8Array, node: Node): string {
  const data = content(bytes, node);
  if (data.length === 0) return "";
  const parts: number[] = [Math.floor(data[0] / 40), data[0] % 40];
  let value = 0;
  for (let i = 1; i < data.length; i++) {
    value = (value << 7) | (data[i] & 0x7f);
    if ((data[i] & 0x80) === 0) {
      parts.push(value);
      value = 0;
    }
  }
  return parts.join(".");
}

export function integer(bytes: Uint8Array, node: Node): Uint8Array {
  let data = content(bytes, node);
  while (data.length > 1 && data[0] === 0x00) data = data.subarray(1);
  return data;
}

export function bitString(bytes: Uint8Array, node: Node): Uint8Array {
  const data = content(bytes, node);
  if (data.length === 0) throw new Error("asn1 empty bit string");
  return data.subarray(1);
}

export function time(bytes: Uint8Array, node: Node): Date {
  const raw = new TextDecoder().decode(content(bytes, node));
  const digits = raw.replace(/Z$/, "");
  const full = node.tag === 0x17 ? expandTwoDigitYear(digits) : digits;
  const year = Number(full.slice(0, 4));
  const month = Number(full.slice(4, 6));
  const day = Number(full.slice(6, 8));
  const hour = Number(full.slice(8, 10));
  const minute = Number(full.slice(10, 12));
  const second = Number(full.slice(12, 14) || "0");
  return new Date(Date.UTC(year, month - 1, day, hour, minute, second));
}

function expandTwoDigitYear(digits: string): string {
  const twoDigit = Number(digits.slice(0, 2));
  const century = twoDigit >= 50 ? "19" : "20";
  return century + digits;
}
