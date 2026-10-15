-- 38_rls_initplan.sql  —  read the login token once per query, not once per row
--
-- Supabase's performance advisor (auth_rls_initplan): policies that call auth.jwt() directly re-run it
-- for every row scanned. Wrapping it as (select auth.jwt()) lets Postgres evaluate it once per
-- statement. Same rules, same results — only faster as tables grow. Rewrites every policy in public
-- and storage in place (ALTER POLICY), skipping calls that are already wrapped. Safe to run more than once.

do $$
declare p record; q text; c text; stmt text;
begin
  for p in select schemaname, tablename, policyname, qual, with_check from pg_policies
           where schemaname in ('public','storage')
             and (qual ~ 'auth\.jwt\(\)' or with_check ~ 'auth\.jwt\(\)')
  loop
    q := regexp_replace(p.qual,       '(?<!SELECT )auth\.jwt\(\)', '(select auth.jwt())', 'g');
    c := regexp_replace(p.with_check, '(?<!SELECT )auth\.jwt\(\)', '(select auth.jwt())', 'g');
    if q is not distinct from p.qual and c is not distinct from p.with_check then continue; end if;
    stmt := format('alter policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
    if p.qual is not null then stmt := stmt || ' using (' || q || ')'; end if;
    if p.with_check is not null then stmt := stmt || ' with check (' || c || ')'; end if;
    execute stmt;
  end loop;
end $$;
