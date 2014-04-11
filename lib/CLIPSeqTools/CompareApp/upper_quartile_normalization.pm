=head1 NAME

CLIPSeqTools::CompareApp::upper_quartile_normalization - Do Upper Quartile normalization on specified columns of tables.

=head1 SYNOPSIS

clipseqtools upper_quartile_normalization [options/parameters]

=head1 DESCRIPTION

Do Upper Quartile normalization on specified columns of tables.

=head1 OPTIONS

  Input options.
    --table <Str>          input table file/files. Use option multiple
                           times to specify multiple table files.
    --key_col <Str>        name for the column/columns to use as a key. It
                           must be unique for each table row. Use option
                           multiple times to specify multiple columns.
    --val_col <Str>        name of column with values to be normalized.

  Output.
    --o_table <Str>        output table file/files. Use option multiple
                           times to give multiple files. Must be given as
                           many times as the table option.

  Other options.
    --val_thres <Num>      rows with value lower or equal than val_thres
                           are not used for normalization. Default: 0
    -v --verbose           print progress lines and extra information.
    -h -? --usage --help   print help message

=cut

package CLIPSeqTools::CompareApp::upper_quartile_normalization;


# Make it an app command
use MooseX::App::Command;
extends 'CLIPSeqTools::CompareApp';


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use namespace::autoclean;
use File::Spec;
use File::Path qw(make_path);
use Data::Table;


#######################################################################
#######################   Command line options   ######################
#######################################################################
option 'table' => (
	is            => 'rw',
	isa           => 'ArrayRef[Str]',
	required      => 1,
	documentation => 'input table file/files. Use option multiple times to give multiple files.',
);

option 'key_col' => (
	is            => 'rw',
	isa           => 'ArrayRef[Str]',
	required      => 1,
	documentation => 'name for the column/columns to use as a key. It must be unique for each table row. Use option multiple times to specify multiple columns.',
);

option 'val_col' => (
	is            => 'rw',
	isa           => 'Str',
	required      => 1,
	documentation => 'name of column with values to be normalized.',
);

option 'val_thres' => (
	is            => 'rw',
	isa           => 'Num',
	default       => 0,
	documentation => 'rows with value lower or equal than val_thres are not used for normalization.',
);

option 'o_table' => (
	is            => 'rw',
	isa           => 'ArrayRef[Str]',
	required      => 1,
	documentation => 'output table file/files. Use option multiple times to give multiple files. Must be given as many times as the table option.'
);


#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {
	my ($self) = @_;
	
	$self->usage_error('Input table files must be as many as output ones.') if @{$self->table} != @{$self->o_table};
}

sub run {
	my ($self) = @_;
	
	warn "Starting analysis: upper_quartile_normalization\n";
	
	warn "Validating arguments\n" if $self->verbose;
	$self->validate_args();
	
	warn "Reading input files\n" if $self->verbose;
	my @tables = map {Data::Table::fromFile($_)} @{$self->table};
	die "Table sizes differ\n" if not all_tables_of_equal_size(@tables);

	warn "Calculating number of unique records with value over threshold\n" if $self->verbose;
	my $records_above_thres = _count_unique_records_with_value_over_thres($self->val_col, $self->val_thres, $self->key_col, @tables);
	my $quantile_index = int($records_above_thres * 0.25);

	warn "Normalizing the values\n" if $self->verbose;
	_build_normalized_column_in_tables($self->val_col, $quantile_index, @tables); #Normalized column name is value column + "_uq" suffix
	
	warn "Writing output files\n" if $self->verbose;
	for (my $i=0; $i<@{$self->o_table}; $i++) {
		my (undef, $directory, undef) = File::Spec->splitpath($self->o_table->[$i]);
		make_path($directory);
		open (my $OUT, '>', $self->o_table->[$i]);
		print $OUT $tables[$i]->tsv;
		close $OUT;
	}
}


#######################################################################
############################   Functions   ############################
#######################################################################
sub _build_normalized_column_in_tables {
	my ($value_column, $quantile_index, @tables) = @_;
	
	# Sort the tables by descending value
	map {$_->sort($value_column, Data::Table::NUMBER, Data::Table::DESC)} @tables;
	
	foreach my $table (@tables) {
		my $uq = $table->elm($quantile_index, $value_column);
		my @normalized_values = map {$_ / $uq} $table->col($value_column);
		$table->addCol(\@normalized_values, $value_column."_uq");
	}
}

sub _count_unique_records_with_value_over_thres {
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


1;
