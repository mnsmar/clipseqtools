use Modern::Perl;
use autodie;
use Getopt::Long;
use lib '/home/pan.alexiou/mylib/perl/GenOO/v1.1/GenOO/lib/';


#count number of nucleotide occurrences in sequence file – total counts, per position counts, start/stop region, from middle, from ends etc. possible graphs in R. 

my $infile;
my $type;
my $outfolder;
GetOptions(
	'infile=s'         => \$infile,
        'type=s'           => \$intype, #can be FASTA / FA, FASTQ / FQ, SAM
        'outfolder=s'        => \$outfolder,
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

if (!defined $outfolder){
	if ($verbose) {warn "\nATTENTION: Output file not provided - dying\n";}
	die usage();
}

open (OUT1, ">", $outfolder."nt_counts_full.tab") or die "Cannot create $outfolder"."nt_counts_full.tab\n";
open (OUT2, ">", $outfolder."nt_counts_start.tab") or die "Cannot create $outfolder"."nt_counts_start.tab\n";
open (OUT3, ">", $outfolder."nt_counts_end.tab") or die "Cannot create $outfolder"."nt_counts_end.tab\n";

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

if ($verbose){warn "Validating input file $infile (type $intype) ".(time-$timestart)." sec\n";}

#############################
### MAIN CODE         #######
#############################

my %counts;
my %counts_start;
my %counts_end;

while (my $read = $file->next_record) {
	my $sequence;
	if ($intype eq "SAM"){
		$sequence = $read->query_seq;
	}
	else {
		$sequence = $read->sequence;
	}
	
	my $length = length($sequence);
	
	my @sequence = split(//,$sequence);
	
	foreach my $nt (@sequence){
		$counts{$nt}{$length}++;
	}
	
	for (my $i = 0; $i < $length; $i++){
		my $nt = $sequence[$i];
		$counts_start{$nt}{$i+1}++; #counts one based
		$counts_end{$nt}{($length-$i)}++; #counts one based from end
	}
}

#############################
### WRITE OUTPUT      #######
#############################

print OUT1 join("\t", ("nt", "length", "count"))."\n";
foreach my $nt (keys %counts){
	foreach my $length (keys %{$counts{$nt}}){
		print OUT1 join("\t", ($nt, $length, $counts{$nt}{$length}))."\n";
	}
}
close OUT1;

print OUT2 join("\t", ("nt", "position", "count"))."\n";
foreach my $nt (keys %counts_start){
	foreach my $position (keys %{$counts_start{$nt}}){
		print OUT2 join("\t", ($nt, $position, $counts_start{$nt}{$position}))."\n";
	}
}
close OUT2;

print OUT3 join("\t", ("nt", "position", "count"))."\n";
foreach my $nt (keys %counts_end){
	foreach my $position (keys %{$counts_end{$nt}}){
		print OUT3 join("\t", ($nt, $position, $counts_end{$nt}{$position}))."\n";
	}
}
close OUT3;



###########################################
# Subroutines used
###########################################
sub usage {
	print "\nUsage:   $0 <options>\n\n".
	      "Options:\n".
	      "    -infile	input file (FASTQ or FASTA format)\n".
	      "    -type	input file type (can be FASTQ, FQ, FASTA or FA)\n".
	      "    -outfolder   output file folder\n".
	      "    -v		verbose\n".
	      "    -h           print this help\n\n";
	exit;
} 