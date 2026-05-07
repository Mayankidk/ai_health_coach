create table if not exists public.user_memories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_memories enable row level security;

drop policy if exists "Users can view their own memories" on public.user_memories;
create policy "Users can view their own memories"
on public.user_memories for select
using (auth.uid() = user_id);

drop policy if exists "Users can insert their own memories" on public.user_memories;
create policy "Users can insert their own memories"
on public.user_memories for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can update their own memories" on public.user_memories;
create policy "Users can update their own memories"
on public.user_memories for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own memories" on public.user_memories;
create policy "Users can delete their own memories"
on public.user_memories for delete
using (auth.uid() = user_id);

create index if not exists user_memories_user_id_created_at_idx
on public.user_memories (user_id, created_at desc);
