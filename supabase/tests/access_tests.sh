#!/bin/bash
# access_tests.sh — builds a replica of the live schema + security rules, applies the current
# migrations, and checks who can read/write what (resident, manager, owner, archived accounts).
# Uses the standard PG* env vars (PGHOST, PGPORT, PGUSER, PGPASSWORD). Exits non-zero on any failure.
#   local:  PGHOST=/tmp PGPORT=55432 PGUSER=postgres bash supabase/tests/access_tests.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; R="$HERE/../security"; DB=instep_access_test
P="psql -q -v ON_ERROR_STOP=1"
$P -d postgres -c "drop database if exists $DB" >/dev/null && $P -d postgres -c "create database $DB" >/dev/null || exit 2
$P -d $DB -f "$HERE/00_boot.sql" >/dev/null 2>&1 || { echo "boot failed"; exit 2; }
$P -d $DB -c "alter table residents add column pin text" >/dev/null || exit 2
# Baseline = the rules production had before 35 (in the order they were applied).
for f in 14_org_rls 15_pin_hash 16_drop_pin_plaintext 23_login_active_only 22_document_files 18_audit_log 19_app_errors 31_medications 34_staff_verified_meetings; do
  $P -d $DB -f "$R/$f.sql" >/dev/null 2>/tmp/access_err || { echo "ERROR applying $f.sql"; grep ERROR /tmp/access_err; exit 2; }
done
$P -d $DB -c "grant select, insert on audit_log, app_errors to authenticated; grant usage on all sequences in schema public to authenticated" >/dev/null
$P -d $DB -f "$HERE/02_seed.sql" >/dev/null || { echo "seed failed"; exit 2; }
# Current rules (run twice: every migration must be safe to re-run).
for f in 35_role_based_rls 37_vendor_accounts 38_rls_initplan 35_role_based_rls 37_vendor_accounts 38_rls_initplan; do
  $P -d $DB -f "$R/$f.sql" >/dev/null 2>/tmp/access_err || { echo "ERROR applying $f.sql"; grep ERROR /tmp/access_err; exit 2; }
done

PASS=0; FAIL=0
t(){ local label="$1" sub="$2" sql="$3" exp="$4"; local claims org role house
  read org role house <<<$(psql -d $DB -Atc "select org||' '||coalesce(role,'-')||' '||coalesce(house,'-') from residents where id='$sub'")
  claims="{\"sub\":\"$sub\",\"org\":\"$org\",\"urole\":\"$role\",\"house\":\"$house\",\"role\":\"authenticated\"}"
  out=$(psql -d $DB -At -v ON_ERROR_STOP=1 2>&1 <<SQL
begin; set local role authenticated; select set_config('request.jwt.claims','$claims',true);
$sql
rollback;
SQL
)
  local got; if echo "$out" | grep -q "ERROR"; then got=deny; else got="ok:$(echo "$out" | tail -n +2 | grep -v '^ROLLBACK\|^BEGIN\|^SET\|^INSERT\|^{\|^$' | tr '\n' ' ' | sed 's/ $//')"; fi
  # count rows for UPDATE/DELETE n
  if [[ "$exp" == blocked && ( "$got" == deny || "$got" == "ok:0" ) ]] || [[ "$exp" == deny && "$got" == deny ]] || [[ "$exp" != deny && "$got" == ok:$exp* ]] || [[ "$exp" == ok && "$got" == ok* ]]; then PASS=$((PASS+1)); echo "  pass  $label"; else FAIL=$((FAIL+1)); echo "  FAIL  $label  expected[$exp] got[$got] $(echo "$out"|grep ERROR|head -1)"; fi
}

