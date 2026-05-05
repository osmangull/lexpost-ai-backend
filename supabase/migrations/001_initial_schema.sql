-- ============================================================
-- LexPost AI - Supabase Schema
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================================
-- USERS (extends Supabase auth.users)
-- ============================================================
create table public.profiles (
    id          uuid primary key references auth.users(id) on delete cascade,
    full_name   text,
    bar_number  text,                          -- Turkish Bar Association number
    firm_name   text,
    plan        text not null default 'free',  -- 'free' | 'pro'
    revenuecat_id text,
    fcm_token   text,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
    on public.profiles for select
    using (auth.uid() = id);

create policy "Users can update own profile"
    on public.profiles for update
    using (auth.uid() = id);

-- ============================================================
-- LEGAL UPDATES (scraped from Resmi Gazete)
-- ============================================================
create table public.legal_updates (
    id              uuid primary key default uuid_generate_v4(),
    title           text not null,
    document_type   text not null check (document_type in ('Yönetmelik', 'Tebliğ', 'Karar')),
    gazette_date    date not null,
    gazette_number  text not null,
    source_url      text not null unique,
    raw_content     text,
    ai_summary      text,
    created_at      timestamptz not null default now()
);

create index idx_legal_updates_date on public.legal_updates (gazette_date desc);
create index idx_legal_updates_type on public.legal_updates (document_type);

-- Public read access (no auth required for browsing updates)
alter table public.legal_updates enable row level security;
create policy "Public read legal updates"
    on public.legal_updates for select
    using (true);

-- ============================================================
-- TEMPLATES (10 pre-defined background templates)
-- ============================================================
create table public.templates (
    id                  uuid primary key default uuid_generate_v4(),
    name                text not null,
    theme               text not null check (theme in ('law', 'office', 'minimalist')),
    background_filename text not null,
    background_url      text,
    preview_url         text,
    sort_order          integer not null default 0,
    is_pro              boolean not null default false,
    created_at          timestamptz not null default now()
);

alter table public.templates enable row level security;
create policy "Public read templates"
    on public.templates for select
    using (true);

-- ============================================================
-- GENERATED POSTS
-- ============================================================
create table public.generated_posts (
    id                uuid primary key default uuid_generate_v4(),
    user_id           uuid not null references public.profiles(id) on delete cascade,
    legal_update_id   uuid not null references public.legal_updates(id) on delete cascade,
    template_id       uuid not null references public.templates(id),
    font_style        text not null check (font_style in ('classic', 'modern')),
    image_url         text not null,
    caption           text,
    status            text not null default 'generated' check (status in ('draft', 'generated', 'shared')),
    created_at        timestamptz not null default now()
);

create index idx_generated_posts_user on public.generated_posts (user_id, created_at desc);

alter table public.generated_posts enable row level security;

create policy "Users can read own posts"
    on public.generated_posts for select
    using (auth.uid() = user_id);

create policy "Users can insert own posts"
    on public.generated_posts for insert
    with check (auth.uid() = user_id);

create policy "Users can delete own posts"
    on public.generated_posts for delete
    using (auth.uid() = user_id);

-- ============================================================
-- Supabase Storage buckets (run in dashboard or via CLI)
-- ============================================================
-- insert into storage.buckets (id, name, public) values ('generated-posts', 'generated-posts', true);
-- insert into storage.buckets (id, name, public) values ('backgrounds', 'backgrounds', true);
