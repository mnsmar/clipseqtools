#!/usr/bin/env perl

=head1 NAME

    count_tags_per_genic_element.pl

=head1 SYNOPSIS

    count_tags_per_genic_element.pl [options/parameters]
    
=head1 DESCRIPTION

    Measures the read count for each genic element (ie. transcript, gene, exon, intron)"
    *Transcript count is measured only for its exons."
    *Gene count is measured only for its exonic regions."

=head1 OPTIONS AND ARGUMENTS

    Input
      Database options (DBIC)
        -driver <Str>        specify driver for database. This can be mysql, SQLite, etc.
        -database <Str>      database name.
        -table <Str>         database table with data.
        -host <Str>          hostname for database connection.
        -user <Str>          username for database connection.
        -password <Str>      password for database connection.
      Gene Models
        -gtf <Str>           GTF file for transcripts.
        -transcript_to_gene_file <Str>   a file that maps gene names to transcript ids.
    
    Output
        -ofile_prefix <Str>  prefix for the path used to create output files - path will be created.
    
    Input Filters.
        -min_length <Int>    reads with smaller length than this value are excluded.
        -max_length <Int>    reads with larger length than this value are excluded.
        -no_repeat           keep only non-repeat mapping reads.
        -with_deletion       keep only reads with deletions (HITS-CLIP).
        -with_TC             keep only reads with T -> C mismatch (PAR-CLIP).
    
    Other options.
        -v                 verbosity. If used progress lines are printed.
        -h                 print this help;


=cut

use Modern::Perl;
use autodie;

##############################################
# Import external libraries
use Getopt::Long;
use File::Path qw(make_path);
use File::Spec;
use List::Util qw(sum max);
use Pod::Usage;

##############################################
# Import GenOO
use GenOO::RegionCollection::Factory;
use GenOO::TranscriptCollection::Factory;
use GenOO::GeneCollection::Factory;

##############################################
# Read command options
my $records_class = 'GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3';
my $driver = "SQLite";

GetOptions(
        'h'               => \my $help,

        #I/O
        'database=s'      => \my $database,
        'table=s'         => \my $table,
        
        'driver=s'        => \$driver,
        'host=s'          => \my $host, #non sqlite
        'user=s'          => \my $user, #non sqlite
        'password=s'      => \my $pass, #non sqlite

        'gtf=s'           => \my $transcript_gtf_file, #
        'transcript_to_gene_file=s' => \my $transcript_to_gene_file,  # DEV can we get rid of this ???
        
        'ofile_prefix=s'  => \my $out_filename_prefix,
        
        #filters
        'min_length=i'    => \my $min_length, #inclusive
        'max_length=i'    => \my $max_length, #inclusive
        'no_repeat'       => \my $no_repeat, #keep only non repeat element reads
        'with_deletion'   => \my $with_deletion, #keep only reads with deletions (HITS-CLIP)
        'with_TC'         => \my $with_TC, #keep only reads with T -> C mismatch (PAR-CLIP)
        
        #flags
        'v'               => \my $verbose,
        'dev'             => \my $devmode,
    
) or pod2usage({-verbose => 1});
pod2usage({-verbose => 2}) if $help;

if ($devmode){$verbose = 1;}
map {defined $_ or pod2usage({-verbose => 1})} ($transcript_gtf_file, $transcript_to_gene_file, $out_filename_prefix);
my $startime = time;
my $prevtime = time;

##############################################
warn "Creating transcript collection\n" if $verbose;
my $transcript_collection = GenOO::TranscriptCollection::Factory->create('GTF', {
	file => $transcript_gtf_file
})->read_collection;

if ($devmode){warn "Step:\t".((int(((time-$prevtime)/60)*100))/100)." min\n";}
if ($devmode){warn "Time:\t".((int(((time-$startime)/60)*100))/100)." min\n";}
$prevtime = time;

##############################################
warn "Creating gene collection\n" if $verbose;
my $transcript_id_to_genename = read_transcript_to_gene_file($transcript_to_gene_file);
my $gene_collection = GenOO::GeneCollection::Factory->create('FromTranscriptCollection', {
	transcript_collection => $transcript_collection,
	annotation_hash       => $transcript_id_to_genename
})->read_collection;

if ($devmode){warn "Step:\t".((int(((time-$prevtime)/60)*100))/100)." min\n";}
if ($devmode){warn "Time:\t".((int(((time-$startime)/60)*100))/100)." min\n";}
$prevtime = time;

