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
    payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'failed', 'refundPending', 'refunded')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'printing', 'ready', 'completed', 'cancelled', 'rejected')),
    is_downloaded BOOLEAN NOT NULL DEFAULT false,
    is_purged BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

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

-- Print Orders Policies: Students & Shopkeeper can view and manage orders
DROP POLICY IF EXISTS "Allow manage print orders" ON public.print_orders;
CREATE POLICY "Allow manage print orders" ON public.print_orders FOR ALL USING (true);

-- Expenses Policies
DROP POLICY IF EXISTS "Allow manage expenses" ON public.expenses;
CREATE POLICY "Allow manage expenses" ON public.expenses FOR ALL USING (true);

-- ==============================================================================
-- 6. SUPABASE STORAGE SETUP (50 MB Limit for Print Documents)
-- ==============================================================================
-- Create the bucket 'xerox-documents' with 50MB (52,428,800 bytes) file size limit
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES (
    'xerox-documents',
    'xerox-documents',
    true, -- Public bucket for instant previewing & reliable cross-device downloading
    52428800 -- 50 Megabytes in bytes
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 52428800;

-- Storage Policies for 'xerox-documents' (Permit upload, read, update, delete)
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

-- ==============================================================================
-- 7. REALTIME REPLICATION ENABLEMENT (Safe idempotent execution)
-- ==============================================================================
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.print_orders;
    EXCEPTION WHEN duplicate_object THEN
        -- already member of publication, ignore safely
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.shop_prices;
    EXCEPTION WHEN duplicate_object THEN
        -- already member of publication, ignore safely
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.expenses;
    EXCEPTION WHEN duplicate_object THEN
        -- already member of publication, ignore safely
    END;
END $$;
