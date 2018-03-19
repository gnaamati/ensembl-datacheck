# Copyright [2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Bio::EnsEMBL::DataCheck::DbCheck;
use Bio::EnsEMBL::Test::MultiTestDB;

use FindBin; FindBin::again();
use Test::More;

use lib "$FindBin::Bin/TestChecks";
use DbCheck_1;
use DbCheck_2;
use DbCheck_3;
use DbCheck_4;

my $test_db_dir = $FindBin::Bin;

my $species  = 'drosophila_melanogaster';
my $db_type  = 'core';
my $dba_type = 'Bio::EnsEMBL::DBSQL::DBAdaptor';
my $testdb   = Bio::EnsEMBL::Test::MultiTestDB->new($species, $test_db_dir);
my $dba      = $testdb->get_DBAdaptor($db_type);

# Note that you cannot, by design, create a DbCheck object; datachecks
# must inherit from it and define mandatory, read-only parameters that
# are specific to that particular datacheck. So there's a limited amount
# of testing that we can do on the base class, the functionality is
# tested on a subclass.

my $module = 'Bio::EnsEMBL::DataCheck::DbCheck';

diag('Fixed attributes');
can_ok($module, qw(db_types tables per_species));

diag('Runtime attributes');
can_ok($module, qw(dba));

diag('Methods');
can_ok($module, qw(skip_datacheck verify_db_type check_history table_dates skip_tests));

# As well as being a nice way to encapsulate sets of tests, the use of
# subtests here is necessary, because the behaviour we are testing
# involves running tests, and we need to isolate that from the reports
# of this test (i.e. DbCheck.t).