##############################################
warn "Creating reads collection\n" if $verbose;
my $reads_collection = read_collection_from_database( $driver, $database, $table, $records_class, $host, $user, $pass);

if ($devmode){warn "Step:\t".((int(((time-$prevtime)/60)*100))/100)." min\n";}
if ($devmode){warn "Time:\t".((int(((time-$startime)/60)*100))/100)." min\n";}
$prevtime = time;

##############################################
warn "Filtering reads collection\n" if $verbose;
my $filtered_rs = $reads_collection->resultset;
$filtered_rs = $filtered_rs->filter_by_length($min_length, $max_length) if (defined $min_length and defined $max_length);
$filtered_rs = $filtered_rs->filter_by_min_length($min_length) if (defined $min_length and !defined $max_length);
$filtered_rs = $filtered_rs->filter_by_max_length($max_length) if (!defined $min_length and defined $max_length);
$filtered_rs = $filtered_rs->search({rmsk => undef}) if defined $no_repeat;
$filtered_rs = $filtered_rs->search({with_deletion => {'!=', undef}}) if defined $with_deletion;
$filtered_rs = $filtered_rs->search({with_tc => {'!=', undef}}) if defined $with_TC;

$reads_collection->resultset($filtered_rs);

if ($devmode){warn "Step:\t".((int(((time-$prevtime)/60)*100))/100)." min\n";}
if ($devmode){warn "Time:\t".((int(((time-$startime)/60)*100))/100)." min\n";}
$prevtime = time;

##############################################
warn "Calculate transcript and exon/intron counts by summing the total number of overlapping reads\n" if $verbose;
my $counter = 1;

$transcript_collection->foreach_record_do( sub {
	my ($transcript) = @_;
	
	# Calculate exon and transcript counts. Transcript counts is calculated by the exonic region only
	my $transcript_exonic_count = 0;
	foreach my $exon (@{$transcript->exons}) {
		my $exon_count = $reads_collection->total_copy_number_for_records_contained_in_region($exon->strand, $exon->chromosome, $exon->start, $exon->stop);
		$exon->extra({count => $exon_count});
		$transcript_exonic_count += $exon_count;
	}
	
	# Calculate intron counts.
	my $transcript_intronic_count = 0;
	foreach my $intron (@{$transcript->introns}) {
		my $intron_count = $reads_collection->total_copy_number_for_records_contained_in_region($intron->strand, $intron->chromosome, $intron->start, $intron->stop);
		$intron->extra({count => $intron_count});
		$transcript_intronic_count += $intron_count;
	}
	
	my $transcript_count = $reads_collection->total_copy_number_for_records_contained_in_region($transcript->strand, $transcript->chromosome, $transcript->start, $transcript->stop);
	
	$transcript->extra({
		count          => $transcript_count,
		exonic_count   => $transcript_exonic_count,
		intronic_count => $transcript_intronic_count
	});
	
	if ($verbose and ($counter % 1000 == 0)){warn $counter."\t".((int(((time-$prevtime)/60)*100))/100)."\n";}
	$counter++;
	
});

if ($devmode){warn "Step:\t".((int(((time-$prevtime)/60)*100))/100)." min\n";}
if ($devmode){warn "Time:\t".((int(((time-$startime)/60)*100))/100)." min\n";}
$prevtime = time;

##############################################
warn "Define gene counts as the counts of its most expressed transcript\n" if $verbose;
$gene_collection->foreach_record_do( sub {
	my ($gene) = @_;
	
	my $gene_exonic_count = 0;
	foreach my $exonic_region ($gene->all_exonic_regions) {
		$gene_exonic_count += $reads_collection->total_copy_number_for_records_contained_in_region($exonic_region->strand, $exonic_region->chromosome, $exonic_region->start, $exonic_region->stop);
	}
	my $gene_count = $reads_collection->total_copy_number_for_records_contained_in_region($gene->strand, $gene->chromosome, $gene->start, $gene->stop);
	
	$gene->extra({
		count        => $gene_count,
		exonic_count => $gene_exonic_count
	});
});

if ($devmode){warn "Step:\t".((int(((time-$prevtime)/60)*100))/100)." min\n";}
if ($devmode){warn "Time:\t".((int(((time-$startime)/60)*100))/100)." min\n";}
$prevtime = time;

##############################################
# Create output path
my ($volume, $directory, $file) = File::Spec->splitpath($out_filename_prefix);
make_path($directory);


