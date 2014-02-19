#!/usr/bin/perl
use Modern::Perl;
use autodie;

##############################################
# Import external libraries
use Getopt::Long;
use File::Path qw(make_path);
use File::Spec;
use List::Util qw(sum max);


##############################################
# Import GenOO
use GenOO::RegionCollection::Factory;
use GenOO::TranscriptCollection::Factory;
use GenOO::GeneCollection::Factory;


# count_per_genic_element.pl -driver SQLite -database alignments.db -table sample -transcript_gtf /store/data/UCSC/hg19/annotation/UCSC_gene_parts.gtf -transcript_to_gene_file /store/data/UCSC/hg19/annotation/names.txt -ofile_prefix ../foo/counts_per_genic_element"


##############################################
# Read command options
my ($help, $database, $table, $host, $user, $pass, $min_length, $max_length, $transcript_gtf_file, $transcript_to_gene_file, $out_filename_prefix);

my $records_class = 'GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v2';
my $driver = "SQLite";

my $verbose;
my $testmode;

GetOptions(
        'h'               => \$help,
        'driver=s'        => \$driver,
        'host=s'          => \$host,
        'database=s'      => \$database,
        'table=s'         => \$table,
        'user=s'          => \$user,
        'password=s'      => \$pass,
        'records_class=s' => \$records_class,
        'min_length=i'    => \$min_length,
        'max_length=i'              => \$max_length,
        'transcript_gtf=s'          => \$transcript_gtf_file,
        'transcript_to_gene_file=s' => \$transcript_to_gene_file,  # can we get rid of this ???
        'ofile_prefix=s'            => \$out_filename_prefix,
        'v'                         => \$verbose,
        't'                         => \$testmode,
) or usage();
usage() if $help;

if ($testmode){$verbose = 1;}

map {defined $_ or usage()} ($transcript_gtf_file, $transcript_to_gene_file, $out_filename_prefix);

##############################################
# Create a transcript collection from a gtf file
if($verbose){warn "Creating transcript collection\n";}
my $transcript_collection = GenOO::TranscriptCollection::Factory->create('GTF', {
	file => $transcript_gtf_file
})->read_collection;


##############################################
# Create a gene collection from the transcript collection and a dictionary (hash) of transcript names to gene names
if($verbose){warn "Creating gene collection\n";}
my $transcript_id_to_genename = read_transcript_to_gene_file($transcript_to_gene_file);
my $gene_collection = GenOO::GeneCollection::Factory->create('FromTranscriptCollection', {
	transcript_collection => $transcript_collection,
	annotation_hash       => $transcript_id_to_genename
})->read_collection;


##############################################
# Create a collection for sequencing reads from database
if($verbose){warn "Creating reads collection\n";}
my $reads_collection = read_collection_from_database( $driver, $database, $table, $records_class, $host, $user, $pass);
$reads_collection->filter_by_length($min_length, $max_length) if (defined $min_length and defined $max_length);



##############################################
# Calculate counts of functional elements (from database)
if($verbose){warn "Calculate transcript and exon/intron counts by summing the total number of overlapping reads\n";}
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
});


##############################################
# Calculate gene counts
if($verbose){warn "Define gene counts as the counts of its most expressed transcript\n";}
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


##############################################
# Create output path
my ($volume, $directory, $file) = File::Spec->splitpath($out_filename_prefix);
make_path($directory);


##############################################
# Print results
if($verbose){warn "Printing gene counts\n";}
open(my $OUT1, '>', "$out_filename_prefix.counts.gene.tab");
say $OUT1 join("\t", 'gene_name', 'gene_location', 'gene_length', 'gene_count', 'gene_count_per_nt', 'gene_exonic_count', 'gene_exonic_length', 'gene_exonic_count_per_nt');
$gene_collection->foreach_record_do( sub {
	my ($gene) = @_;
	
	say $OUT1 join("\t", $gene->name, $gene->location, $gene->length, $gene->extra->{count}, $gene->extra->{count} / $gene->length, $gene->extra->{exonic_count}, $gene->exonic_length, $gene->extra->{exonic_count} / $gene->exonic_length );
});
close $OUT1;

