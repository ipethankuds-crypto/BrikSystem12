-- ==============================================================================
-- Brik Systems — Multi-Tenant Architecture & Row Level Security (RLS)
-- Foundation for Authentication, Client Accounts & Multi-Tenancy
-- ==============================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 2. ENUMS & TYPES
-- ------------------------------------------------------------------------------
-- Representing system roles:
-- ADMIN: Brik Administrator (can create & manage client organizations and accounts)
-- CLIENT: Client user (restricted strictly to their own organization's dashboard & data)
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('ADMIN', 'CLIENT');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ------------------------------------------------------------------------------
-- 3. ORGANIZATIONS / CLIENTS (TENANTS)
-- Each local business client is an Organization with a unique UUID.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    business_type VARCHAR(100) NOT NULL DEFAULT 'General Contractor',
    phone VARCHAR(50),
    email VARCHAR(255),
    address VARCHAR(255),
    city VARCHAR(100),
    province VARCHAR(100),
    postal_code VARCHAR(20),
    logo_url TEXT,
    website_domain VARCHAR(255),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Backward compatibility alias view/table if needed
CREATE OR REPLACE VIEW businesses AS SELECT * FROM organizations;

-- ------------------------------------------------------------------------------
-- 4. USER PROFILES
-- Every authenticated user in Supabase Auth (auth.users) has a profile row
-- linking them to their Organization and Role.
-- Relationship: Many Users -> One Organization (Multi-User per Client support)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    role user_role NOT NULL DEFAULT 'CLIENT',
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    avatar_url TEXT,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index for fast lookup by organization
CREATE INDEX IF NOT EXISTS idx_profiles_organization_id ON profiles(organization_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_organizations_slug ON organizations(slug);

-- ------------------------------------------------------------------------------
-- 5. FUTURE DATA TABLES (PREPARED FOR MULTI-TENANT ISOLATION)
-- Every record belongs to an organization_id.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50) NOT NULL,
    address VARCHAR(255),
    city VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_name VARCHAR(255) NOT NULL,
    service VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    scheduled_date DATE,
    scheduled_time VARCHAR(50),
    price NUMERIC(10, 2) DEFAULT 0.00,
    technician VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS leads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50) NOT NULL,
    service_requested VARCHAR(255) NOT NULL,
    source VARCHAR(100) DEFAULT 'Website Form',
    status VARCHAR(50) NOT NULL DEFAULT 'NEW',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    author_name VARCHAR(255) NOT NULL,
    service VARCHAR(255),
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    status VARCHAR(50) DEFAULT 'COMPLETED',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_customers_org ON customers(organization_id);
CREATE INDEX IF NOT EXISTS idx_jobs_org ON jobs(organization_id);
CREATE INDEX IF NOT EXISTS idx_leads_org ON leads(organization_id);
CREATE INDEX IF NOT EXISTS idx_reviews_org ON reviews(organization_id);

-- ------------------------------------------------------------------------------
-- 6. SECURITY HELPER FUNCTIONS
-- ------------------------------------------------------------------------------

-- Returns the organization_id of the currently authenticated user
CREATE OR REPLACE FUNCTION get_auth_user_organization_id()
RETURNS UUID AS $$
    SELECT organization_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Checks if the currently authenticated user has the ADMIN role
CREATE OR REPLACE FUNCTION is_brik_admin()
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() AND role = 'ADMIN' AND active = true
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ------------------------------------------------------------------------------
-- 7. ROW LEVEL SECURITY (RLS) POLICIES
-- Strict multi-tenant isolation enforced at the PostgreSQL engine level.
-- ------------------------------------------------------------------------------

-- Enable RLS on all tables
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- ORGANIZATIONS POLICIES
-- ==============================================================================
-- 1. Brik Admin can view and manage ALL organizations
CREATE POLICY "Admins have full access to all organizations"
    ON organizations FOR ALL
    TO authenticated
    USING (is_brik_admin())
    WITH CHECK (is_brik_admin());

-- 2. Client users can only SELECT their own organization record
CREATE POLICY "Clients can view their own organization"
    ON organizations FOR SELECT
    TO authenticated
    USING (id = get_auth_user_organization_id());

