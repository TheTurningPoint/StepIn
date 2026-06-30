-- 21_feature_flags.sql  —  per-org feature configuration (one codebase, different facility types)
--
-- Lets a tenant turn off features it doesn't use and relabel "House" to its own noun, so a sober-living
-- house and a transitional apartment complex can both run on the same app/backend without a fork.
-- All defaults keep the current behavior (everything on, label "House"), so running this changes
-- nothing for existing orgs.
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
