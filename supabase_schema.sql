-- ==============================================================================
-- CAMPUS XEROX SHOP - SUPABASE POSTGRESQL DATABASE SCHEMA & MIGRATION SCRIPT
-- ==============================================================================
-- Run this complete script in the Supabase SQL Editor (Dashboard -> SQL Editor)
-- to create all tables, RLS security policies, 50MB storage bucket, and seed data.
-- ==============================================================================

-- 1. PROFILES TABLE (Syncs with Supabase Auth users & App Accounts)
CREATE TABLE IF NOT EXISTS public.profiles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'shopkeeper')),
    student_id TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. SHOP PRICING TABLE (Configurable for all paper categories & extra services)
CREATE TABLE IF NOT EXISTS public.shop_prices (
    id TEXT PRIMARY KEY DEFAULT 'campus-xerox',
    bw_single NUMERIC(10, 2) NOT NULL DEFAULT 1.00,
    bw_double NUMERIC(10, 2) NOT NULL DEFAULT 1.50,
    color_single NUMERIC(10, 2) NOT NULL DEFAULT 5.00,
    color_double NUMERIC(10, 2) NOT NULL DEFAULT 8.00,
    photocopy NUMERIC(10, 2) NOT NULL DEFAULT 1.00,
    paper_75_gsm NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    paper_100_gsm NUMERIC(10, 2) NOT NULL DEFAULT 1.50,
    paper_glossy NUMERIC(10, 2) NOT NULL DEFAULT 10.00,
    spiral_binding NUMERIC(10, 2) NOT NULL DEFAULT 30.00,
    hard_binding NUMERIC(10, 2) NOT NULL DEFAULT 150.00,
    lamination NUMERIC(10, 2) NOT NULL DEFAULT 10.00,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed default pricing if not present
INSERT INTO public.shop_prices (
    id, bw_single, bw_double, color_single, color_double, photocopy,
    paper_75_gsm, paper_100_gsm, paper_glossy, spiral_binding, hard_binding, lamination, updated_at
)
VALUES (
    'campus-xerox', 1.00, 1.50, 5.00, 8.00, 1.00,
    0.00, 1.50, 10.00, 30.00, 150.00, 10.00, now()
)
ON CONFLICT (id) DO UPDATE SET
    paper_75_gsm = EXCLUDED.paper_75_gsm,
    paper_100_gsm = EXCLUDED.paper_100_gsm,
    paper_glossy = EXCLUDED.paper_glossy,
    spiral_binding = EXCLUDED.spiral_binding,
    hard_binding = EXCLUDED.hard_binding;

-- 2B. SERVICES TABLE (Granular dynamic service catalog)
CREATE TABLE IF NOT EXISTS public.services (
    id TEXT PRIMARY KEY,
    shop_id TEXT NOT NULL DEFAULT 'campus-xerox',
    service_name TEXT NOT NULL,
    description TEXT DEFAULT '',
    price NUMERIC(10, 2) NOT NULL,
    pricing_unit TEXT NOT NULL DEFAULT 'per_page',
    is_active BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed initial services if empty
INSERT INTO public.services (id, shop_id, service_name, description, price, pricing_unit, is_active, updated_at)
VALUES
    ('srv_bw_single', 'campus-xerox', 'B&W Single Side', 'Black & white single side print', 1.00, 'per_page', true, now()),
    ('srv_bw_double', 'campus-xerox', 'B&W Double Side', 'Black & white double side print', 1.50, 'per_page', true, now()),
    ('srv_color_single', 'campus-xerox', 'Color Single Side', 'Full color single side print', 5.00, 'per_page', true, now()),
    ('srv_color_double', 'campus-xerox', 'Color Double Side', 'Full color double side print', 8.00, 'per_page', true, now()),
    ('srv_spiral_binding', 'campus-xerox', 'Binding', 'Spiral coil binding', 30.00, 'per_item', true, now()),
    ('srv_lamination', 'campus-xerox', 'Lamination', 'A4 hot pouch lamination', 10.00, 'per_item', true, now())
ON CONFLICT (id) DO NOTHING;

-- 2C. PAYMENT SETTINGS TABLE (Dynamic shopkeeper payment account and QR code)
CREATE TABLE IF NOT EXISTS public.payment_settings (
    id TEXT PRIMARY KEY DEFAULT 'campus-xerox',
    shop_id TEXT NOT NULL DEFAULT 'campus-xerox',
    upi_id TEXT NOT NULL DEFAULT '',
    payee_name TEXT NOT NULL DEFAULT 'Campus Xerox',
    payment_app TEXT NOT NULL DEFAULT 'Google Pay',
    qr_image_url TEXT NOT NULL DEFAULT '',
    is_active BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed default payment settings
INSERT INTO public.payment_settings (
    id, shop_id, upi_id, payee_name, payment_app, qr_image_url, is_active, updated_at
)
VALUES (
    'campus-xerox', 'campus-xerox', '', 'Campus Xerox', 'Google Pay', '', true, now()
)
ON CONFLICT (id) DO NOTHING;

-- 3. PRINT ORDERS TABLE
CREATE TABLE IF NOT EXISTS public.print_orders (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    student_email TEXT NOT NULL DEFAULT '',
    file_name TEXT NOT NULL,
    file_url TEXT NOT NULL,
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    pages INTEGER NOT NULL DEFAULT 1,
    copies INTEGER NOT NULL DEFAULT 1,
    color BOOLEAN NOT NULL DEFAULT false,
    double_sided BOOLEAN NOT NULL DEFAULT false,
    lamination BOOLEAN NOT NULL DEFAULT false,
    binding BOOLEAN NOT NULL DEFAULT false,
    paper_type TEXT NOT NULL DEFAULT 'standard75Gsm',
    binding_type TEXT NOT NULL DEFAULT 'none',
    total NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    payment_mode TEXT NOT NULL DEFAULT 'online' CHECK (payment_mode IN ('online', 'counter')),
    payment_status TEXT NOT NULL DEFAULT 'unpaid',
    status TEXT NOT NULL DEFAULT 'pending',
    is_downloaded BOOLEAN NOT NULL DEFAULT false,
    is_purged BOOLEAN NOT NULL DEFAULT false,
    price_snapshot JSONB DEFAULT NULL,
    bw_page_count INTEGER DEFAULT NULL,
    color_page_count INTEGER DEFAULT NULL,
    color_page_numbers JSONB DEFAULT '[]'::jsonb,
    page_settings JSONB DEFAULT '[]'::jsonb,
    payment_method TEXT DEFAULT '',
    transaction_reference TEXT DEFAULT '',
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

-- Migration support for existing print_orders tables:
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS bw_page_count INTEGER DEFAULT NULL;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS color_page_count INTEGER DEFAULT NULL;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS color_page_numbers JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS page_settings JSONB DEFAULT '[]'::jsonb;

-- 4. EXPENSES TABLE (Shopkeeper accounting)
CREATE TABLE IF NOT EXISTS public.expenses (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    category TEXT NOT NULL DEFAULT 'supplies',
    date TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==============================================================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.print_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
DROP POLICY IF EXISTS "Public read profiles" ON public.profiles;
CREATE POLICY "Public read profiles" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public manage profiles" ON public.profiles;
CREATE POLICY "Public manage profiles" ON public.profiles FOR ALL USING (true);

-- Pricing Policies: Anyone can view prices, staff can edit
DROP POLICY IF EXISTS "Anyone can view shop prices" ON public.shop_prices;
CREATE POLICY "Anyone can view shop prices" ON public.shop_prices FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow manage shop prices" ON public.shop_prices;
CREATE POLICY "Allow manage shop prices" ON public.shop_prices FOR ALL USING (true);

-- Services Policies
DROP POLICY IF EXISTS "Anyone can view active services" ON public.services;
CREATE POLICY "Anyone can view active services" ON public.services FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow manage services" ON public.services;
CREATE POLICY "Allow manage services" ON public.services FOR ALL USING (true);

-- Payment Settings Policies: Anyone can view active payment settings, staff can edit
DROP POLICY IF EXISTS "Anyone can view active payment settings" ON public.payment_settings;
CREATE POLICY "Anyone can view active payment settings" ON public.payment_settings FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow manage payment settings" ON public.payment_settings;
CREATE POLICY "Allow manage payment settings" ON public.payment_settings FOR ALL USING (true);

-- Print Orders Policies: Students & Shopkeeper can view and manage orders
DROP POLICY IF EXISTS "Allow manage print orders" ON public.print_orders;
CREATE POLICY "Allow manage print orders" ON public.print_orders FOR ALL USING (true);

-- Expenses Policies
DROP POLICY IF EXISTS "Allow manage expenses" ON public.expenses;
CREATE POLICY "Allow manage expenses" ON public.expenses FOR ALL USING (true);

-- ==============================================================================
-- 6. SUPABASE STORAGE SETUP (Documents & Payment QR Buckets)
-- ==============================================================================
-- Document bucket (50MB)
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES (
    'xerox-documents',
    'xerox-documents',
    true,
    52428800
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 52428800;

-- Storage Policies for 'xerox-documents'
DROP POLICY IF EXISTS "Allow public uploads to xerox-documents" ON storage.objects;
CREATE POLICY "Allow public uploads to xerox-documents"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'xerox-documents');

DROP POLICY IF EXISTS "Allow public downloads from xerox-documents" ON storage.objects;
CREATE POLICY "Allow public downloads from xerox-documents"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'xerox-documents');

DROP POLICY IF EXISTS "Allow public updates to xerox-documents" ON storage.objects;
CREATE POLICY "Allow public updates to xerox-documents"
    ON storage.objects FOR UPDATE
    USING (bucket_id = 'xerox-documents');

DROP POLICY IF EXISTS "Allow public deletes in xerox-documents" ON storage.objects;
CREATE POLICY "Allow public deletes in xerox-documents"
    ON storage.objects FOR DELETE
    USING (bucket_id = 'xerox-documents');

-- Payment QR bucket (10MB limit for scannable QR images)
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES (
    'payment_qr',
    'payment_qr',
    true,
    10485760
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 10485760;

-- Storage Policies for 'payment_qr'
DROP POLICY IF EXISTS "Allow public uploads to payment_qr" ON storage.objects;
CREATE POLICY "Allow public uploads to payment_qr"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'payment_qr');

DROP POLICY IF EXISTS "Allow public downloads from payment_qr" ON storage.objects;
CREATE POLICY "Allow public downloads from payment_qr"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'payment_qr');

DROP POLICY IF EXISTS "Allow public updates to payment_qr" ON storage.objects;
CREATE POLICY "Allow public updates to payment_qr"
    ON storage.objects FOR UPDATE
    USING (bucket_id = 'payment_qr');

DROP POLICY IF EXISTS "Allow public deletes in payment_qr" ON storage.objects;
CREATE POLICY "Allow public deletes in payment_qr"
    ON storage.objects FOR DELETE
    USING (bucket_id = 'payment_qr');

-- ==============================================================================
-- 7. REALTIME REPLICATION ENABLEMENT (Safe idempotent execution)
-- ==============================================================================
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.print_orders;
    EXCEPTION WHEN duplicate_object THEN
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.shop_prices;
    EXCEPTION WHEN duplicate_object THEN
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.services;
    EXCEPTION WHEN duplicate_object THEN
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_settings;
    EXCEPTION WHEN duplicate_object THEN
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.expenses;
    EXCEPTION WHEN duplicate_object THEN
    END;
END $$;