-- 3. Client users can update specific fields of their own organization (e.g. phone, address)
CREATE POLICY "Clients can update their own organization"
    ON organizations FOR UPDATE
    TO authenticated
    USING (id = get_auth_user_organization_id())
    WITH CHECK (id = get_auth_user_organization_id());

-- ==============================================================================
-- PROFILES POLICIES
-- ==============================================================================
-- 1. Admins have full access to all user profiles
CREATE POLICY "Admins have full access to all profiles"
    ON profiles FOR ALL
    TO authenticated
    USING (is_brik_admin())
    WITH CHECK (is_brik_admin());

-- 2. Users can read their own profile and peer profiles in the same organization
CREATE POLICY "Users can view profiles in their own organization"
    ON profiles FOR SELECT
    TO authenticated
    USING (organization_id = get_auth_user_organization_id() OR id = auth.uid());

-- 3. Users can update their own profile details
CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- ==============================================================================
-- CUSTOMERS, JOBS, LEADS, REVIEWS POLICIES (TENANT ISOLATION)
-- ==============================================================================

-- CUSTOMERS:
CREATE POLICY "Tenant isolation for customers"
    ON customers FOR ALL
    TO authenticated
    USING (organization_id = get_auth_user_organization_id() OR is_brik_admin())
    WITH CHECK (organization_id = get_auth_user_organization_id() OR is_brik_admin());

-- JOBS:
CREATE POLICY "Tenant isolation for jobs"
    ON jobs FOR ALL
    TO authenticated
    USING (organization_id = get_auth_user_organization_id() OR is_brik_admin())
    WITH CHECK (organization_id = get_auth_user_organization_id() OR is_brik_admin());

-- LEADS:
CREATE POLICY "Tenant isolation for leads"
    ON leads FOR ALL
    TO authenticated
    USING (organization_id = get_auth_user_organization_id() OR is_brik_admin())
    WITH CHECK (organization_id = get_auth_user_organization_id() OR is_brik_admin());

-- Public can insert leads (e.g. contact form) with valid organization_id
CREATE POLICY "Public website can submit leads"
    ON leads FOR INSERT
    TO anon
    WITH CHECK (true);

-- REVIEWS:
CREATE POLICY "Tenant isolation for reviews"
    ON reviews FOR ALL
    TO authenticated
    USING (organization_id = get_auth_user_organization_id() OR is_brik_admin())
    WITH CHECK (organization_id = get_auth_user_organization_id() OR is_brik_admin());

-- ------------------------------------------------------------------------------
-- 8. DEMO SEED DATA SCRIPT (FOR DEXTER'S CLIENT ACCOUNT)
-- Run this in the Supabase SQL Editor after creating dexter125555@gmail.com in Auth
-- ------------------------------------------------------------------------------
/*
-- Step A: Insert Demo Client Organization
INSERT INTO organizations (id, name, slug, business_type, phone, email, address, city, province)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'Northside Plumbing & Heating',
    'northside-plumbing',
    'Plumbing & Heating',
    '(416) 555-0100',
    'dexter125555@gmail.com',
    '142 King St West',
    'Toronto',
    'ON'
) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- Step B: Link Dexter's Supabase Auth user to the Organization
-- Note: Replace with the actual User UID generated by Supabase Auth for dexter125555@gmail.com
DO $$
DECLARE
    dexter_auth_id UUID;
BEGIN
    SELECT id INTO dexter_auth_id FROM auth.users WHERE email = 'dexter125555@gmail.com' LIMIT 1;
    
    IF dexter_auth_id IS NOT NULL THEN
        INSERT INTO profiles (id, organization_id, role, full_name, email, phone)
        VALUES (
            dexter_auth_id,
            '00000000-0000-0000-0000-000000000001',
            'CLIENT',
            'Dexter',
            'dexter125555@gmail.com',
            '(416) 555-0100'
        ) ON CONFLICT (id) DO UPDATE 
        SET organization_id = EXCLUDED.organization_id, role = 'CLIENT', full_name = 'Dexter';
    END IF;
END $$;
*/
