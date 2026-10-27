-- ==============================================================================
-- CAMPUS XEROX SHOP - SUPABASE POSTGRESQL DATABASE SCHEMA & MIGRATION
-- ==============================================================================
-- Run this complete script in the Supabase SQL Editor (Dashboard -> SQL Editor).
--
-- Features & Highlights:
-- 1. Full Grant Privileges: Explicitly grants schema & table permissions to 'anon'
--    and 'authenticated' roles to prevent 42501 (permission denied) errors.
-- 2. Compatible with both App-managed users (demo/mock) and Supabase Auth users.
-- 3. Storage Setup: Public buckets for 'xerox-documents' (50MB) and 'payment_qr' (10MB)
--    with open RLS policies allowing uploads, downloads, and auto-purge deletions.
-- 4. Preserves Custom Shop Prices, Services, and UPI Payment Accounts.
-- 5. Enables Supabase Realtime across all tables for instant two-phone synchronization.
-- ==============================================================================

-- ==============================================================================
-- 1. TABLE DEFINITIONS
-- ==============================================================================

-- 1A. PROFILES TABLE (User accounts & roles)
CREATE TABLE IF NOT EXISTS public.profiles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    email TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'shopkeeper')),
    student_id TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure all columns exist if created with an older partial schema:
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT NOT NULL DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'student';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS student_id TEXT DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- 1B. SHOP PRICING TABLE (Paper categories, GSM, bindings, and services)
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

-- Ensure all pricing columns exist:
ALTER TABLE public.shop_prices ADD COLUMN IF NOT EXISTS bw_single NUMERIC(10, 2) NOT NULL DEFAULT 1.00;
ALTER TABLE public.shop_prices ADD COLUMN IF NOT EXISTS bw_double NUMERIC(10, 2) NOT NULL DEFAULT 1.50;
ALTER TABLE public.shop_prices ADD COLUMN IF NOT EXISTS color_single NUMERIC(10, 2) NOT NULL DEFAULT 5.00;
ALTER TABLE public.shop_prices ADD COLUMN IF NOT EXISTS color_double NUMERIC(10, 2) NOT NULL DEFAULT 8.00;
ALTER TABLE public.shop_prices ADD COLUMN IF NOT EXISTS photocopy NUMERIC(10, 2) NOT NULL DEFAULT 1.00;
ALTER TABLE public.shop_prices ADD COLUMN IF NOT EXISTS paper_75_gsm NUMERIC(10, 2) NOT NULL DEFAULT 0.00;
ALTER TABLE public.shop_prices ADD COLUMN IF NOT EXISTS paper_100_gsm NUMERIC(10, 2) NOT NULL DEFAULT 1.50;
ALTER TABLE public.shop_prices ADD COLUMN IF NOT EXISTS paper_glossy NUMERIC(10, 2) NOT NULL DEFAULT 10.00;
ALTER TABLE public.shop_prices ADD COLUMN IF NOT EXISTS spiral_binding NUMERIC(10, 2) NOT NULL DEFAULT 30.00;
ALTER TABLE public.shop_prices ADD COLUMN IF NOT EXISTS hard_binding NUMERIC(10, 2) NOT NULL DEFAULT 150.00;
ALTER TABLE public.shop_prices ADD COLUMN IF NOT EXISTS lamination NUMERIC(10, 2) NOT NULL DEFAULT 10.00;
ALTER TABLE public.shop_prices ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Seed default pricing ONLY if not present (Preserves custom shopkeeper prices)
INSERT INTO public.shop_prices (
    id, bw_single, bw_double, color_single, color_double, photocopy,
    paper_75_gsm, paper_100_gsm, paper_glossy, spiral_binding, hard_binding, lamination, updated_at
)
VALUES (
    'campus-xerox', 1.00, 1.50, 5.00, 8.00, 1.00,
    0.00, 1.50, 10.00, 30.00, 150.00, 10.00, now()
)
ON CONFLICT (id) DO NOTHING;

