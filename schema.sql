-- Attendance Marker: database schema for Supabase
-- Run this whole file once in: Supabase dashboard -> SQL Editor -> New query -> Run

-- 1. COURSES: one row per course + section + semester
create table if not exists public.courses (
  id          bigint generated always as identity primary key,
  code        text not null,
  name        text not null,
  section     text not null,
  semester    text not null,
  instructor  text,
  created_at  timestamptz not null default now(),
  unique (code, section, semester)          -- used by upsert onConflict "code,section,semester"
);

-- 2. STUDENTS: one row per student, roll number is unique
create table if not exists public.students (
  id          bigint generated always as identity primary key,
  roll_no     text not null unique,         -- used by upsert onConflict "roll_no"
  name        text not null,
  created_at  timestamptz not null default now()
);

-- 3. ENROLLMENTS: links students to courses (many-to-many)
create table if not exists public.enrollments (
  id          bigint generated always as identity primary key,
  course_id   bigint not null references public.courses(id)  on delete cascade,
  student_id  bigint not null references public.students(id) on delete cascade,
  unique (course_id, student_id)            -- used by upsert onConflict "course_id,student_id"
);

-- 4. SESSIONS: one lecture on one day for one course
create table if not exists public.sessions (
  id            bigint generated always as identity primary key,
  course_id     bigint not null references public.courses(id) on delete cascade,
  session_date  date not null,
  start_time    time not null,
  end_time      time not null,
  created_at    timestamptz not null default now(),
  check (end_time > start_time),
  unique (course_id, session_date, start_time)
);

-- 5. ATTENDANCE: one row per student per session
create table if not exists public.attendance (
  id          bigint generated always as identity primary key,
  session_id  bigint not null references public.sessions(id) on delete cascade,
  student_id  bigint not null references public.students(id) on delete cascade,
  status      text not null default 'present'
              check (status in ('present', 'absent', 'late')),
  unique (session_id, student_id)           -- used by upsert onConflict "session_id,student_id"
);

-- Indexes for the lookups the app does
create index if not exists enrollments_course_idx on public.enrollments (course_id);
create index if not exists sessions_course_idx    on public.sessions (course_id, session_date desc);
create index if not exists attendance_session_idx on public.attendance (session_id);

-- ---------------------------------------------------------------
-- ACCESS RULES (Row Level Security)
-- The app has no login: it uses the public "publishable" key.
-- So we let the anon role read, insert and update. (No delete.)
-- NOTE: this means anyone who has your site link can read/write
-- the data. Fine for a prototype; add login before real use.
-- ---------------------------------------------------------------
alter table public.courses     enable row level security;
alter table public.students    enable row level security;
alter table public.enrollments enable row level security;
alter table public.sessions    enable row level security;
alter table public.attendance  enable row level security;

grant usage on schema public to anon;
grant select, insert, update on
  public.courses, public.students, public.enrollments,
  public.sessions, public.attendance
to anon;

do $$
declare t text;
begin
  foreach t in array array['courses','students','enrollments','sessions','attendance']
  loop
    execute format('drop policy if exists "anon read"   on public.%I', t);
    execute format('drop policy if exists "anon insert" on public.%I', t);
    execute format('drop policy if exists "anon update" on public.%I', t);
    execute format('create policy "anon read"   on public.%I for select to anon using (true)', t);
    execute format('create policy "anon insert" on public.%I for insert to anon with check (true)', t);
    execute format('create policy "anon update" on public.%I for update to anon using (true) with check (true)', t);
  end loop;
end $$;
