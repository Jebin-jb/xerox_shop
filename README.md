# 🖨️ Campus Xerox - Student & Shopkeeper Print Management App

A production-grade, real-time Flutter application designed for campus Xerox & print shops. Students can upload documents (up to 50 MB), customize print options, view live calculated rates, pay online or at the counter, and track order fulfillment in real-time. Shopkeepers can manage queues, update live prices, download and securely purge documents, and track revenues and expenses.

---

## ✨ Features

- **50 MB File Transfers:** Supports large PDFs, Word documents, PowerPoint presentations, and images with real-time upload progress.
- **Privacy & Auto-Purge:** Documents are stored in a private storage bucket with signed URLs and automatically purged upon completion or cancellation.
- **Supabase Backend:** Powered by PostgreSQL Database, Realtime webhooks/subscriptions, and Supabase Storage.
- **Offline / Local Fallback Mode:** Seamlessly works out-of-the-box in demo mode using persistent local storage even if Supabase credentials are not configured yet.
- **Role-Based Portals:**
  - 🎓 **Student Portal:** Create orders, track active prints, view live shop price rates, view pickup codes.
  - 🏪 **Shopkeeper Portal:** Live incoming print queue, 1-click status updates (`Accepted` ➔ `Printing` ➔ `Ready` ➔ `Completed`), price control, and profit/loss reports.
- **Responsive Mobile UI:** Optimized across all screen sizes (small phones 320px–360px, standard 390px–430px, and foldables/tablets 800px+).
- **Theme Support:** Modern glassmorphism with Dark & Light mode toggle.

---

## 🚀 Getting Started

### 1. Run the App Locally

```bash
# Get dependencies
flutter pub get

# Run on connected device or Chrome
flutter run
```

---

## 🔗 Connecting to Supabase

1. Create a free project at [supabase.com](https://supabase.com).
2. Go to **Project Settings ➔ API** and copy:
   - **Project URL**
   - **Anon / Public API Key**
3. Open `lib/services/supabase_config.dart` and paste your credentials:
   ```dart
   static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
   static const String supabaseAnonKey = 'YOUR_ANON_KEY';
   ```
4. Run the provided database migration:
   - Open `supabase_schema.sql` in this repo.
   - Go to your **Supabase Dashboard ➔ SQL Editor**, paste the SQL, and click **Run**.

---

## 👥 Demo Accounts (Local Mode)

| Role | Email | Password |
| :--- | :--- | :--- |
| **Student** | `student@college.ac.in` | `Student@12345` |
| **Shopkeeper** | `shopkeeper@college.ac.in` | `Shop@12345` |

---

## 📁 Project Structure

```
lib/
├── app_config.dart            # App-wide global settings
├── main.dart                  # Application entrypoint & Supabase initialization
├── models/
│   └── app_models.dart        # Data models (UserProfile, ShopPrice, PrintOrder, ExpenseEntry)
├── screens/
│   ├── auth/                  # Portal selection, Student login, Admin login, Registration
│   ├── student/               # Student Home, Create Order (50MB upload), Order Receipt, Order History
│   ├── shopkeeper/            # Shop Dashboard, Orders Queue, Price Control, Reports & Accounting
│   └── role_gate.dart         # Role-based route guard
├── services/
│   ├── auth_service.dart      # Authentication service (Supabase Auth + Local fallback)
│   ├── data_service.dart      # Persistent reactive data store
│   ├── payment_service.dart   # Unified payment gateway handler
│   ├── storage_service.dart   # 50MB file upload & signed URL manager
│   ├── supabase_config.dart   # Supabase credentials & bucket config
│   └── supabase_service.dart  # Realtime Supabase PostgreSQL service
├── theme/
│   └── app_theme.dart         # Material 3 light/dark glassmorphic design system
└── widgets/
    ├── glass.dart             # Ambient backgrounds & glass panels
    ├── order_widgets.dart     # Order cards & status badges
    └── payment_modal.dart     # Checkout & payment modal
```
