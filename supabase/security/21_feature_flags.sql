-- 21_feature_flags.sql  —  per-org feature configuration (one codebase, different facility types)
--
-- Lets a tenant turn off features it doesn't use and relabel "House" to its own noun, so a sober-living
-- house and a transitional apartment complex can both run on the same app/backend without a fork.
-- These are set ONCE at provisioning (admin.html -> provisionorg), NOT in owner Settings, so a small
-- house owner never sees (or can't accidentally toggle) them. All defaults keep current behavior
-- (everything on, label "House"), so running this changes nothing for existing orgs. The app only
-- READS these columns, so it's safe to deploy before this runs; run it before provisioning a
-- configured (e.g. curfew-off) org.
--
-- Additive and safe to run more than once.

alter table public.settings
  add column if not exists feature_curfew boolean default true,
  add column if not exists feature_chores boolean default true,
  add column if not exists unit_label    text    default 'House';

-- Backfill any existing rows (e.g. The Turning Point) to the defaults so nothing turns off.
update public.settings
  set feature_curfew = coalesce(feature_curfew, true),
      feature_chores = coalesce(feature_chores, true),
      unit_label     = coalesce(nullif(trim(unit_label), ''), 'House');

notify pgrst, 'reload schema';
