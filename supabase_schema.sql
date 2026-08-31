-- ==============================================================================
-- BrikSystem12 - Multi-Tenant SaaS Platform for Local Service Businesses
-- PostgreSQL & Supabase Database Schema with Row Level Security (RLS)
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 1. ENUMS
-- ------------------------------------------------------------------------------
CREATE TYPE user_role AS ENUM ('OWNER', 'ADMIN', 'STAFF', 'TECHNICIAN');
CREATE TYPE lead_status AS ENUM ('NEW', 'CONTACTED', 'QUALIFIED', 'BOOKED', 'LOST', 'CONVERTED');
CREATE TYPE job_status AS ENUM ('SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');
CREATE TYPE appointment_status AS ENUM ('SCHEDULED', 'CONFIRMED', 'COMPLETED', 'CANCELLED', 'NO_SHOW');
CREATE TYPE review_request_status AS ENUM ('PENDING', 'SENT', 'COMPLETED', 'EXPIRED');
CREATE TYPE message_channel AS ENUM ('SMS', 'EMAIL', 'SYSTEM');
CREATE TYPE message_direction AS ENUM ('INBOUND', 'OUTBOUND');

-- ------------------------------------------------------------------------------
-- 2. BUSINESSES (TENANTS)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS businesses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    business_type VARCHAR(100) NOT NULL, -- e.g. 'plumber', 'electrician', 'hvac', 'roofer'
    phone VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    address VARCHAR(255),
    city VARCHAR(100),
    province VARCHAR(100),
    postal_code VARCHAR(20),
    logo_url TEXT,
    website_domain VARCHAR(255),
    description TEXT,
    business_hours JSONB DEFAULT '{"monday": "8:00 AM - 5:00 PM", "tuesday": "8:00 AM - 5:00 PM", "wednesday": "8:00 AM - 5:00 PM", "thursday": "8:00 AM - 5:00 PM", "friday": "8:00 AM - 5:00 PM", "saturday": "9:00 AM - 2:00 PM", "sunday": "Closed"}'::jsonb,
    timezone VARCHAR(50) DEFAULT 'America/New_York',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 3. PROFILES / USERS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_user_id UUID UNIQUE, -- References auth.users(id) in Supabase
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    role user_role NOT NULL DEFAULT 'STAFF',
    avatar_url TEXT,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 4. CUSTOMERS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50) NOT NULL,
    address VARCHAR(255),
    city VARCHAR(100),
    province VARCHAR(100),
    postal_code VARCHAR(20),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 5. LEADS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS leads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50) NOT NULL,
    service_requested VARCHAR(255) NOT NULL,
    description TEXT,
    preferred_time VARCHAR(100),
    source VARCHAR(100) DEFAULT 'Website Form', -- 'Website Form', 'Phone Call', 'Referral', etc.
    status lead_status NOT NULL DEFAULT 'NEW',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 6. SERVICES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price_description VARCHAR(100), -- e.g. '$150/hr' or 'Starting at $299'
    estimated_duration_minutes INT DEFAULT 60,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 7. JOBS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    lead_id UUID REFERENCES leads(id) ON DELETE SET NULL,
    service_id UUID REFERENCES services(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    service VARCHAR(255) NOT NULL,
    description TEXT,
    scheduled_date DATE NOT NULL,
    scheduled_time VARCHAR(50),
    assigned_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    status job_status NOT NULL DEFAULT 'SCHEDULED',
    price NUMERIC(10, 2) DEFAULT 0.00,
    notes TEXT,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 8. APPOINTMENTS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
    lead_id UUID REFERENCES leads(id) ON DELETE SET NULL,
    job_id UUID REFERENCES jobs(id) ON DELETE SET NULL,
    assigned_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    status appointment_status NOT NULL DEFAULT 'SCHEDULED',
    service_type VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 9. REVIEWS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    job_id UUID REFERENCES jobs(id) ON DELETE SET NULL,
    author_name VARCHAR(255) NOT NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    request_status review_request_status DEFAULT 'COMPLETED',
    requested_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    review_url TEXT,
    public_display BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 10. AUTOMATION RULES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS automation_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    trigger_type VARCHAR(100) NOT NULL, -- 'job_completed', 'lead_created', 'appointment_scheduled', 'appointment_reminder'
    delay_minutes INT DEFAULT 0,
    channel message_channel NOT NULL DEFAULT 'SMS',
    message_template TEXT NOT NULL,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 11. MESSAGES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    lead_id UUID REFERENCES leads(id) ON DELETE SET NULL,
    job_id UUID REFERENCES jobs(id) ON DELETE SET NULL,
    channel message_channel NOT NULL DEFAULT 'SMS',
    direction message_direction NOT NULL DEFAULT 'OUTBOUND',
    recipient VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'SENT', -- 'QUEUED', 'SENT', 'DELIVERED', 'FAILED'
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 12. WEBSITE SETTINGS (PUBLIC WEBSITE BUILDER CONFIG)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS website_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID UNIQUE NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    headline VARCHAR(255) NOT NULL DEFAULT 'Fast, Reliable & Trusted Local Experts',
    subheadline TEXT DEFAULT 'Licensed & insured professionals providing top-rated services for your home and commercial property.',
    about_text TEXT DEFAULT 'We are proud to serve our local community with dependable, top-tier craftsmanship, transparent upfront pricing, and 24/7 customer support.',
    logo_url TEXT,
    hero_image_url TEXT,
    primary_phone VARCHAR(50),
    primary_email VARCHAR(255),
    address VARCHAR(255),
    service_area_text VARCHAR(255) DEFAULT 'Proudly serving Metro and surrounding communities within a 45-mile radius',
    cta_text VARCHAR(100) DEFAULT 'Get a Free Quote & Schedule Service',
    theme_settings JSONB DEFAULT '{"primaryColor": "#2563eb", "secondaryColor": "#1e293b", "accentColor": "#f59e0b", "fontFamily": "Inter"}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 13. INDEXES FOR MULTI-TENANT QUERY PERFORMANCE
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_businesses_slug ON businesses(slug);
CREATE INDEX IF NOT EXISTS idx_profiles_business ON profiles(business_id);
CREATE INDEX IF NOT EXISTS idx_customers_business ON customers(business_id);
CREATE INDEX IF NOT EXISTS idx_leads_business ON leads(business_id);
CREATE INDEX IF NOT EXISTS idx_jobs_business ON jobs(business_id);
CREATE INDEX IF NOT EXISTS idx_appointments_business ON appointments(business_id);
CREATE INDEX IF NOT EXISTS idx_services_business ON services(business_id);
CREATE INDEX IF NOT EXISTS idx_reviews_business ON reviews(business_id);
CREATE INDEX IF NOT EXISTS idx_automations_business ON automation_rules(business_id);
CREATE INDEX IF NOT EXISTS idx_messages_business ON messages(business_id);
CREATE INDEX IF NOT EXISTS idx_website_settings_business ON website_settings(business_id);

-- ------------------------------------------------------------------------------
-- 14. ROW LEVEL SECURITY (RLS) POLICIES
-- ------------------------------------------------------------------------------
ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE automation_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE website_settings ENABLE ROW LEVEL SECURITY;

-- Helper function to extract user's business_id from JWT / profile
CREATE OR REPLACE FUNCTION get_current_user_business_id()
RETURNS UUID AS $$
    SELECT business_id FROM profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Public read policies for Public Website
CREATE POLICY "Public website can view business public info"
    ON businesses FOR SELECT USING (true);

CREATE POLICY "Public website can view website settings"
    ON website_settings FOR SELECT USING (true);

CREATE POLICY "Public website can view active services"
    ON services FOR SELECT USING (active = true);

CREATE POLICY "Public website can view public reviews"
    ON reviews FOR SELECT USING (public_display = true);

-- Public can submit leads and reviews
CREATE POLICY "Public can submit new leads"
    ON leads FOR INSERT WITH CHECK (true);

CREATE POLICY "Public can submit new reviews"
    ON reviews FOR INSERT WITH CHECK (true);

-- Authenticated Multi-Tenant Policies (Strict isolation by business_id)
CREATE POLICY "Users can access their own business"
    ON businesses FOR ALL
    USING (id = get_current_user_business_id());

CREATE POLICY "Users can access profiles of their business"
    ON profiles FOR ALL
    USING (business_id = get_current_user_business_id());

CREATE POLICY "Users can access customers of their business"
    ON customers FOR ALL
    USING (business_id = get_current_user_business_id());

CREATE POLICY "Users can access leads of their business"
    ON leads FOR ALL
    USING (business_id = get_current_user_business_id());

CREATE POLICY "Users can manage services of their business"
    ON services FOR ALL
    USING (business_id = get_current_user_business_id());

CREATE POLICY "Users can access jobs of their business"
    ON jobs FOR ALL
    USING (business_id = get_current_user_business_id());

CREATE POLICY "Users can access appointments of their business"
    ON appointments FOR ALL
    USING (business_id = get_current_user_business_id());

CREATE POLICY "Users can access reviews of their business"
    ON reviews FOR ALL
    USING (business_id = get_current_user_business_id());

CREATE POLICY "Users can access automations of their business"
    ON automation_rules FOR ALL
    USING (business_id = get_current_user_business_id());

CREATE POLICY "Users can access messages of their business"
    ON messages FOR ALL
    USING (business_id = get_current_user_business_id());

CREATE POLICY "Users can manage website settings of their business"
    ON website_settings FOR ALL
    USING (business_id = get_current_user_business_id());
