export function createEntityStore(key, seed) {
  const storageKey = `iu_admin_${key}`;

  function read() {
    try {
      const raw = localStorage.getItem(storageKey);
      if (raw) return JSON.parse(raw);
    } catch {
      /* keep seed */
    }
    return structuredClone(seed);
  }

  let data = read();
  const listeners = new Set();

  function persist() {
    localStorage.setItem(storageKey, JSON.stringify(data));
    listeners.forEach((listener) => listener());
  }

  return {
    getAll() {
      return data;
    },
    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    replace(next) {
      data = next;
      persist();
    },
    upsert(item, idKey = 'id') {
      const exists = data.some((row) => row[idKey] === item[idKey]);
      data = exists ? data.map((row) => (row[idKey] === item[idKey] ? { ...row, ...item } : row)) : [item, ...data];
      persist();
    },
    patch(id, partial, idKey = 'id') {
      data = data.map((row) => (row[idKey] === id ? { ...row, ...partial } : row));
      persist();
    },
    remove(id, idKey = 'id') {
      data = data.filter((row) => row[idKey] !== id);
      persist();
    },
  };
}
