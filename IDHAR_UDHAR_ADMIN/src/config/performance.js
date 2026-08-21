export const BUSINESS_PERFORMANCE_THRESHOLDS = {
  highChangePercent: 8,
  mediumChangePercent: 0,
  highCompletionPercent: 90,
  mediumCompletionPercent: 80,
  highCancelPercent: 3,
  mediumCancelPercent: 6,
  highBarRatio: 1.15,
  mediumBarRatio: 0.75,
};

export const BUSINESS_PERFORMANCE = {
  HIGH: {
    key: 'HIGH',
    label: 'High',
    color: '#10B981',
    textClass: 'text-emerald-700',
    bgClass: 'bg-emerald-50',
    dotClass: 'bg-emerald-500',
  },
  MEDIUM: {
    key: 'MEDIUM',
    label: 'Medium',
    color: '#FDBA74',
    textClass: 'text-orange-700',
    bgClass: 'bg-orange-50',
    dotClass: 'bg-orange-300',
  },
  LOW: {
    key: 'LOW',
    label: 'Low',
    color: '#EF4444',
    textClass: 'text-red-700',
    bgClass: 'bg-red-50',
    dotClass: 'bg-danger',
  },
};

function scoreLevel(okHigh, okMedium) {
  if (okHigh) return 'HIGH';
  if (okMedium) return 'MEDIUM';
  return 'LOW';
}

export function resolveBusinessPerformance({
  changePercent = 0,
  completionPercent = 100,
  cancelPercent = 0,
} = {}) {
  const thresholds = BUSINESS_PERFORMANCE_THRESHOLDS;
  const changeLevel = scoreLevel(
    changePercent >= thresholds.highChangePercent,
    changePercent >= thresholds.mediumChangePercent,
  );
  const completionLevel = scoreLevel(
    completionPercent >= thresholds.highCompletionPercent,
    completionPercent >= thresholds.mediumCompletionPercent,
  );
  const cancelLevel = scoreLevel(
    cancelPercent <= thresholds.highCancelPercent,
    cancelPercent <= thresholds.mediumCancelPercent,
  );
  const rank = { HIGH: 2, MEDIUM: 1, LOW: 0 };
  const worst = Math.min(rank[changeLevel], rank[completionLevel], rank[cancelLevel]);
  const key = worst === 2 ? 'HIGH' : worst === 1 ? 'MEDIUM' : 'LOW';
  return BUSINESS_PERFORMANCE[key];
}

export function resolveBarPerformance(value, average) {
  const amount = Number(value) || 0;
  if (amount <= 0) {
    return { key: 'NONE', label: '', color: '#18CFE8' };
  }
  const mean = Number(average) || 0;
  if (mean <= 0) return BUSINESS_PERFORMANCE.MEDIUM;
  const ratio = amount / mean;
  if (ratio >= BUSINESS_PERFORMANCE_THRESHOLDS.highBarRatio) return BUSINESS_PERFORMANCE.HIGH;
  if (ratio >= BUSINESS_PERFORMANCE_THRESHOLDS.mediumBarRatio) return BUSINESS_PERFORMANCE.MEDIUM;
  return BUSINESS_PERFORMANCE.LOW;
}