##############################################
# Print results
warn "Printing gene counts\n" if $verbose;
open(my $OUT1, '>', "$out_filename_prefix.counts.gene.tab");
say $OUT1 join("\t", 'gene_name', 'gene_location', 'gene_length', 'gene_count', 'gene_count_per_nt', 'gene_exonic_count', 'gene_exonic_length', 'gene_exonic_count_per_nt');
$gene_collection->foreach_record_do( sub {
	my ($gene) = @_;
	
	say $OUT1 join("\t", $gene->name, $gene->location, $gene->length, $gene->extra->{count}, $gene->extra->{count} / $gene->length, $gene->extra->{exonic_count}, $gene->exonic_length, $gene->extra->{exonic_count} / $gene->exonic_length );
});
close $OUT1;

warn "Printing transcript counts\n" if $verbose;
open(my $OUT2, '>', "$out_filename_prefix.counts.transcript.tab");
say $OUT2 join("\t", 'transcript_id', 'transcript_location', 'transcript_length', 'gene_name', 'transcript_count', 'transcript_count_per_nt', 'transcript_exonic_count', 'transcript_exonic_length', 'transcript_exonic_count_per_nt', 'transcript_intronic_count', 'transcript_intronic_length', 'transcript_intronic_count_per_nt');
$transcript_collection->foreach_record_do( sub {
	my ($transcript) = @_;
	
	my $intronic_count_per_nt = $transcript->intronic_length > 0 ? $transcript->extra->{intronic_count} / $transcript->intronic_length : 'NA';
	
	say $OUT2 join("\t", $transcript->id, $transcript->location, $transcript->length, $transcript->gene->name, $transcript->extra->{count}, $transcript->extra->{count} / $transcript->length, $transcript->extra->{exonic_count}, $transcript->exonic_length, $transcript->extra->{exonic_count} / $transcript->exonic_length, $transcript->extra->{intronic_count}, $transcript->intronic_length, $intronic_count_per_nt);
});
close $OUT2;

warn "Printing exon counts\n" if $verbose;
open(my $OUT3, '>', "$out_filename_prefix.counts.exon.tab");
say $OUT3 join("\t", 'transcript_id', 'exon_location', 'exon_length', 'gene_name', 'exon_count', 'exon_count_per_nt');
$transcript_collection->foreach_record_do( sub {
	my ($transcript) = @_;
	
	foreach my $part (@{$transcript->exons}) {
		say $OUT3 join("\t", $transcript->id, $part->location, $part->length, $transcript->gene->name, $part->extra->{count}, $part->extra->{count} / $part->length);
	}
});
close $OUT3;

warn "Printing intron counts\n" if $verbose;
open(my $OUT4, '>', "$out_filename_prefix.counts.intron.tab");
say $OUT4 join("\t", 'transcript_id', 'intron_location', 'intron_length', 'gene_name', 'intron_count', 'intron_count_per_nt');
$transcript_collection->foreach_record_do( sub {
	my ($transcript) = @_;
	
	foreach my $part (@{$transcript->introns}) {
		say $OUT4 join("\t", $transcript->id, $part->location, $part->length, $transcript->gene->name, $part->extra->{count}, $part->extra->{count} / $part->length);
	}
});
close $OUT4;

if ($devmode){warn "Step:\t".((int(((time-$prevtime)/60)*100))/100)." min\n";}
if ($devmode){warn "END TOTAL TIME:\t".((int(((time-$startime)/60)*100))/100)." min\n";}

###########################################
# Subroutines used
###########################################

sub read_collection_from_database {
	my ($driver, $database, $table, $records_class, $host, $user, $pass) = @_;
	
	map {defined $_ or usage()} ($driver, $database, $table);
	return GenOO::RegionCollection::Factory->create('DBIC', {
		driver        => $driver,
		host          => $host,
		database      => $database,
		user          => $user,
		password      => $pass,
		table         => $table,
		records_class => $records_class,
	})->read_collection;
}

sub read_transcript_to_gene_file {
	my ($file) = @_;
	
	my %transcript_id_to_genename;
	
	open(my $IN, '<', $file);
	while (my $line = $IN->getline){
		my ($transcript_id, undef, $genename, $description) = split(/\t/,$line);
		$transcript_id_to_genename{$transcript_id} = $genename;
	}
	$IN->close;
	
	return \%transcript_id_to_genename;
}