-- 1C. SERVICES TABLE (Granular dynamic service catalog)
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id TEXT NOT NULL DEFAULT 'campus-xerox',
    service_name TEXT NOT NULL,
    description TEXT DEFAULT '',
    price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    pricing_unit TEXT NOT NULL DEFAULT 'per_page',
    is_active BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure all columns exist:
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS shop_id TEXT NOT NULL DEFAULT 'campus-xerox';
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS service_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '';
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS price NUMERIC(10, 2) NOT NULL DEFAULT 0.00;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS pricing_unit TEXT NOT NULL DEFAULT 'per_page';
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Seed default services only if they do not exist
INSERT INTO public.services (shop_id, service_name, description, price, pricing_unit, is_active, updated_at)
SELECT s.shop_id, s.service_name, s.description, s.price, s.pricing_unit, s.is_active, now()
FROM (VALUES
    ('campus-xerox', 'B&W Single Side', 'Black & white single side print', 1.00::numeric, 'per_page', true),
    ('campus-xerox', 'B&W Double Side', 'Black & white double side print', 1.50::numeric, 'per_page', true),
    ('campus-xerox', 'Color Single Side', 'Full color single side print', 5.00::numeric, 'per_page', true),
    ('campus-xerox', 'Color Double Side', 'Full color double side print', 8.00::numeric, 'per_page', true),
    ('campus-xerox', 'Binding', 'Spiral coil binding', 30.00::numeric, 'per_item', true),
    ('campus-xerox', 'Lamination', 'A4 hot pouch lamination', 10.00::numeric, 'per_item', true)
) AS s(shop_id, service_name, description, price, pricing_unit, is_active)
WHERE NOT EXISTS (
    SELECT 1 FROM public.services existing
    WHERE existing.shop_id = s.shop_id
      AND lower(trim(existing.service_name)) = lower(trim(s.service_name))
);

-- 1D. PAYMENT SETTINGS TABLE (Shopkeeper UPI account & QR code)
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

-- Ensure all columns exist:
ALTER TABLE public.payment_settings ADD COLUMN IF NOT EXISTS shop_id TEXT NOT NULL DEFAULT 'campus-xerox';
ALTER TABLE public.payment_settings ADD COLUMN IF NOT EXISTS upi_id TEXT NOT NULL DEFAULT '';
ALTER TABLE public.payment_settings ADD COLUMN IF NOT EXISTS payee_name TEXT NOT NULL DEFAULT 'Campus Xerox';
ALTER TABLE public.payment_settings ADD COLUMN IF NOT EXISTS payment_app TEXT NOT NULL DEFAULT 'Google Pay';
ALTER TABLE public.payment_settings ADD COLUMN IF NOT EXISTS qr_image_url TEXT NOT NULL DEFAULT '';
ALTER TABLE public.payment_settings ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.payment_settings ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

INSERT INTO public.payment_settings (
    id, shop_id, upi_id, payee_name, payment_app, qr_image_url, is_active, updated_at
)
VALUES (
    'campus-xerox', 'campus-xerox', '', 'Campus Xerox', 'Google Pay', '', true, now()
)
ON CONFLICT (id) DO NOTHING;

-- 1E. PRINT ORDERS TABLE
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
    shop_id TEXT NOT NULL DEFAULT 'campus-xerox',
    paper_type_name TEXT DEFAULT '',
    gsm_name TEXT DEFAULT '',
    binding_name TEXT DEFAULT '',
    special_instructions TEXT DEFAULT '',
    original_file_name TEXT DEFAULT '',
    page_selection TEXT DEFAULT '',
    is_deleted_from_queue BOOLEAN NOT NULL DEFAULT false,
    is_deleted_by_student BOOLEAN NOT NULL DEFAULT false,
    cancellation_by TEXT DEFAULT NULL,
    cancellation_reason TEXT DEFAULT NULL,
    rejection_reason TEXT DEFAULT NULL,
    refund_status TEXT DEFAULT 'NONE',
    removal_reason TEXT DEFAULT NULL,
    removed_at TIMESTAMPTZ DEFAULT NULL,
    removed_by TEXT DEFAULT NULL,
    payment_method TEXT DEFAULT '',
    transaction_reference TEXT DEFAULT '',
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

