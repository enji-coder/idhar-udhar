const MONTHS = {
  jan: 0, january: 0, feb: 1, february: 1, mar: 2, march: 2, apr: 3, april: 3,
  may: 4, jun: 5, june: 5, jul: 6, july: 6, aug: 7, august: 7, sep: 8, september: 8,
  oct: 9, october: 9, nov: 10, november: 10, dec: 11, december: 11,
};

export const DATA_TODAY = new Date(2026, 7, 17);

export function parseAppDate(value) {
  if (!value && value !== 0) return null;
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
  const text = String(value).trim();
  if (!text || text === '-' || text === 'N/A') return null;
  const iso = text.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (iso) return new Date(Number(iso[1]), Number(iso[2]) - 1, Number(iso[3]));
  const named = text.match(/^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})/);
  if (named) {
    const month = MONTHS[named[2].toLowerCase()];
    if (month == null) return null;
    return new Date(Number(named[3]), month, Number(named[1]));
  }
  const numeric = text.match(/^(\d{1,2})[/-](\d{1,2})[/-](\d{4})/);
  if (numeric) return new Date(Number(numeric[3]), Number(numeric[2]) - 1, Number(numeric[1]));
  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function applyClock(date, timeText) {
  const match = String(timeText || '').match(/(\d{1,2}):(\d{2})\s*(AM|PM)?/i);
  if (!match) return date;
  let hours = Number(match[1]);
  const minutes = Number(match[2]);
  const meridem = match[3]?.toUpperCase();
  if (meridem === 'PM' && hours < 12) hours += 12;
  if (meridem === 'AM' && hours === 12) hours = 0;
  date.setHours(hours, minutes, 0, 0);
  return date;
}

export function parseAppDateTime(dateValue, timeValue) {
  const date = parseAppDate(dateValue);
  if (!date) return null;
  return applyClock(date, timeValue || dateValue);
}

export function sortByDateTime(rows, dateKey = 'date', timeKey = 'time', newestFirst = true) {
  return [...rows].sort((left, right) => {
    const leftStamp = parseAppDateTime(left[dateKey] || left.timestamp, left[timeKey] || left.timestamp)?.getTime() || 0;
    const rightStamp = parseAppDateTime(right[dateKey] || right.timestamp, right[timeKey] || right.timestamp)?.getTime() || 0;
    return newestFirst ? rightStamp - leftStamp : leftStamp - rightStamp;
  });
}

export function startOfDay(date) {
  const next = new Date(date);
  next.setHours(0, 0, 0, 0);
  return next;
}

export function endOfDay(date) {
  const next = new Date(date);
  next.setHours(23, 59, 59, 999);
  return next;
}

export function toISODate(date) {
  if (!date) return '';
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function formatAppDate(date) {
  if (!date) return 'N/A';
  return date.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

export function formatAppTime(value, fallback = 'N/A') {
  if (!value) return fallback;
  const match = String(value).match(/(\d{1,2}:\d{2}\s*(?:AM|PM))/i);
  if (match) {
    const parts = match[1].toUpperCase().replace(/\s+/g, ' ').trim().match(/(\d{1,2}):(\d{2})\s*(AM|PM)/);
    if (!parts) return match[1].toUpperCase();
    return `${String(Number(parts[1])).padStart(2, '0')}:${parts[2]} ${parts[3]}`;
  }
  const date = parseAppDateTime(value, value);
  if (!date) return String(value);
  return date.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true }).replace(/\./g, '').toUpperCase();
}

export function formatTimestamp(dateValue, timeValue) {
  const date = parseAppDate(dateValue);
  const time = formatAppTime(timeValue || dateValue, '');
  if (!date && !time) return 'N/A';
  if (!date) return time;
  return time ? `${formatAppDate(date)}, ${time}` : formatAppDate(date);
}

export function daysBetween(from, to = DATA_TODAY) {
  const start = parseAppDate(from);
  const end = parseAppDate(to) || DATA_TODAY;
  if (!start) return null;
  return Math.round((startOfDay(start) - startOfDay(end)) / 86400000);
}

export function inDateRange(value, from, to) {
  const date = parseAppDate(value);
  if (!date) return false;
  if (from && date < startOfDay(parseAppDate(from) || from)) return false;
  if (to && date > endOfDay(parseAppDate(to) || to)) return false;
  return true;
}

const MONTH_INDEX = {
  January: 0, February: 1, March: 2, April: 3, May: 4, June: 5,
  July: 6, August: 7, September: 8, October: 9, November: 10, December: 11,
};

export function rangeForPreset(preset, year, monthName, customFrom, customTo) {
  const today = DATA_TODAY;
  const yearNumber = Number(year) || today.getFullYear();
  if (preset === 'custom') {
    return { from: customFrom, to: customTo };
  }
  if (preset === 'today') {
    const iso = toISODate(today);
    return { from: iso, to: iso };
  }
  if (preset === 'yesterday') {
    const date = new Date(today);
    date.setDate(date.getDate() - 1);
    const iso = toISODate(date);
    return { from: iso, to: iso };
  }
  if (preset === 'week') {
    const fromDate = new Date(today);
    fromDate.setDate(fromDate.getDate() - 6);
    return { from: toISODate(fromDate), to: toISODate(today) };
  }
  if (preset === 'month') {
    const month = today.getMonth();
    return { from: toISODate(new Date(yearNumber, month, 1)), to: toISODate(today) };
  }
  if (preset === 'lastMonth') {
    const fromDate = new Date(yearNumber, today.getMonth() - 1, 1);
    const toDate = new Date(yearNumber, today.getMonth(), 0);
    return { from: toISODate(fromDate), to: toISODate(toDate) };
  }
  if (preset === '3m') {
    const fromDate = new Date(today);
    fromDate.setMonth(fromDate.getMonth() - 3);
    return { from: toISODate(fromDate), to: toISODate(today) };
  }
  if (preset === '6m') {
    const fromDate = new Date(today);
    fromDate.setMonth(fromDate.getMonth() - 6);
    return { from: toISODate(fromDate), to: toISODate(today) };
  }
  if (preset === 'year') {
    return { from: `${yearNumber}-01-01`, to: toISODate(today) };
  }
  if (preset === 'lastYear') {
    return { from: `${yearNumber - 1}-01-01`, to: `${yearNumber - 1}-12-31` };
  }
  if (monthName && MONTH_INDEX[monthName] != null) {
    const month = MONTH_INDEX[monthName];
    const fromDate = new Date(yearNumber, month, 1);
    const toDate = new Date(yearNumber, month + 1, 0);
    return { from: toISODate(fromDate), to: toISODate(toDate) };
  }
  return { from: customFrom, to: customTo };
}
