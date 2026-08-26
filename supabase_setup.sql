-- ========================================================================================
-- FILE: supabase_setup.sql
-- DESCRIPTION: Core Database Schema & Security Configuration for Toolbox PRO
-- IMPORTANT: Run this entire script in the Supabase SQL Editor.
-- ========================================================================================

-- 1. Create custom ENUMs
CREATE TYPE public.plan_type AS ENUM ('free', 'pro', 'business');
CREATE TYPE public.conversion_status AS ENUM ('started', 'completed', 'failed', 'cancelled');

-- 2. Create `profiles` table
CREATE TABLE public.profiles (
    id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create `entitlements` table
CREATE TABLE public.entitlements (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    plan plan_type DEFAULT 'free'::plan_type NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create `conversion_history` table
CREATE TABLE public.conversion_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tool_id TEXT NOT NULL,
    input_format TEXT,
    output_format TEXT,
    file_size BIGINT,
    status conversion_status DEFAULT 'started'::conversion_status NOT NULL,
    processing_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Create `ai_usage` table
CREATE TABLE public.ai_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    model TEXT NOT NULL,
    feature TEXT NOT NULL,
    input_tokens INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0,
    total_tokens INTEGER DEFAULT 0,
    estimated_cost_usd NUMERIC(10,6) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ========================================================================================
-- INDEXES
-- ========================================================================================
CREATE INDEX idx_conversion_history_user_id ON public.conversion_history(user_id, created_at DESC);
CREATE INDEX idx_ai_usage_user_id ON public.ai_usage(user_id, created_at DESC);

-- ========================================================================================
-- ROW LEVEL SECURITY (RLS)
-- ========================================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversion_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can read and update their OWN profile.
CREATE POLICY "Users can view own profile" 
ON public.profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" 
ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Entitlements: Users can READ their own entitlement, but CANNOT update it directly.
CREATE POLICY "Users can view own entitlement" 
ON public.entitlements FOR SELECT USING (auth.uid() = user_id);
-- (No UPDATE or INSERT policy provided for entitlements. This prevents users from upgrading themselves to 'pro'. Only service_role keys / Edge Functions can update this.)

-- Conversion History: Users can view and insert their own history.
CREATE POLICY "Users can view own history" 
ON public.conversion_history FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own history" 
ON public.conversion_history FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own history status" 
ON public.conversion_history FOR UPDATE USING (auth.uid() = user_id);

-- AI Usage: Users can view their own AI usage (insertion is handled server-side only via Edge Functions)
CREATE POLICY "Users can view own ai usage" 
ON public.ai_usage FOR SELECT USING (auth.uid() = user_id);

-- ========================================================================================
-- TRIGGERS & FUNCTIONS
-- ========================================================================================

-- Function: Automatically create a profile and free entitlement when a new auth.user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  -- Insert into profiles
  INSERT INTO public.profiles (id, email)
  VALUES (new.id, new.email);
  
  -- Insert into entitlements (defaults to 'free')
  INSERT INTO public.entitlements (user_id)
  VALUES (new.id);
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Fire the function AFTER INSERT on auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ========================================================================================
-- STORAGE CONFIGURATION
-- ========================================================================================
-- Note: Create a bucket named "user_files" in the Supabase Dashboard, set it to PRIVATE.

-- Run these policies in the SQL editor to secure the bucket:
-- CREATE POLICY "Users can upload their own files" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'user_files' AND auth.uid()::text = (storage.foldername(name))[1]);
-- CREATE POLICY "Users can update their own files" ON storage.objects FOR UPDATE USING (bucket_id = 'user_files' AND auth.uid()::text = (storage.foldername(name))[1]);
-- CREATE POLICY "Users can view their own files" ON storage.objects FOR SELECT USING (bucket_id = 'user_files' AND auth.uid()::text = (storage.foldername(name))[1]);
-- CREATE POLICY "Users can delete their own files" ON storage.objects FOR DELETE USING (bucket_id = 'user_files' AND auth.uid()::text = (storage.foldername(name))[1]);
