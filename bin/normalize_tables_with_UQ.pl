#!/usr/bin/env perl

=head1 NAME

    normalize_tables_with_UQ.pl

=head1 SYNOPSIS

    normalize_tables_with_UQ.pl [options/parameters]
    
=head1 DESCRIPTION

    Given a table of values, performs upper quartile normalization on the specified columns

=head1 OPTIONS AND ARGUMENTS

    Input
        -ifile     <Str>   input tab delimited file. use option multiple times to specify myltiple input files eg. -i file1 -i file2.
        -key       <Str>   name for the column to be used as a key. It must be unique for each row/record to use multiple columns as key, use the option multiple times eg. -key col1 -key col2.
        -val       <Str>   name for the column with the values to be normalized
    
    Output
        -ofile     <Str>   output tab delimited file. It is similar to the input file with a new column with the normalized values added. use option multiple times to specify myltiple output files eg. -o outfile1 -o outfile2. output file must be given in the same order and be equal to the input files.
    
    Input Filters.
        -val_thres <Num>   records with value lower or equal than this value are discarded (Default: 0).
    
    Other options.
        -v                 verbosity. If used progress lines are printed.
        -h                 print this help;


=cut


########################
# Load required modules
use Modern::Perl;
use Getopt::Long;
use File::Path qw(make_path);
use Data::Table;
use Pod::Usage;

########################
# Read command options
my (@key_columns, $value_column, @input_files, @output_files);
my $val_thres = 0;
GetOptions(
	
	'h'               => \my $help,
	
	#I/O
	'key=s'           => \@key_columns,
	'val=s'           => \$value_column,
	'ifile=s'         => \@input_files,
	'ofile=s'         => \@output_files,
	
	#filters
	'val_thres=s'     => \$val_thres, #default 0
	
	#flags
	'v'               => \my $verbose,
	'dev'             => \my $devmode,
	
) or pod2usage({-verbose => 1});
pod2usage({-verbose => 2}) if $help;

if ($devmode){$verbose = 1;}

unless ( (@key_columns > 0) and defined $value_column and (@input_files > 0) and (@input_files == @output_files) ) {
	pod2usage({-verbose => 1};
}
my $startime = time;

# Read the files into table objects
warn "Reading the input files\n" if $verbose;
my @tables = map {Data::Table::fromFile($_)} @input_files;
die "Table sizes differ\n" if not all_tables_of_equal_size(@tables);


# Calculate the number of records with value over the threshold in any of the input tables
warn "Calculating the number of records with value over the threshold in any of the input tables\n" if $verbose;
my $records_above_thres = count_records_with_value_over_thres_in_any_table($value_column, $val_thres, \@key_columns, @tables);
my $quantile_index = int($records_above_thres * 0.25);


# Normalize and add a new normalized value column in each table. The new column is named after the value column + the "_uq" suffix
warn "Normalizing the values\n" if $verbose;
add_new_normalized_value_column_in_each_table($value_column, $quantile_index, @tables);


# Write the tables in the output files
warn "Writing tables to output files\n" if $verbose;
for (my $i=0; $i<@input_files; $i++) {
	my ($volume, $directory, $file) = File::Spec->splitpath($output_files[$i]); make_path($directory);
	open (my $OUT, ">", $output_files[$i]);
	print $OUT $tables[$i]->tsv;
	close $OUT;
}

if ($devmode){warn "Done! Time:\t".((int(((time-$startime)/60)*100))/100)." min\n";}

###########################################
# Subroutines used
###########################################


sub add_new_normalized_value_column_in_each_table {
	my ($value_column, $quantile_index, @tables) = @_;
	
	# Sort the tables by descending value
	map {$_->sort($value_column, Data::Table::NUMBER, Data::Table::DESC)} @tables;
	
	foreach my $table (@tables) {
		my $uq = $table->elm($quantile_index, $value_column);
		my @normalized_values = map {$_ / $uq} $table->col($value_column);
		$table->addCol(\@normalized_values, $value_column."_uq");
	}
}

sub count_records_with_value_over_thres_in_any_table {
	my ($value_column, $val_thres, $key_columns, @tables) = @_;
	
	# Sort the tables according to the keys
	my @sorting_conditions = map{$_, Data::Table::STRING, Data::Table::ASC} @{$key_columns};
	map {$_->sort(@sorting_conditions)} @tables;
	
	my $records_count = 0;
	my $row_count = $tables[0]->nofRow;
	for (my $i=0; $i<$row_count; $i++) {
		my @values = map {$_->elm($i, $value_column)} @tables;
		if ((grep {$_ > $val_thres} @values) > 0) {
			$records_count++;
		}
	}
	
	return $records_count;
}

sub all_tables_of_equal_size {
	my @tables = @_;
	
	my $row_count = $tables[0]->nofRow;
	my $col_count = $tables[0]->nofCol;
	
	foreach my $table (@tables) {
		if ($table->nofRow != $row_count or $table->nofCol != $col_count) {
			return 0;
		}
	}
	
	return 1;
}

