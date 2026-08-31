import { createClient } from '@supabase/supabase-js';

// Support Vite import.meta.env, process.env, or browser window globals
const SUPABASE_URL: string =
  (typeof import.meta !== 'undefined' && (import.meta as any).env?.VITE_SUPABASE_URL) ||
  (typeof window !== 'undefined' && (window as any).__SUPABASE_URL__) ||
  'https://qrrdmhwpiiwtixofyvqf.supabase.co';

const SUPABASE_ANON_KEY: string =
  (typeof import.meta !== 'undefined' && (import.meta as any).env?.VITE_SUPABASE_ANON_KEY) ||
  (typeof window !== 'undefined' && (window as any).__SUPABASE_ANON_KEY__) ||
  '';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY || 'placeholder-anon-key', {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

export interface Organization {
  id: string;
  name: string;
  slug: string;
  business_type: string;
  phone?: string;
  email?: string;
  address?: string;
  city?: string;
  province?: string;
  postal_code?: string;
  active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Profile {
  id: string;
  organization_id: string;
  role: 'ADMIN' | 'CLIENT';
  full_name: string;
  email: string;
  phone?: string;
  avatar_url?: string;
  active: boolean;
  created_at: string;
  updated_at: string;
  organization?: Organization;
}