subtest 'Minimal DbCheck with passing tests', sub {
  my $dbcheck = TestChecks::DbCheck_1->new(
    dba => $dba,
  );
  isa_ok($dbcheck, $module);

  my $name = $dbcheck->name;

  is_deeply($dbcheck->db_types, [],        'db_types attribute defaults to empty list');
  is_deeply($dbcheck->tables,   [],        'tables attribute defaults to empty list');
  is($dbcheck->per_species,     0,         'per_species attribute defaults to zero');
  isa_ok($dbcheck->dba,         $dba_type, 'dba attribute');

  is($dbcheck->skip_tests(),     undef, 'skip_tests method undefined');
  is($dbcheck->verify_db_type(), undef, 'verify_db_type method undefined');
  is($dbcheck->check_history(),  undef, 'check_history method undefined');
  is($dbcheck->skip_datacheck(), undef, 'skip_datacheck method undefined');

  # The tests that are run are Test::More tests. Running them within a test
  # is a bit confusing. To simulate a proper test of the tests, need to reset
  # the Test::More framework.
  Test::More->builder->reset();
  my $output = $dbcheck->run;
  diag("Test enumeration reset by the datacheck object ($name)");

  my $started = $dbcheck->_started;
  sleep(2);

  like($output, qr/# Subtest\: $name/m, 'tests ran as subtests');
  like($output, qr/^\s+1\.\.2/m,         '2 subtests ran successfully');
  like($output, qr/^\s+ok 1 - $name/m,  'test ran successfully');
  like($output, qr/^\s+1\.\.1/m,         'test ran with a plan');

  like($dbcheck->_started,  qr/^\d+$/, '_started attribute has numeric value');
  like($dbcheck->_finished, qr/^\d+$/, '_finished attribute has numeric value');
  is($dbcheck->_passed,     1,         '_passed attribute is true');

  # Now that we've run the test, we've got something to compare against
  # the database tables; because specific tables are not given, all will
  # be checked.
  my ($skip, $skip_reason) = $dbcheck->check_history();
  is($skip, 1, 'History used to skip datacheck');
  is($skip_reason, 'Database tables not updated since last run', 'Correct skip reason');

  ($skip, $skip_reason) = $dbcheck->skip_datacheck();
  is($skip, 1, 'History used to skip datacheck');
  is($skip_reason, 'Database tables not updated since last run', 'Correct skip reason');

  Test::More->builder->reset();
  $output = $dbcheck->run;
  diag("Test enumeration reset by the datacheck object ($name)");

  cmp_ok($dbcheck->_started, '>', $started, '_started attribute changed when datacheck skipped');
  is($dbcheck->_finished,    undef,         '_finished attribute undefined when datacheck skipped');
  is($dbcheck->_passed,      1,             '_passed attribute remains true');
};

subtest 'DbCheck with failing test', sub {
  my $dbcheck = TestChecks::DbCheck_2->new(
    dba => $dba,
  );
  isa_ok($dbcheck, $module);

  my $name = $dbcheck->name;

  # The tests that are run are Test::More tests. Running them within a test
  # is a bit confusing. To simulate a proper test of the tests, need to reset
  # the Test::More framework.
  Test::More->builder->reset();
  my $output = $dbcheck->run;
  diag("Test enumeration reset by the datacheck object ($name)");

  my ($started, $finished) = ($dbcheck->_started, $dbcheck->_finished);
  sleep(2);

  like($output, qr/# Subtest\: $name/m,    'tests ran as subtests');
  like($output, qr/^\s+not ok 1/m,         '1 subtest failed');
  like($output, qr/^\s+not ok 1 - $name/m, 'test failed');
  like($output, qr/^\s+1\.\.1/m,           'test ran with a plan');

  like($dbcheck->_started,  qr/^\d+$/, '_started attribute has numeric value');
  like($dbcheck->_finished, qr/^\d+$/, '_finished attribute has numeric value');
  is($dbcheck->_passed,     0,         '_passed attribute is false');

  # Now that we've run the test, we've got something to compare against
  # the database tables. However, because the test failed, we always
  # need to run it.
  is($dbcheck->check_history(),  undef, 'check_history method undefined');
  is($dbcheck->skip_datacheck(), undef, 'skip_datacheck method undefined');

  Test::More->builder->reset();
  $output = $dbcheck->run;
  diag("Test enumeration reset by the datacheck object ($name)");

  like($output, qr/# Subtest\: $name/m,    'tests ran as subtests');
  like($output, qr/^\s+not ok 1/m,         '1 subtest failed');
  like($output, qr/^\s+not ok 1 - $name/m, 'test failed');
  like($output, qr/^\s+1\.\.1/m,           'test ran with a plan');

  cmp_ok($dbcheck->_started,  '>', $started,  '_started attribute changed when failed datacheck re-run');
  cmp_ok($dbcheck->_finished, '>', $finished, '_finished attribute changed when failed datacheck re-run');
  is($dbcheck->_passed,        0,             '_passed attribute remains false');
};

subtest 'DbCheck with non-matching db_type', sub {
  my $dbcheck = TestChecks::DbCheck_3->new(
    dba => $dba,
  );
  isa_ok($dbcheck, $module);

  my $name = $dbcheck->name;

  is_deeply($dbcheck->db_types, ['variation'], 'db_types attribute set correctly');

  my ($skip, $skip_reason) = $dbcheck->verify_db_type();
  is($skip, 1, 'db_types used to skip datacheck');
  is($skip_reason, "Database type 'core' is not relevant for this datacheck", 'Correct skip reason');

  ($skip, $skip_reason) = $dbcheck->skip_datacheck();
  is($skip, 1, 'db_types used to skip datacheck');
  is($skip_reason, "Database type 'core' is not relevant for this datacheck", 'Correct skip reason');
};

subtest 'DbCheck with db_type and tables', sub {
  my $dbcheck = TestChecks::DbCheck_4->new(
    dba => $dba,
  );
  isa_ok($dbcheck, $module);

  my $name = $dbcheck->name;

  is_deeply($dbcheck->db_types, ['core'],               'db_types attribute set correctly');
  is_deeply($dbcheck->tables,   ['gene', 'transcript'], 'tables attribute set correctly');

  is($dbcheck->verify_db_type(), undef, 'verify_db_type method undefined');

  # The tests that are run are Test::More tests. Running them within a test
  # is a bit confusing. To simulate a proper test of the tests, need to reset
  # the Test::More framework.
  Test::More->builder->reset();
  my $output = $dbcheck->run;
  diag("Test enumeration reset by the datacheck object ($name)");

  sleep(2);

  like($dbcheck->_started,  qr/^\d+$/, '_started attribute has numeric value');
  like($dbcheck->_finished, qr/^\d+$/, '_finished attribute has numeric value');
  is($dbcheck->_passed,     1,         '_passed attribute is true');

  # Now that we've run the test, we've got something to compare against
  # the database tables, 'gene' and 'transcript' in this case.
  my ($skip, undef) = $dbcheck->check_history();
  is($skip, 1, 'History used to skip datacheck after no table updates');

  Test::More->builder->reset();
  $output = $dbcheck->run;
  diag("Test enumeration reset by the datacheck object ($name)");

  sleep(2);

  # Force an update to the timestamp of a table that is _not_ linked to this datacheck.
  $dba->dbc->sql_helper->execute_update('ALTER TABLE exon ADD COLUMN test_col INT;');
  $dba->dbc->sql_helper->execute_update('ALTER TABLE exon DROP COLUMN test_col;');

  ($skip, undef) = $dbcheck->check_history();
  is($skip, 1, 'History used to skip datacheck after irrelevant table update');

  Test::More->builder->reset();
  $output = $dbcheck->run;
  diag("Test enumeration reset by the datacheck object ($name)");

  my $started = $dbcheck->_started;
  sleep(2);

  # Force an update to the timestamp of a table that is linked to this datacheck.
  $dba->dbc->sql_helper->execute_update('ALTER TABLE gene ADD COLUMN test_col INT;');
  $dba->dbc->sql_helper->execute_update('ALTER TABLE gene DROP COLUMN test_col;');

  ($skip, undef) = $dbcheck->check_history();
  is($skip, undef, 'History not used to skip datacheck after relevant table update');

  Test::More->builder->reset();
  $output = $dbcheck->run;
  diag("Test enumeration reset by the datacheck object ($name)");

  cmp_ok($dbcheck->_started, '>', $started, '_started attribute changed after relevant table update');
  like($dbcheck->_finished,  qr/^\d+$/,     '_finished attribute has numeric value after relevant table update');
  is($dbcheck->_passed,        1,           '_passed attribute is true');
};

# To do: DbCheck with skip_tests method defined

# To do: DbCheck with no dba passed (should die)

# To do: Confirm that dba connection is dropped after run

# To do: DbCheck with per_species = 1 (need test collection db for this)

done_testing();