export const walletTransactions = [
  { id: 'WLT-9001', user: 'Rahul Mehta', userType: 'Customer', type: 'Credit', amount: 500, balance: 860, date: '14 Aug 2026', time: '09:12 AM', status: 'Success', method: 'UPI', description: 'Wallet top-up via UPI' },
  { id: 'WLT-9002', user: 'Priya Patel', userType: 'Customer', type: 'Debit', amount: 189, balance: 311, date: '14 Aug 2026', time: '10:48 AM', status: 'Success', method: 'Wallet', description: 'Order IU-AMD-10422' },
  { id: 'WLT-9003', user: 'Vikram Singh', userType: 'Rider', type: 'Credit', amount: 1280, balance: 8640, date: '14 Aug 2026', time: '08:05 PM', status: 'Success', method: 'UPI', description: 'Daily earnings settlement' },
  { id: 'WLT-9004', user: 'Kavya Iyer', userType: 'Customer', type: 'Refund', amount: 99, balance: 249, date: '13 Aug 2026', time: '07:52 PM', status: 'Success', method: 'Wallet', description: 'Refund for cancelled IU-AMD-10426' },
  { id: 'WLT-9005', user: 'Sandeep Kaur', userType: 'Rider', type: 'Credit', amount: 980, balance: 7420, date: '14 Aug 2026', time: '07:40 PM', status: 'Pending', method: 'UPI', description: 'Incentive hold — rain bonus' },
  { id: 'WLT-9006', user: 'Arjun Desai', userType: 'Customer', type: 'Adjustment', amount: 50, balance: 50, date: '12 Aug 2026', time: '06:18 PM', status: 'Success', method: 'Wallet', description: 'Goodwill credit — delayed delivery' },
  { id: 'WLT-9007', user: 'Sneha Shah', userType: 'Customer', type: 'Debit', amount: 540, balance: 1460, date: '14 Aug 2026', time: '08:20 AM', status: 'Success', method: 'Wallet', description: 'Order IU-AMD-10424' },
  { id: 'WLT-9008', user: 'Farhan Ali', userType: 'Rider', type: 'Debit', amount: 200, balance: 5180, date: '11 Aug 2026', time: '09:30 AM', status: 'Success', method: 'Wallet', description: 'Penalty — missed pickup window' },
];

export const walletSummary = {
  total: 186420,
  available: 164880,
  pending: 21540,
  transactions: walletTransactions.length,
};
