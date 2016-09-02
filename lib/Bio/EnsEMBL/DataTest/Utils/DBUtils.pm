
=head1 LICENSE

Copyright [2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::DataTest::Utils::DBUtils;
use warnings;
use strict;
use Carp qw/croak/;

use Test::More;

BEGIN {
  require Exporter;
  our $VERSION = 1.00;
  our @ISA     = qw(Exporter);
  our @EXPORT =
    qw(table_dates rowcount is_rowcount is_rowcount_zero is_rowcount_nonzero
    ok_foreignkeys get_species_ids is_query is_same_counts is_same_result)
    ;
}

sub table_dates {
  my ( $dbc, $dbname ) = @_;
  # TODO assertion?
  my $type = 'Bio::EnsEMBL::DBSQL::DBConnection';
  if ( !defined $dbc || !$dbc->isa($type) ) {
    croak "table_dates() requires $type";
  }
  if ( !defined $dbname ) {
    $dbname = $dbc->dbname();
  }
  return
    $dbc->sql_helper()->execute_into_hash(
    -SQL =>
'select table_name,update_time from information_schema.tables where table_schema=?',
    -PARAMS => [$dbname] );
}

sub get_species_ids {
  my ($dbc) = @_;
  if ( $dbc->can('dbc') ) {
    $dbc = $dbc->dbc();
  }
  return $dbc->sql_helper()
    ->execute( -SQL =>
          'select distinct species_id from meta where species_id is not null' );
}

sub rowcount {
  my ( $dbc, $sql ) = @_;
  if ( $dbc->can('dbc') ) {
    $dbc = $dbc->dbc();
  }
  diag($sql);
  if ( index( uc($sql), "SELECT COUNT" ) != -1 &&
       index( uc($sql), "GROUP BY" ) == -1 )
  {
    return $dbc->sql_helper()->execute_single_result( -SQL => $sql );
  }
  else {
    return scalar @{ $dbc->sql_helper()->execute( -SQL => $sql ) };
  }
}

sub is_rowcount {
  my ( $dba, $sql, $expected, $name ) = @_;
  $name ||= "Checking that $sql returns $expected";
  is( rowcount( $dba, $sql ), $expected, $name );
  return;
}

sub is_rowcount_zero {
  my ( $dba, $sql, $name ) = @_;
  is_rowcount( $dba, $sql, 0, $name );
  return;
}

sub is_rowcount_nonzero {
  my ( $dba, $sql, $name ) = @_;
  ok( rowcount( $dba, $sql ) > 0, $name );
  return;
}

sub is_query {
  my ( $dba, $expected, $sql, $name ) = @_;
  is( $expected,
      $dba->dbc()->sql_helper()->execute_single_result( -SQL => $sql ), $name );
  return;
}

sub is_same_result {
  my ( $dba, $dba2, $sql, $name ) = @_;
  $name ||= "Comparing results of $sql";
  my $r1 = $dba->dbc()->sql_helper()->execute( -SQL => $sql );
  my $r2 = $dba2->dbc()->sql_helper()->execute( -SQL => $sql );
  if ( scalar(@$r1) != scalar(@$r2) ) {
    fail( $name . " - different row counts" );
  }
  else {
    for ( my $i = 0; $i < scalar(@$r1); $i++ ) {
      for ( my $j = 0; $j < scalar( @{ $r1->[$i] } ); $j++ ) {
        is( $r1->[$i]->[$j], $r1->[$i]->[$j], $name . " row $i, column $j" );
      }
    }
  }
  return;
}

sub is_same_counts {
  my ( $dba, $dba2, $sql, $threshold, $name ) = @_;
  $threshold ||= 1;
  $name      ||= "Checking counts from $sql";
  my $c1 = $dba->dbc()->sql_helper()->execute_into_hash( -SQL => $sql );
  my $c2 = $dba2->dbc()->sql_helper()->execute_into_hash( -SQL => $sql );
  while ( my ( $k, $v1 ) = each %$c1 ) {
    my $v2 = $c2->{$k} || 0;
    ok( $v1 > ( $v2*$threshold ), $name . " - comparing $k ($v1 vs $v2)" );
  }
  return;
}

sub ok_foreignkeys {
  my ( $dba, $table1, $col1, $table2, $col2, $both_ways, $constraint, $name ) =
    @_;

  $col2 ||= $col1;
  $both_ways ||= 0;
  my $sql_left =
    "SELECT COUNT(*) FROM $table1 LEFT JOIN $table2 " .
    "ON $table1.$col1 = $table2.$col2 " . "WHERE $table2.$col2 IS NULL";

  if ($constraint) {
    $sql_left .= " AND $constraint";
  }

  is_rowcount_zero( $dba,
                    $sql_left, (
                      $name ||
"Checking for values in ${table1}.${col1} not found in ${table2}.${col2}" ) );

  if ($both_ways) {

    my $sql_right =
      "SELECT COUNT(*) FROM $table2 LEFT JOIN $table1 " .
      "ON $table2.$col2 = $table1.$col1 " . "WHERE $table1.$col1 IS NULL";

    if ($constraint) {
      $sql_right .= " AND $constraint";
    }

    is_rowcount_zero( $dba,
                      $sql_right, (
                        $name ||
"Checking for values in ${table2}.${col2} not found in ${table1}.${col1}" ) );

  }

  return;
} ## end sub ok_foreignkeys

1;