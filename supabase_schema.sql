-- Run this in your Supabase SQL Editor to update the profiles table

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS dietary_preference TEXT DEFAULT 'None';

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS name TEXT DEFAULT 'User';

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS fitness_level TEXT DEFAULT 'Beginner';

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS daily_step_goal INTEGER DEFAULT 10000;

-- Verify the table structure
SELECT * FROM public.profiles LIMIT 1;
