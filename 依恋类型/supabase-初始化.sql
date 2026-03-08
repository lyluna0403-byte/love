-- 依恋类型测评 Supabase 初始化脚本
-- 在 Supabase SQL Editor 一次性执行

create table if not exists public.redeem_codes (
  code text primary key,
  is_used boolean not null default false,
  used_at timestamptz,
  used_session_id text,
  created_at timestamptz not null default now()
);

create table if not exists public.attachment_submissions (
  id bigint generated always as identity primary key,
  redeem_code text not null references public.redeem_codes(code),
  session_id text not null,
  submitted_at timestamptz not null default now(),
  answers jsonb not null,
  results jsonb not null
);

alter table public.redeem_codes enable row level security;
alter table public.attachment_submissions enable row level security;

-- 清理旧策略，避免重复执行报错
 drop policy if exists redeem_codes_select_all on public.redeem_codes;
 drop policy if exists redeem_codes_update_all on public.redeem_codes;
 drop policy if exists submissions_insert_all on public.attachment_submissions;
 drop policy if exists submissions_select_all on public.attachment_submissions;

-- 测评端需要：查询兑换码、标记兑换码已使用、插入作答
create policy redeem_codes_select_all on public.redeem_codes
for select to anon, authenticated
using (true);

create policy redeem_codes_update_all on public.redeem_codes
for update to anon, authenticated
using (true)
with check (true);

create policy submissions_insert_all on public.attachment_submissions
for insert to anon, authenticated
with check (true);

-- 独立后台页面如使用 anon key 拉取数据，需要读权限
create policy submissions_select_all on public.attachment_submissions
for select to anon, authenticated
using (true);

-- 生成 400 个兑换码（格式：YL-XXXXX-XXXXX）
with raw as (
  select upper(substr(md5(random()::text || clock_timestamp()::text || g::text), 1, 10)) as s
  from generate_series(1, 1600) g
), picked as (
  select distinct ('YL-' || substr(s, 1, 5) || '-' || substr(s, 6, 5)) as code
  from raw
  limit 400
)
insert into public.redeem_codes (code)
select code from picked
on conflict (code) do nothing;

select count(*) as redeem_code_count from public.redeem_codes;
