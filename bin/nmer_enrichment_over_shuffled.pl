#!/usr/bin/env perl

=head1 NAME

nmer_enrichment_over_shuffled.pl

=head1 SYNOPSIS

nmer_enrichment_over_shuffled.pl [options/parameters]

Measure Nmer enrichment over shuffled reads. Suffling is done at the nucleotide level and p-values are calculated using permutations.

  Input options for library.
      -driver <Str>          driver for database connection (eg. mysql, SQLite).
      -database <Str>        database name or path to database file for file based databases.
      -table <Str>           database table.
      -host <Str>            hostname for database connection.
      -user <Str>            username for database connection.
      -password <Str>        password for database connection.
      -records_class <Str>   type of records stored in database (Default: GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3).

  Output.
      -o_file <Str>          filename for output file. If path does not exist it will be created.

  Input Filters (only for DBIC input type).
      -filter <Filter>       filter library. Option can be given multiple times.
                             Filter syntax: column_name="pattern"
                               e.g. -filter deletion="def" -filter rmsk="undef" to keep reads with deletions and not repeat masked.
                               e.g. -filter query_length=">31" -filter query_length="<=50" to keep reads longer than 31 and shorter or   equal to 50.
                             Supported operators: ">", ">=", "<", "<=", "=", "!=","def", "undef"

  Other options.
      -N <Int>               the length N of the Nmer. Default: 6
      -P <Int>               the number of permutation to be performed. Consider using more than 100 to get p-values < 0.01
      -sub_size <Int>        if set it specifies the number of records on which the analysis will run. Records are selected randomly.
      -sub_percent <Float>   specifies the percent of records on which the analysis will run. Records are selected randomly. Default: 100
      -v                     verbosity. If used progress lines are printed.
      -h                     print help message
      -man                   show man page


=head1 DESCRIPTION

Measure Nmer enrichment over shuffled reads. Suffling is done at the nucleotide level and p-values are calculated using permutations.

=cut


##############################################
# Import external libraries
use Modern::Perl;
use autodie;
use Getopt::Long;
use Pod::Usage;
use File::Spec;
use List::Util qw/shuffle/;
use File::Path qw(make_path);
use List::Util qw(sum);


##############################################
# Import GenOO
use GenOO::RegionCollection::Factory;


##############################################
# Read command options
my $P = 1;   # permutations
my $N = 6;   # length of Nmer
my $subset_percent = 100;
my $records_class = 'GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3';

GetOptions(
# Input options for library.
	'driver=s'        => \my $driver,
	'host=s'          => \my $host,
	'database=s'      => \my $database,
	'table=s'         => \my $table,
	'user=s'          => \my $user,
	'password=s'      => \my $pass,
	'records_class=s' => \$records_class,
# Output
	'o_file=s'        => \my $o_file,
# Input Filters
	'filter=s'        => \my @filters, # eg. -filter deletion="def" -filter score="!=100"
# Other options
	'N=i'             => \$N,
	'P=i'             => \$P,
	'sub_size=i'      => \my $subset_size,
	'sub_percent=f'   => \$subset_percent,
	'h'               => \my $help,
	'man'             => \my $man,
	'v'               => \my $verbose,
) or pod2usage({-verbose => 0});

pod2usage(-verbose => 1)  if $help;
pod2usage(-verbose => 2)  if $man;


##############################################
warn "Checking the input\n" if $verbose;
check_options_and_arguments();


##############################################
warn "Creating reads collection\n" if $verbose;
my $reads_collection = read_collection('DBIC', undef, $driver, $database, $table, $records_class, $host, $user, $pass);
apply_simple_filters($reads_collection, \@filters);


##############################################
warn "Calculating subset parameters\n" if $verbose;
my $records_count = $reads_collection->records_count;
$subset_percent = $subset_size / $records_count * 100 if $subset_size;
my $subset_factor = $subset_percent / 100;
warn "Program will run on approximatelly ".sprintf('%.0f', $subset_percent)."% of library\n" if $verbose;