U(){ echo "with u as ($1 returning 1) select count(*) from u;"; }
echo "== RESIDENT rA1 (house A) — attacks"
t "read others' PIN hashes"            rA1 "select count(pin_hash) from residents;" deny
t "see other residents' rows"          rA1 "select count(*) from residents where id<>'rA1';" 0
t "promote self to owner"              rA1 "$(U "update residents set role='owner' where id='rA1'")" blocked
t "change manager's name/house"        rA1 "$(U "update residents set house='B' where id='mA'")" blocked
t "set someone's pin_hash"             rA1 "$(U "update residents set pin_hash='h' where id='mA'")" blocked
t "set_pin on manager"                 rA1 "select set_pin('mA','9999');" deny
t "read housemate's screenings"        rA1 "select count(*) from drug_tests where resident_id<>'rA1';" 0
t "delete own screening"               rA1 "$(U "delete from drug_tests where id='dA1'")" blocked
t "edit own screening result"          rA1 "$(U "update drug_tests set result='neg' where id='dA1'")" blocked
t "insert a screening"                 rA1 "insert into drug_tests(id,resident_id,house,org) values('x','rA1','A','ttp'); select 1;" deny
t "read incidents"                     rA1 "select count(*) from incidents;" 0
t "read others' grievances (incl anon)" rA1 "select count(*) from grievances where coalesce(resident_id,'')<>'rA1';" 0
t "delete curfew record"               rA1 "$(U "delete from curfew_log where id='clA2'")" blocked
t "insert curfew as housemate"         rA1 "insert into curfew_log(id,resident_id,house,org,action) values('x','rA2','A','ttp','in'); select 1;" deny
t "self-excuse curfew"                 rA1 "insert into curfew_log(id,resident_id,house,org,action,excused,ts) values('x','rA1','A','ttp','in',true,'2020-01-01'); select excused::text||' '||(ts>now()-interval '1 minute')::text from curfew_log where id='x';" "false true"
t "fake staff-verified checkin"        rA1 "insert into checkins(id,resident_id,house,org,verified_by_id) values('x','rA1','A','ttp','mA'); select coalesce(verified_by_id,'null') from checkins where id='x';" null
t "checkin for housemate"              rA1 "insert into checkins(id,resident_id,house,org) values('x','rA2','A','ttp'); select 1;" deny
t "change org settings"                rA1 "$(U "update settings set required=0 where org='ttp'")" blocked
t "edit doc templates"                 rA1 "$(U "update document_templates set name='x'")" blocked
t "mark housemate's chore done"        rA1 "$(U "update chores set completed_date=current_date where id='cA2'")" blocked
t "retitle own chore"                  rA1 "$(U "update chores set title='nothing' where id='cA1'")" blocked
t "sign housemate's document"          rA1 "$(U "update resident_documents set status='resident_signed' where id='rdA2'")" blocked
t "complete own doc w/o manager"       rA1 "$(U "update resident_documents set status='complete' where id='rdA1'")" blocked
t "read housemate's signed PDF"        rA1 "select count(*) from storage.objects where name='ttp/rdA2_signed.pdf';" 0
t "read other house events"            rA1 "select count(*) from events where house='B';" 0
t "file grievance as housemate"        rA1 "insert into grievances(id,resident_id,house,org,status) values('x','rA2','A','ttp','open'); select 1;" deny
t "read audit log"                     rA1 "select count(*) from audit_log;" 0
echo "== RESIDENT rA1 — normal app use"
t "read own row"                       rA1 "select count(*) from residents where id='rA1';" 1
t "set own recovery date + email"      rA1 "$(U "update residents set sobriety_date='2026-01-01', email='a@b.co' where id='rA1'")" 1
t "read own screenings"                rA1 "select count(*) from drug_tests where resident_id='rA1';" 1
t "check in"                           rA1 "insert into checkins(id,resident_id,house,org) values('x','rA1','A','ttp'); select 1;" 1
t "curfew sign out"                    rA1 "insert into curfew_log(id,resident_id,house,org,action) values('x','rA1','A','ttp','out'); select 1;" 1
t "read own check-ins only"            rA1 "select count(*) from checkins;" 1
t "see house chores"                   rA1 "select count(*) from chores;" 2
t "mark own chore done"                rA1 "$(U "update chores set completed_date=current_date where id='cA1'")" 1
t "sign own document"                  rA1 "$(U "update resident_documents set status='resident_signed',resident_sig='s',resident_signed_at=now() where id='rdA1'")" 1
t "open template + own signed PDF"     rA1 "select count(*) from storage.objects where name in ('ttp/t1_rules.pdf','ttp/rdA1_signed.pdf');" 2
t "file named grievance"               rA1 "insert into grievances(id,resident_id,house,org,status,category) values('x','rA1','A','ttp','open','c'); select 1;" 1
t "file anonymous grievance"           rA1 "insert into grievances(id,resident_id,house,org,status,category) values('x',null,'A','ttp','open','c'); select 1;" 1
t "read own grievances"                rA1 "select count(*) from grievances where resident_id='rA1';" 1
t "ack sticky note"                    rA1 "insert into announcement_acks(id,announcement_id,resident_id,org) values('x','a1','rA1','ttp'); select 1;" 1
t "read settings + events"             rA1 "select (select count(*) from settings)||'/'||(select count(*) from events);" "1/2"
t "change own PIN"                     rA1 "select set_pin('rA1','4444','3333');" t
t "change own PIN w/ wrong current"    rA1 "select set_pin('rA1','4444','0000');" deny
echo "== MANAGER mA (house A)"
t "sees house A residents (incl discharged)" mA "select count(*) from residents where role='resident';" 3
t "no pin_hash"                        mA "select count(pin_hash) from residents;" deny
t "record screening"                   mA "insert into drug_tests(id,resident_id,house,org) values('x','rA1','A','ttp'); select 1;" 1
t "record screening for house B"       mA "insert into drug_tests(id,resident_id,house,org) values('x','rB1','B','ttp'); select 1;" deny
t "update lab result"                  mA "$(U "update drug_tests set lab_result='neg' where id='dA2'")" 1
t "delete screening"                   mA "$(U "delete from drug_tests where id='dA2'")" blocked
t "delete grievance"                   mA "$(U "delete from grievances where id='gA1'")" blocked
t "resolve grievance"                  mA "$(U "update grievances set status='resolved' where id='gA1'")" 1
t "add resident"                       mA "insert into residents(id,name,role,house,org,status) values('n','New Person','resident','A','ttp','active'); select set_pin('n','1234');" t
t "add a manager"                      mA "insert into residents(id,name,role,house,org,status) values('n','New Mgr','manager','A','ttp','active'); select 1;" deny
t "promote resident to manager"        mA "$(U "update residents set role='manager' where id='rA1'")" blocked
t "discharge resident"                 mA "$(U "update residents set status='discharged' where id='rA1'")" 1
t "hard-delete resident"               mA "$(U "delete from residents where id='rA1'")" blocked
t "reset resident PIN"                 mA "select set_pin('rA1','5555');" t
t "reset owner PIN"                    mA "select set_pin('o1','5555');" deny
t "duplicate active name rejected"     mA "insert into residents(id,name,role,house,org,status) values('n','rae one','resident','A','ttp','active'); select 1;" deny
t "re-add discharged person ok"        mA "insert into residents(id,name,role,house,org,status) values('n','Rex Gone','resident','A','ttp','active'); select 1;" 1
t "read activity log"                 mA "select count(*)>=0 from audit_log;" t
t "excuse curfew"                      mA "insert into curfew_log(id,resident_id,house,org,action,excused) values('x','rA1','A','ttp','in',true); select excused from curfew_log where id='x';" t
t "save settings"                      mA "$(U "update settings set required=3 where org='ttp'")" 1
t "staff-verified meeting"             mA "insert into checkins(id,resident_id,house,org,verified_by_id) values('x','rA1','A','ttp','mA'); select verified_by_id from checkins where id='x';" mA
echo "== OWNER o1"
t "sees all houses" o1 "select count(*) from residents where role='resident';" 4
t "add manager + set PIN"              o1 "insert into residents(id,name,role,house,org,status) values('n','New Mgr','manager','C','ttp','active'); select set_pin('n','1234');" t
t "archive manager"                    o1 "$(U "update residents set status='discharged' where id='mB'")" 1
t "delete resident"                    o1 "$(U "delete from residents where id='rB1'")" 1
t "cannot touch other org"             o1 "select count(*) from residents where org='other';" 0
echo "== ARCHIVED / DISCHARGED with unexpired tokens"
t "archived manager reads residents"   mX "select count(*) from residents;" 0
t "archived manager reads screenings"  mX "select count(*) from drug_tests;" 0
t "discharged resident checks in"      rX "insert into checkins(id,resident_id,house,org) values('x','rX','A','ttp'); select 1;" deny
t "discharged resident reads settings" rX "select count(*) from settings;" 0
t "timesheets locked to public"       rA1 "select count(*) from timesheets;" blocked
t "owner reads app errors"           o1 "select count(*)>=0 from app_errors;" t
t "queued sign-in 10 min old keeps phone time" rA1 "insert into curfew_log(id,resident_id,house,org,action,ts) values('x','rA1','A','ttp','in',now()-interval '10 minutes'); select (ts < now()-interval '9 minutes')::text from curfew_log where id='x';" true
t "backdated 3h sign-in uses server time"  rA1 "insert into curfew_log(id,resident_id,house,org,action,ts) values('x','rA1','A','ttp','in',now()-interval '3 hours'); select (ts > now()-interval '1 minute')::text from curfew_log where id='x';" true
t "resident can't read vendor billing"     rA1 "select count(*) from vendor_accounts;" deny
echo; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ] || exit 1
