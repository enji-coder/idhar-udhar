import { createRoot } from 'react-dom/client';
import InvoicePreview from './InvoicePreview';
import { ASSETS } from '../../config/assets';
import { LOGO_DATA_URL } from '../../config/logoDataUrl';

async function logoDataUrl() {
  if (LOGO_DATA_URL?.startsWith('data:image')) return LOGO_DATA_URL;
  const href = new URL(ASSETS.LOGO, window.location.origin).href;
  const response = await fetch(href);
  const blob = await response.blob();
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
}

function strToBytes(text) {
  return new TextEncoder().encode(text);
}

function concatBytes(parts) {
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  parts.forEach((part) => {
    out.set(part, offset);
    offset += part.length;
  });
  return out;
}

function jpegFromCanvas(canvas) {
  const dataUrl = canvas.toDataURL('image/jpeg', 0.93);
  const binary = atob(dataUrl.split(',')[1]);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function buildPdf(pages) {
  const pageW = 595;
  const pageH = 842;
  const parts = [strToBytes('%PDF-1.4\n')];
  const offsets = [0];
  let offset = 9;

  function addObject(bytes) {
    offsets.push(offset);
    parts.push(bytes);
    offset += bytes.length;
  }

  addObject(strToBytes('1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n'));
  const pageIds = pages.map((_, index) => `${3 + index} 0 R`).join(' ');
  addObject(strToBytes(`2 0 obj << /Type /Pages /Kids [${pageIds}] /Count ${pages.length} >> endobj\n`));

  pages.forEach((_, index) => {
    const imageId = 3 + pages.length + index;
    const contentId = 3 + pages.length * 2 + index;
    addObject(strToBytes(`${3 + index} 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageW} ${pageH}] /Resources << /XObject << /Im${index + 1} ${imageId} 0 R >> >> /Contents ${contentId} 0 R >> endobj\n`));
  });

  pages.forEach((page, index) => {
    addObject(concatBytes([
      strToBytes(`${3 + pages.length + index} 0 obj << /Type /XObject /Subtype /Image /Width ${page.pxWidth} /Height ${page.pxHeight} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${page.jpeg.length} >> stream\n`),
      page.jpeg,
      strToBytes('\nendstream endobj\n'),
    ]));
  });

  pages.forEach((page, index) => {
    const content = `q ${page.width.toFixed(2)} 0 0 ${page.height.toFixed(2)} ${page.x.toFixed(2)} ${page.y.toFixed(2)} cm /Im${index + 1} Do Q`;
    addObject(strToBytes(`${3 + pages.length * 2 + index} 0 obj << /Length ${content.length} >> stream\n${content}\nendstream endobj\n`));
  });

  const xrefStart = offset;
  const xrefLines = ['xref', `0 ${offsets.length}`, '0000000000 65535 f '];
  for (let i = 1; i < offsets.length; i += 1) {
    xrefLines.push(`${String(offsets[i]).padStart(10, '0')} 00000 n `);
  }
  parts.push(strToBytes(`${xrefLines.join('\n')}\n`));
  parts.push(strToBytes(`trailer << /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n${xrefStart}\n%%EOF`));
  return new Blob([concatBytes(parts)], { type: 'application/pdf' });
}

async function waitForImages(node) {
  const images = [...node.querySelectorAll('img')];
  await Promise.all(images.map(async (img) => {
    if (img.decode) {
      try { await img.decode(); } catch { /* keep waiting below */ }
    }
    if (img.complete && img.naturalWidth > 0) return;
    await new Promise((resolve) => {
      const done = () => resolve();
      img.onload = done;
      img.onerror = done;
      window.setTimeout(done, 2500);
    });
  }));
}

async function renderPreview(invoice) {
  const logoSrc = await logoDataUrl().catch(() => LOGO_DATA_URL || ASSETS.LOGO);
  const host = document.createElement('div');
  host.setAttribute('data-invoice-capture', 'true');
  host.style.cssText = 'position:fixed;left:-794px;top:0;width:794px;background:#ffffff;z-index:-1;pointer-events:none;';
  document.body.appendChild(host);
  const root = createRoot(host);
  await new Promise((resolve) => {
    root.render(<InvoicePreview invoice={{ ...invoice, logoSrc }} />);
    window.requestAnimationFrame(() => window.requestAnimationFrame(resolve));
  });
  await waitForImages(host);
  const logo = host.querySelector('img');
  if (logo && !(logo.complete && logo.naturalWidth > 0)) {
    logo.src = logoSrc;
    await waitForImages(host);
  }
  await new Promise((resolve) => window.setTimeout(resolve, 160));
  return { host, root, sheet: host.querySelector('.invoice-sheet') };
}

function sliceCanvas(canvas) {
  const pageW = 595;
  const pageH = 842;
  const margin = 18;
  const contentW = pageW - margin * 2;
  const contentH = pageH - margin * 2;
  const ratio = contentW / canvas.width;
  const sliceHeightPx = Math.max(1, Math.floor(contentH / ratio));
  const pages = [];
  let y = 0;
  while (y < canvas.height) {
    const height = Math.min(sliceHeightPx, canvas.height - y);
    const slice = document.createElement('canvas');
    slice.width = canvas.width;
    slice.height = height;
    const ctx = slice.getContext('2d');
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, slice.width, slice.height);
    ctx.drawImage(canvas, 0, y, canvas.width, height, 0, 0, canvas.width, height);
    const drawH = height * ratio;
    pages.push({
      jpeg: jpegFromCanvas(slice),
      pxWidth: slice.width,
      pxHeight: slice.height,
      width: contentW,
      height: drawH,
      x: margin,
      y: pageH - margin - drawH,
    });
    y += height;
  }
  return pages;
}

async function captureSheet(sheet) {
  const html2canvas = (await import('html2canvas')).default;
  try {
    return await html2canvas(sheet, {
      scale: 2,
      useCORS: true,
      allowTaint: true,
      backgroundColor: '#ffffff',
      logging: false,
      imageTimeout: 4000,
      onclone: (_doc, cloned) => {
        cloned.querySelectorAll('img').forEach((img) => {
          img.style.maxWidth = 'none';
        });
      },
    });
  } catch {
    return html2canvas(sheet, {
      scale: 2,
      backgroundColor: '#ffffff',
      logging: false,
      imageTimeout: 2000,
    });
  }
}

export async function downloadInvoicePdf(invoice) {
  if (!invoice) return;
  const mounted = await renderPreview(invoice);
  try {
    const canvas = await captureSheet(mounted.sheet);
    const blob = buildPdf(sliceCanvas(canvas));
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${invoice.invoiceNumber}.pdf`;
    link.click();
    URL.revokeObjectURL(url);
  } finally {
    mounted.root.unmount();
    mounted.host.remove();
  }
}