##############################################
warn "Counting Nmer occurrences in original and shuffled reads\n" if $verbose;
my %nmer_stats;
$reads_collection->foreach_record_do(sub{
	my ($record) = @_;
	
	return 0 if rand > $subset_factor;
	
	my $seq = $record->sequence;
	for my $i (0..length($seq)-$N) {
		my $nmer = substr($seq, $i, $N);
		$nmer_stats{$nmer}->{'count'}        += $record->copy_number;
		$nmer_stats{$nmer}->{'collapsed_count'} += 1;
	}
	
	my @seq_array = split(//, $seq);
	for (my $perm = 0; $perm < $P; $perm++) {
		my @random_seq_array = shuffle(@seq_array);
		for (my $i=0; $i < @seq_array - $N + 1; $i++) {
			my $nmer = join('', @random_seq_array[$i..$i+$N-1]);
			$nmer_stats{$nmer}->{'sh_count'}->[$perm]           += $record->copy_number;
			$nmer_stats{$nmer}->{'sh_collapsed_count'}->[$perm] += 1;
		}
	}
	
	return 0;
});


#################################
warn "Creating output path\n" if $verbose;
my (undef, $directory, undef) = File::Spec->splitpath($o_file); make_path($directory);


##############################################
warn "Calculating p-values and printing results.\n" if $verbose;
open (my $OUT, '>', $o_file);
say $OUT join("\t", 'nmer', 'count', 'collapsed_count', 'average_sh_count', 'average_sh_collapsed_count', 'enrichment', 'collapsed_enrichment', 'pvalue', 'collapsed_pvalue');
foreach my $nmer (keys %nmer_stats) {
	next if $nmer =~ /N/;
	
	my $count                = $nmer_stats{$nmer}->{'count'}                 || 0;
	my $collapsed_count      = $nmer_stats{$nmer}->{'collapsed_count'}       || 0;
	my @sh_counts            = @{$nmer_stats{$nmer}->{'sh_count'}};
	my @sh_collapsed_counts  = @{$nmer_stats{$nmer}->{'sh_collapsed_count'}};
	
	map{$_ = 0 if !$_} @sh_counts;           # make any undefined values 0
	map{$_ = 0 if !$_} @sh_collapsed_counts; # make any undefined values 0
	
	my $avg_sh_count         = sum(@sh_counts) / $P           || 1;
	my $avg_collapsed_count  = sum(@sh_collapsed_counts) / $P || 1;
	
	my $enrichment           = $count / $avg_sh_count;
	my $collapsed_enrichment = $collapsed_count / $avg_collapsed_count;
	
	my $pvalue               = equal_or_more($count, @sh_counts) / $P;
	my $collapsed_pvalue     = equal_or_more($collapsed_count, @sh_collapsed_counts) / $P;
	
	say $OUT join("\t", $nmer, $count, $collapsed_count, $avg_sh_count, $avg_collapsed_count, $enrichment, $collapsed_enrichment, $pvalue, $collapsed_pvalue);
}



##############################################
# Subroutines used
##############################################
sub check_options_and_arguments {
	
	pod2usage(-verbose => 1, -message => "\n$0: Driver for database connection is required.\n") if !$driver;
	pod2usage(-verbose => 1, -message => "\n$0: Database name or path is required.\n") if !$database;
	pod2usage(-verbose => 1, -message => "\n$0: Database table is required.\n") if !$table;
	
	pod2usage(-verbose => 1, -message => "\n$0: Subset percent must be in the region (0,100].\n") if $subset_percent <= 0 or $subset_percent > 100;
	
	pod2usage(-verbose => 1, -message => "\n$0: Output file is required.\n") if !$o_file;
}

sub equal_or_more {
	my $value = shift;
	
	return scalar(grep {$_ >= $value} @_);
}

sub read_collection {
	my ($type, $file, $driver, $database, $table, $p_records_class, $host, $user, $pass) = @_;
	
	return read_collection_from_file($file, $type) if $type =~ /^BED$/;
	return read_collection_from_database($driver, $database, $table, $p_records_class, $host, $user, $pass) if $type =~ /^DBIC$/;
}


sub read_collection_from_file {
	my ($file, $type) = @_;
	
	return GenOO::RegionCollection::Factory->create($type, {
		file => $file
	})->read_collection;
}


sub read_collection_from_database {
	my ($driver, $database, $table, $p_records_class, $host, $user, $pass) = @_;
	
	return GenOO::RegionCollection::Factory->create('DBIC', {
		driver        => $driver,
		host          => $host,
		database      => $database,
		user          => $user,
		password      => $pass,
		table         => $table,
		records_class => $p_records_class,
	})->read_collection;
}


sub apply_simple_filters {
	my ($collection, $params) = @_;
	
	foreach my $element (@$params) {
		$element =~ /^(.+?)=(.+?)$/;
		my $col_name = $1;
		my $filter   = $2;
		$collection->simple_filter($col_name, $filter);
	}
}
