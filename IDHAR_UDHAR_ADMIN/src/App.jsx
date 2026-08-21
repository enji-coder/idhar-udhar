import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import ProtectedRoute from './components/auth/ProtectedRoute';
import AdminLayout from './components/layout/AdminLayout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import LiveOperations from './pages/LiveOperations';
import Orders from './pages/Orders';
import Tracking from './pages/Tracking';
import Riders from './pages/Riders';
import RiderDetail from './pages/RiderDetail';
import Customers from './pages/Customers';
import CustomerDetail from './pages/CustomerDetail';
import Verification from './pages/Verification';
import Payments from './pages/Payments';
import Earnings from './pages/Earnings';
import Payouts from './pages/Payouts';
import Coupons from './pages/Coupons';
import Promotions from './pages/Promotions';
import Notifications from './pages/Notifications';
import Support from './pages/Support';
import Reports from './pages/Reports';
import Settings from './pages/Settings';
import Profile from './pages/Profile';
import Vehicles from './pages/Vehicles';
import VehicleCategories from './pages/VehicleCategories';
import WalletPage from './pages/Wallet';
import Zones from './pages/Zones';
import Invoices from './pages/Invoices';
import PurchaseInvoices from './pages/PurchaseInvoices';
import Announcements from './pages/Announcements';

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route
            element={(
              <ProtectedRoute>
                <AdminLayout />
              </ProtectedRoute>
            )}
          >
            <Route path="/" element={<Navigate to="/dashboard" replace />} />
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/live" element={<LiveOperations />} />
            <Route path="/orders" element={<Orders />} />
            <Route path="/tracking" element={<Tracking />} />
            <Route path="/riders" element={<Riders />} />
            <Route path="/riders/:id" element={<RiderDetail />} />
            <Route path="/customers" element={<Customers />} />
            <Route path="/customers/:id" element={<CustomerDetail />} />
            <Route path="/verification" element={<Verification />} />
            <Route path="/payments" element={<Payments />} />
            <Route path="/earnings" element={<Earnings />} />
            <Route path="/payouts" element={<Payouts />} />
            <Route path="/coupons" element={<Coupons />} />
            <Route path="/promotions" element={<Promotions />} />
            <Route path="/notifications" element={<Notifications />} />
            <Route path="/support" element={<Support />} />
            <Route path="/reports" element={<Reports />} />
            <Route path="/settings" element={<Settings />} />
            <Route path="/profile" element={<Profile />} />
            <Route path="/vehicles" element={<Vehicles />} />
            <Route path="/vehicle-categories" element={<VehicleCategories />} />
            <Route path="/wallet" element={<WalletPage />} />
            <Route path="/zones" element={<Zones />} />
            <Route path="/invoices" element={<Invoices />} />
            <Route path="/purchase-invoices" element={<PurchaseInvoices />} />
            <Route path="/announcements" element={<Announcements />} />
            <Route path="/upi-settings" element={<Navigate to="/payments" replace />} />
            <Route path="/promo-codes" element={<Navigate to="/coupons" replace />} />
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
