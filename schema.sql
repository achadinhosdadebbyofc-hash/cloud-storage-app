-- Execute no SQL Editor do Supabase.
create extension if not exists pgcrypto;
create table if not exists public.folders(
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null check(char_length(name) between 1 and 120),
 parent_id uuid references public.folders(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table if not exists public.assets(
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null, object_path text not null unique,
 mime_type text not null default 'application/octet-stream',
 size_bytes bigint not null default 0 check(size_bytes>=0),
 folder_id uuid references public.folders(id) on delete set null,
 is_starred boolean not null default false,
 created_at timestamptz not null default now(), deleted_at timestamptz
);
create index if not exists assets_owner_created_idx on public.assets(owner_id,created_at desc);
alter table public.folders enable row level security;
alter table public.assets enable row level security;
create policy "folder read own" on public.folders for select using(auth.uid()=owner_id);
create policy "folder insert own" on public.folders for insert with check(auth.uid()=owner_id);
create policy "folder update own" on public.folders for update using(auth.uid()=owner_id) with check(auth.uid()=owner_id);
create policy "folder delete own" on public.folders for delete using(auth.uid()=owner_id);
create policy "asset read own" on public.assets for select using(auth.uid()=owner_id);
create policy "asset insert own" on public.assets for insert with check(auth.uid()=owner_id);
create policy "asset update own" on public.assets for update using(auth.uid()=owner_id) with check(auth.uid()=owner_id);
create policy "asset delete own" on public.assets for delete using(auth.uid()=owner_id);
insert into storage.buckets(id,name,public,file_size_limit)
values('cloud-assets','cloud-assets',false,524288000) on conflict(id) do update set public=false;
create policy "cloud objects read own" on storage.objects for select to authenticated
using(bucket_id='cloud-assets' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "cloud objects insert own" on storage.objects for insert to authenticated
with check(bucket_id='cloud-assets' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "cloud objects update own" on storage.objects for update to authenticated
using(bucket_id='cloud-assets' and (storage.foldername(name))[1]=auth.uid()::text)
with check(bucket_id='cloud-assets' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "cloud objects delete own" on storage.objects for delete to authenticated
using(bucket_id='cloud-assets' and (storage.foldername(name))[1]=auth.uid()::text);

-- Cota lógica por usuário: 500 GiB. A cota do provedor/billing deve ser
-- contratada separadamente. Este gatilho protege os metadados da aplicação.
create or replace function public.enforce_user_storage_quota()
returns trigger language plpgsql security definer set search_path=public as $$
declare current_bytes bigint;
begin
  if tg_op='UPDATE' and new.owner_id<>old.owner_id then
    raise exception 'Não é permitido transferir arquivos entre proprietários.';
  end if;
  select coalesce(sum(size_bytes),0) into current_bytes
    from public.assets
   where owner_id=new.owner_id and deleted_at is null
     and (tg_op<>'UPDATE' or id<>old.id);
  if new.deleted_at is null and current_bytes + new.size_bytes > 536870912000 then
    raise exception 'Cota de armazenamento de 500 GiB excedida.';
  end if;
  return new;
end; $$;
drop trigger if exists assets_quota_guard on public.assets;
create trigger assets_quota_guard before insert or update of size_bytes,deleted_at,owner_id
on public.assets for each row execute function public.enforce_user_storage_quota();

-- O bucket é privado. O frontend deve usar URLs assinadas de curta duração.
