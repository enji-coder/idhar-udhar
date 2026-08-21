import { downloadCsv } from '../utils/format';

function crc32(bytes) {
  let crc = ~0;
  for (let i = 0; i < bytes.length; i += 1) {
    crc ^= bytes[i];
    for (let bit = 0; bit < 8; bit += 1) {
      const mask = -(crc & 1);
      crc = (crc >>> 1) ^ (0xedb88320 & mask);
    }
  }
  return ~crc >>> 0;
}

function concatBytes(parts) {
  const length = parts.reduce((sum, part) => sum + part.length, 0);
  const output = new Uint8Array(length);
  let offset = 0;
  parts.forEach((part) => {
    output.set(part, offset);
    offset += part.length;
  });
  return output;
}

function u16(value) {
  return new Uint8Array([value & 255, (value >>> 8) & 255]);
}

function u32(value) {
  return new Uint8Array([value & 255, (value >>> 8) & 255, (value >>> 16) & 255, (value >>> 24) & 255]);
}

function encodeUtf8(text) {
  return new TextEncoder().encode(text);
}

function zipStore(files) {
  const localParts = [];
  const centralParts = [];
  let offset = 0;
  files.forEach((file) => {
    const nameBytes = encodeUtf8(file.name);
    const data = file.data;
    const crc = crc32(data);
    const local = concatBytes([
      u32(0x04034b50),
      u16(20),
      u16(0),
      u16(0),
      u16(0),
      u16(0),
      u32(crc),
      u32(data.length),
      u32(data.length),
      u16(nameBytes.length),
      u16(0),
      nameBytes,
      data,
    ]);
    const central = concatBytes([
      u32(0x02014b50),
      u16(20),
      u16(20),
      u16(0),
      u16(0),
      u16(0),
      u16(0),
      u32(crc),
      u32(data.length),
      u32(data.length),
      u16(nameBytes.length),
      u16(0),
      u16(0),
      u16(0),
      u16(0),
      u32(0),
      u32(offset),
      nameBytes,
    ]);
    localParts.push(local);
    centralParts.push(central);
    offset += local.length;
  });
  const centralDir = concatBytes(centralParts);
  const end = concatBytes([
    u32(0x06054b50),
    u16(0),
    u16(0),
    u16(files.length),
    u16(files.length),
    u32(centralDir.length),
    u32(offset),
    u16(0),
  ]);
  return concatBytes([...localParts, centralDir, end]);
}

function xmlEscape(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function cellXml(value) {
  const text = value == null ? '' : String(value);
  if (text !== '' && Number.isFinite(Number(text)) && !/^0\d+/.test(text) && String(Number(text)) === text) {
    return `<c t="n"><v>${xmlEscape(text)}</v></c>`;
  }
  return `<c t="inlineStr"><is><t>${xmlEscape(text)}</t></is></c>`;
}

function buildSheetXml(rows, columns) {
  const header = `<row r="1">${columns.map((column, index) => cellXml(column.label).replace('<c', `<c r="${colLetter(index)}1"`)).join('')}</row>`;
  const body = rows.map((row, rowIndex) => {
    const r = rowIndex + 2;
    const cells = columns.map((column, index) => cellXml(row[column.key]).replace('<c', `<c r="${colLetter(index)}${r}"`)).join('');
    return `<row r="${r}">${cells}</row>`;
  }).join('');
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>${header}${body}</sheetData></worksheet>`;
}

function colLetter(index) {
  let n = index + 1;
  let text = '';
  while (n > 0) {
    const rem = (n - 1) % 26;
    text = String.fromCharCode(65 + rem) + text;
    n = Math.floor((n - 1) / 26);
  }
  return text;
}

function triggerDownload(filename, blob) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

function exportableRows(rows, columns) {
  return rows.map((row) => {
    const next = {};
    columns.forEach((column) => {
      const raw = row[column.exportKey || column.key];
      next[column.key] = raw == null ? '' : typeof raw === 'object' ? '' : raw;
    });
    return next;
  });
}

export function exportCsv(filename, rows, columns) {
  downloadCsv(filename.endsWith('.csv') ? filename : `${filename}.csv`, exportableRows(rows, columns), columns);
}

export function exportXlsx(filename, rows, columns) {
  const data = exportableRows(rows, columns);
  const sheet = buildSheetXml(data, columns);
  const files = [
    { name: '[Content_Types].xml', data: encodeUtf8(`<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>`) },
    { name: '_rels/.rels', data: encodeUtf8(`<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>`) },
    { name: 'xl/workbook.xml', data: encodeUtf8(`<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Report" sheetId="1" r:id="rId1"/></sheets>
</workbook>`) },
    { name: 'xl/_rels/workbook.xml.rels', data: encodeUtf8(`<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>`) },
    { name: 'xl/worksheets/sheet1.xml', data: encodeUtf8(sheet) },
  ];
  const bytes = zipStore(files);
  triggerDownload(filename.endsWith('.xlsx') ? filename : `${filename}.xlsx`, new Blob([bytes], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }));
}