if($verbose){warn "Printing transcript counts\n";}
open(my $OUT2, '>', "$out_filename_prefix.counts.transcript.tab");
say $OUT2 join("\t", 'transcript_id', 'transcript_location', 'transcript_length', 'gene_name', 'transcript_count', 'transcript_count_per_nt', 'transcript_exonic_count', 'transcript_exonic_length', 'transcript_exonic_count_per_nt', 'transcript_intronic_count', 'transcript_intronic_length', 'transcript_intronic_count_per_nt');
$transcript_collection->foreach_record_do( sub {
	my ($transcript) = @_;
	
	my $intronic_count_per_nt = $transcript->intronic_length > 0 ? $transcript->extra->{intronic_count} / $transcript->intronic_length : 'NA';
	
	say $OUT2 join("\t", $transcript->id, $transcript->location, $transcript->length, $transcript->gene->name, $transcript->extra->{count}, $transcript->extra->{count} / $transcript->length, $transcript->extra->{exonic_count}, $transcript->exonic_length, $transcript->extra->{exonic_count} / $transcript->exonic_length, $transcript->extra->{intronic_count}, $transcript->intronic_length, $intronic_count_per_nt);
});
close $OUT2;

if($verbose){warn "Printing exon counts\n";}
open(my $OUT3, '>', "$out_filename_prefix.counts.exon.tab");
say $OUT3 join("\t", 'transcript_id', 'exon_location', 'exon_length', 'gene_name', 'exon_count', 'exon_count_per_nt');
$transcript_collection->foreach_record_do( sub {
	my ($transcript) = @_;
	
	foreach my $part (@{$transcript->exons}) {
		say $OUT3 join("\t", $transcript->id, $part->location, $part->length, $transcript->gene->name, $part->extra->{count}, $part->extra->{count} / $part->length);
	}
});
close $OUT3;

if($verbose){warn "Printing intron counts\n";}
open(my $OUT4, '>', "$out_filename_prefix.counts.intron.tab");
say $OUT4 join("\t", 'transcript_id', 'intron_location', 'intron_length', 'gene_name', 'intron_count', 'intron_count_per_nt');
$transcript_collection->foreach_record_do( sub {
	my ($transcript) = @_;
	
	foreach my $part (@{$transcript->introns}) {
		say $OUT4 join("\t", $transcript->id, $part->location, $part->length, $transcript->gene->name, $part->extra->{count}, $part->extra->{count} / $part->length);
	}
});
close $OUT4;


###########################################
# Subroutines used
###########################################
sub usage {
	print "\nUsage:\n".
	      "$0 [options] <transcript_gtf_file> <transcript_to_gene_file> <out_filename_prefix>\n\n".
	      "Description:\n".
	      "Measures the read count for each genic element (ie. transcript, gene, exon, intron).\n".
	      "*Transcript count is measured only for its exons.\n".
	      "*Gene count is measured only for its exonic regions.\n\n".
	      "Options:\n".
	      "        -driver=<Str>                  specify driver for the database. This can be mysql, SQLite, etc\n".
	      "        -database=<Str>                the database name\n".
	      "        -table=<Str>                   the database table with data\n".
	      "        -host=<Str>                    the hostname for database connection\n".
	      "        -user=<Str>                    the username for database connection\n".
	      "        -password=<Str>                the password for database connection\n".
	      "        -records_class=<Str>           the class name of the records stored in the database (Default: GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v1)\n".
	      "        -min_length=<Int>              reads with smaller length than this value are excluded\n".
	      "        -max_length=<Int>              reads with larger length than this value are excluded\n".
	      "        -transcript_gtf=<Str>          the GTF file with the transcript information\n".
	      "        -transcript_to_gene_file=<Str> a file that maps gene names to transcript ids\n".
	      "        -ofile_prefix=<Str>            the prefix for the path used to create the output files\n".
	      "        -h                             print this help\n\n";
	exit;
}

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