-- Migration support for existing print_orders tables:
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS shop_id TEXT NOT NULL DEFAULT 'campus-xerox';
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS bw_page_count INTEGER DEFAULT NULL;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS color_page_count INTEGER DEFAULT NULL;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS color_page_numbers JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS page_settings JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS special_instructions TEXT DEFAULT '';
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS original_file_name TEXT DEFAULT '';
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS page_selection TEXT DEFAULT '';
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS paper_type_name TEXT DEFAULT '';
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS gsm_name TEXT DEFAULT '';
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS binding_name TEXT DEFAULT '';
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS is_deleted_from_queue BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS is_deleted_by_student BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS cancellation_by TEXT DEFAULT NULL;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS cancellation_reason TEXT DEFAULT NULL;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS rejection_reason TEXT DEFAULT NULL;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS refund_status TEXT DEFAULT 'NONE';
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS removal_reason TEXT DEFAULT NULL;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS removed_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE public.print_orders ADD COLUMN IF NOT EXISTS removed_by TEXT DEFAULT NULL;

-- Collection Code format check: supports 4-digit numeric code and legacy CP- codes
ALTER TABLE public.print_orders DROP CONSTRAINT IF EXISTS chk_collection_code_format;
ALTER TABLE public.print_orders ADD CONSTRAINT chk_collection_code_format
    CHECK (code ~ '^[0-9]{4}$' OR code ~ '^CP-');

-- Prevent duplicate collection codes among active orders
CREATE UNIQUE INDEX IF NOT EXISTS idx_print_orders_active_code 
ON public.print_orders (code) 
WHERE status IN ('pending', 'accepted', 'printing', 'ready') AND is_deleted_from_queue = false;

