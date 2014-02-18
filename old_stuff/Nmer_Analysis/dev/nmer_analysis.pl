#!/usr/bin/perl 

use Modern::Perl;
use autodie;
use Getopt::Long;
use List::Util qw(shuffle);
use lib '/home/pan.alexiou/mylib/perl/GenOO/v1.1/GenOO/lib';
use GenOO::Data::File::FASTQ;
use GenOO::Data::File::FASTA;
use GenOO::Data::File::SAM;

my $infile;
my $intype;
my $outfile;
my $verbose;
my $min_length;
my $max_length;
my $N = 6;
my $permutations = 100;
my $help;

GetOptions(
	'infile=s'         => \$infile,
        'intype=s'         => \$intype, #can be FASTA / FA, FASTQ / FQ, SAM
        'outfile=s'        => \$outfile,
        'min_length=i'     => \$min_length,
        'max_length=i'     => \$max_length,
        'perm=i'           => \$permutations,
        'N=i'              => \$N,
        'v'                => \$verbose,
#         'i'                => \$interactive,
        'h'                => \$help,
) or usage();
usage() if $help;

my $timestart = time;



#############################
### USER INPUT CHECKS #######
#############################

if ($verbose){warn "Checking Input\n";}
if (!defined $infile){
	if ($verbose) {warn "\nATTENTION: Input file not provided - dying\n";}
	die usage();
}

if (!defined $intype){
	if ($verbose) {warn "\nATTENTION: Input file TYPE not provided - dying\n";}
	die usage();
}

if (!defined $outfile){
	if ($verbose) {warn "\nATTENTION: Output file not provided - dying\n";}
	die usage();
}

my $file;
if ((uc($intype) eq "FQ") or (uc($intype) eq "FASTQ")){
	$intype = "FQ";
	$file = GenOO::Data::File::FASTQ->new({
		file => $infile,
	});
}
elsif ((uc($intype) eq "FA") or (uc($intype) eq "FASTA")){
	$intype = "FA";
	$file = GenOO::Data::File::FASTA->new({
		file => $infile,
	});
}
elsif (uc($intype) eq "SAM"){
	$intype = "SAM";
	$file = GenOO::Data::File::SAM->new({
		file => $infile,
	});
}
else{
	if ($verbose) {warn "\nATTENTION: Input file TYPE not correct - type is $intype not in accepted list [FA, FASTA, FQ, FASTQ, SAM] - dying\n";}
	die usage();
}

if (!defined $file){die "Cannot open Input file\n";}

open (OUT, ">", $outfile) or die "Cannot open $outfile to write output\n";

if ($verbose){warn "Validating input file $infile (type $intype) ".(time-$timestart)." sec\n";}

#############################
### MAIN CODE         #######
#############################
my %counts;
my $total_kmers = 0;
my %shuffled_counts;
my $counter = 0;
while (my $read = $file->next_record) {
# 	warn "  Calculating nucleotide content for read\n";
	my $sequence;
	$counter++;
	if ($intype eq "SAM"){
		$sequence = $read->query_seq;
	}
	else {
		$sequence = $read->sequence;
	}
	
	my $length = length($sequence);
	if (($max_length) and ($length > $max_length)){next;}
	if (($min_length) and ($length < $min_length)){next;}
	
	$sequence = uc($sequence);
	$sequence =~ tr/U/T/;
	
	for (my $i = 0; $i < length($sequence) - $N; $i++){
		my $Nmer = substr($sequence, $i, $N);
		$counts{$Nmer} += 1;
		$total_kmers += 1;
	}
# 	warn $sequence;
	for (my $perm = 0; $perm < $permutations; $perm++){
		my $shuffled_string = shuffle_string($sequence);
# 		warn $shuffled_string."\n";
		for (my $i = 0; $i < length($shuffled_string) - $N; $i++){
			my $Nmer = substr($shuffled_string, $i, $N);
			$shuffled_counts{$Nmer}{$perm} += 1;
		}
	}

	if (($counter % 1000000 == 0) and ($verbose)){warn "Read $counter entries from $infile (type $intype) - ".(time-$timestart)." sec\n";}
}

print OUT "Nmer\tCounts\tPval\tO/E\n";
foreach my $Nmer (sort {$counts{$b} <=> $counts{$a}} keys %counts){
	my $pval = 0;
	for (my $perm = 0; $perm < $permutations; $perm++){
		if (exists $shuffled_counts{$Nmer}{$perm} and $shuffled_counts{$Nmer}{$perm} >= $counts{$Nmer}){$pval++;}
	}
	$pval = $pval / $permutations;
	print OUT $Nmer."\t".($counts{$Nmer}/$total_kmers)."\t".$pval."\t".(($counts{$Nmer}/$total_kmers) * (4 ** $N))."\n";
}
close OUT;

###########################################
# Subroutines used
###########################################
sub usage {
	print "\nUsage:   $0 <options>\n\n".
	      "Options:\n\n".
	      "(Required)\n".
	      "    -infile      input file (FASTQ or FASTA format)\n".
	      "    -intype      input file type (can be FASTQ, FQ, FASTA or FA)\n".
	      "    -outfile     output file\n\n".
	      "(Optional)\n".
	      "    -min_length  only count reads larger than this (integer)\n".
              "    -max_length  only count reads smaller than this (integer)\n".
              "    -N           length of Nmer (defaults to 6)\n".
              "    -perm        number of permutations (defaults to 100)\n".
	      "    -v           verbose\n".
	      "    -h           print this help\n\n";
	exit;
}

sub shuffle_string {
	my $string = shift;
	my @array = split("",$string);
	my @shuffled_array = shuffle(@array);
	return join("", @shuffled_array);
}