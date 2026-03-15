-- Run this in your Supabase SQL Editor to update the profiles table

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS dietary_preference TEXT DEFAULT 'None';

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS name TEXT DEFAULT 'User';

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS fitness_level TEXT DEFAULT 'Beginner';

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS daily_step_goal INTEGER DEFAULT 10000;

-- Function to handle new user creation and sync name from auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, name)
  VALUES (
    new.id,
    COALESCE(
      new.raw_user_meta_data->>'display_name',
      new.raw_user_meta_data->>'full_name',
      'User'
    )
  )
  ON CONFLICT (id) DO UPDATE
  SET name = EXCLUDED.name
  WHERE profiles.name = 'User'; -- Only update if name is still default
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function when a new user signs up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE;

-- Verify the table structure
SELECT * FROM public.profiles LIMIT 1;

-- Creating `user_memories` table for the AI Memory Vault
CREATE TABLE IF NOT EXISTS public.user_memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_active BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS for `user_memories`
ALTER TABLE public.user_memories ENABLE ROW LEVEL SECURITY;

-- Policies for `user_memories`
CREATE POLICY "Users can view their own memories" 
ON public.user_memories FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own memories" 
ON public.user_memories FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own memories" 
ON public.user_memories FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own memories" 
ON public.user_memories FOR DELETE USING (auth.uid() = user_id);