-- 1F. EXPENSES TABLE (Shopkeeper financial records)
CREATE TABLE IF NOT EXISTS public.expenses (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    category TEXT NOT NULL DEFAULT 'supplies',
    date TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'supplies';
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS date TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_print_orders_student_id ON public.print_orders (student_id);
CREATE INDEX IF NOT EXISTS idx_print_orders_status ON public.print_orders (status);
CREATE INDEX IF NOT EXISTS idx_print_orders_created_at ON public.print_orders (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles (role);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles (email);
CREATE INDEX IF NOT EXISTS idx_services_shop_id ON public.services (shop_id);
CREATE INDEX IF NOT EXISTS idx_services_name ON public.services (service_name);

-- ==============================================================================
-- 2. EXPLICIT POSTGRESQL GRANTS (Fixes 42501 Permission Denied for 'anon')
-- ==============================================================================
-- In Supabase, newly created tables must grant USAGE and TABLE privileges to both
-- 'anon' and 'authenticated' roles so the PostgREST Data API can query and mutate them.

GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;

GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO postgres, anon, authenticated, service_role;

-- Drop legacy triggers that block operations when auth.uid() is null:
DROP TRIGGER IF EXISTS trg_check_order_update ON public.print_orders;
DROP TRIGGER IF EXISTS trg_check_profile_role ON public.profiles;

-- ==============================================================================
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.print_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

-- 3A. PROFILES POLICIES
DROP POLICY IF EXISTS "Public read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public manage profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles read policy" ON public.profiles;
DROP POLICY IF EXISTS "Profiles insert policy" ON public.profiles;
DROP POLICY IF EXISTS "Profiles update policy" ON public.profiles;
DROP POLICY IF EXISTS "Profiles allow select" ON public.profiles;
DROP POLICY IF EXISTS "Profiles allow insert" ON public.profiles;
DROP POLICY IF EXISTS "Profiles allow update" ON public.profiles;

CREATE POLICY "Profiles allow select" ON public.profiles
FOR SELECT TO authenticated, anon
USING (true);

CREATE POLICY "Profiles allow insert" ON public.profiles
FOR INSERT TO authenticated, anon
WITH CHECK (true);

CREATE POLICY "Profiles allow update" ON public.profiles
FOR UPDATE TO authenticated, anon
USING (true)
WITH CHECK (true);

-- 3B. SHOP PRICING POLICIES
DROP POLICY IF EXISTS "Anyone can view shop prices" ON public.shop_prices;
DROP POLICY IF EXISTS "Allow manage shop prices" ON public.shop_prices;
DROP POLICY IF EXISTS "Shopkeeper can modify prices" ON public.shop_prices;
DROP POLICY IF EXISTS "Prices select policy" ON public.shop_prices;
DROP POLICY IF EXISTS "Prices modify policy" ON public.shop_prices;
DROP POLICY IF EXISTS "Prices allow all" ON public.shop_prices;

CREATE POLICY "Prices allow select" ON public.shop_prices
FOR SELECT TO authenticated, anon
USING (true);

CREATE POLICY "Prices allow manage" ON public.shop_prices
FOR ALL TO authenticated, anon
USING (true)
WITH CHECK (true);

-- 3C. SERVICES POLICIES
DROP POLICY IF EXISTS "Anyone can view active services" ON public.services;
DROP POLICY IF EXISTS "Allow manage services" ON public.services;
DROP POLICY IF EXISTS "Shopkeeper can modify services" ON public.services;
DROP POLICY IF EXISTS "Services select policy" ON public.services;
DROP POLICY IF EXISTS "Services modify policy" ON public.services;

CREATE POLICY "Services allow select" ON public.services
FOR SELECT TO authenticated, anon
USING (true);

CREATE POLICY "Services allow manage" ON public.services
FOR ALL TO authenticated, anon
USING (true)
WITH CHECK (true);

-- 3D. PAYMENT SETTINGS POLICIES
DROP POLICY IF EXISTS "Anyone can view active payment settings" ON public.payment_settings;
DROP POLICY IF EXISTS "Allow manage payment settings" ON public.payment_settings;
DROP POLICY IF EXISTS "Shopkeeper can modify payment settings" ON public.payment_settings;
DROP POLICY IF EXISTS "Payment settings select policy" ON public.payment_settings;
DROP POLICY IF EXISTS "Payment settings modify policy" ON public.payment_settings;

CREATE POLICY "Payment settings allow select" ON public.payment_settings
FOR SELECT TO authenticated, anon
USING (true);

CREATE POLICY "Payment settings allow manage" ON public.payment_settings
FOR ALL TO authenticated, anon
USING (true)
WITH CHECK (true);

-- 3E. EXPENSES POLICIES
DROP POLICY IF EXISTS "Allow manage expenses" ON public.expenses;
DROP POLICY IF EXISTS "Shopkeeper only expenses" ON public.expenses;

CREATE POLICY "Expenses allow manage" ON public.expenses
FOR ALL TO authenticated, anon
USING (true)
WITH CHECK (true);

-- 3F. PRINT ORDERS POLICIES
DROP POLICY IF EXISTS "Allow manage print orders" ON public.print_orders;
DROP POLICY IF EXISTS "Orders read policy" ON public.print_orders;
DROP POLICY IF EXISTS "Orders insert policy" ON public.print_orders;
DROP POLICY IF EXISTS "Shopkeeper update orders policy" ON public.print_orders;
DROP POLICY IF EXISTS "Student update pending order policy" ON public.print_orders;
DROP POLICY IF EXISTS "Orders delete policy" ON public.print_orders;
DROP POLICY IF EXISTS "Orders allow select" ON public.print_orders;
DROP POLICY IF EXISTS "Orders allow insert" ON public.print_orders;
DROP POLICY IF EXISTS "Orders allow update" ON public.print_orders;
DROP POLICY IF EXISTS "Orders allow delete" ON public.print_orders;

CREATE POLICY "Orders allow select" ON public.print_orders
FOR SELECT TO authenticated, anon
USING (true);

CREATE POLICY "Orders allow insert" ON public.print_orders
FOR INSERT TO authenticated, anon
WITH CHECK (true);

CREATE POLICY "Orders allow update" ON public.print_orders
FOR UPDATE TO authenticated, anon
USING (true)
WITH CHECK (true);

CREATE POLICY "Orders allow delete" ON public.print_orders
FOR DELETE TO authenticated, anon
USING (true);

-- ==============================================================================
-- 4. SUPABASE STORAGE SETUP (Documents & Payment QR Buckets)
-- ==============================================================================

-- 4A. Documents Bucket (50MB, public=true for instant student upload & shopkeeper printing)
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('xerox-documents', 'xerox-documents', true, 52428800)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 52428800;

-- Drop all previous storage policies for xerox-documents
DROP POLICY IF EXISTS "Allow public uploads to xerox-documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow public downloads from xerox-documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow public updates to xerox-documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow public deletes in xerox-documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow uploads to xerox-documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow downloads from xerox-documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow deletes in xerox-documents" ON storage.objects;

CREATE POLICY "Allow public uploads to xerox-documents" ON storage.objects
FOR INSERT TO authenticated, anon
WITH CHECK (bucket_id = 'xerox-documents');

CREATE POLICY "Allow public downloads from xerox-documents" ON storage.objects
FOR SELECT TO authenticated, anon
USING (bucket_id = 'xerox-documents');

CREATE POLICY "Allow public updates to xerox-documents" ON storage.objects
FOR UPDATE TO authenticated, anon
USING (bucket_id = 'xerox-documents')
WITH CHECK (bucket_id = 'xerox-documents');

CREATE POLICY "Allow public deletes in xerox-documents" ON storage.objects
FOR DELETE TO authenticated, anon
USING (bucket_id = 'xerox-documents');

-- 4B. Payment QR Bucket (10MB, public=true for student UPI scan)
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('payment_qr', 'payment_qr', true, 10485760)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 10485760;

DROP POLICY IF EXISTS "Allow public uploads to payment_qr" ON storage.objects;
DROP POLICY IF EXISTS "Allow public downloads from payment_qr" ON storage.objects;
DROP POLICY IF EXISTS "Allow public updates to payment_qr" ON storage.objects;
DROP POLICY IF EXISTS "Allow public deletes in payment_qr" ON storage.objects;
DROP POLICY IF EXISTS "Public read payment_qr" ON storage.objects;
DROP POLICY IF EXISTS "Shopkeeper upload payment_qr" ON storage.objects;
DROP POLICY IF EXISTS "Shopkeeper update payment_qr" ON storage.objects;
DROP POLICY IF EXISTS "Shopkeeper delete payment_qr" ON storage.objects;

CREATE POLICY "Allow public uploads to payment_qr" ON storage.objects
FOR INSERT TO authenticated, anon
WITH CHECK (bucket_id = 'payment_qr');

CREATE POLICY "Allow public downloads from payment_qr" ON storage.objects
FOR SELECT TO authenticated, anon
USING (bucket_id = 'payment_qr');

CREATE POLICY "Allow public updates to payment_qr" ON storage.objects
FOR UPDATE TO authenticated, anon
USING (bucket_id = 'payment_qr')
WITH CHECK (bucket_id = 'payment_qr');

CREATE POLICY "Allow public deletes in payment_qr" ON storage.objects
FOR DELETE TO authenticated, anon
USING (bucket_id = 'payment_qr');

-- ==============================================================================
-- 5. REALTIME REPLICATION ENABLEMENT
-- ==============================================================================
ALTER TABLE public.print_orders REPLICA IDENTITY FULL;
ALTER TABLE public.shop_prices REPLICA IDENTITY FULL;
ALTER TABLE public.payment_settings REPLICA IDENTITY FULL;
ALTER TABLE public.services REPLICA IDENTITY FULL;
ALTER TABLE public.expenses REPLICA IDENTITY FULL;

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
        ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_settings;
    EXCEPTION WHEN duplicate_object THEN
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.services;
    EXCEPTION WHEN duplicate_object THEN
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.expenses;
    EXCEPTION WHEN duplicate_object THEN
    END;
END $$;
