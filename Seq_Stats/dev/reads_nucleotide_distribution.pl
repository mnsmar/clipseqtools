use Modern::Perl;
use autodie;
use Getopt::Long;
use lib '/home/pan.alexiou/mylib/perl/GenOO/v1.1/GenOO/lib/';
use GenOO::Data::File::FASTQ;
use GenOO::Data::File::FASTA;
use GenOO::Data::File::SAM;

my $infile;
my $intype;
my $outfolder;
my $verbose;
my $removeN;
my $min_length;
my $max_length;
my $help;
GetOptions(
	'infile=s'         => \$infile,
        'intype=s'         => \$intype, #can be FASTA / FA, FASTQ / FQ, SAM
        'outfolder=s'      => \$outfolder,
        'min_length=i'     => \$min_length,
        'max_length=i'     => \$max_length,
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

if ($verbose){warn "Validating input file $infile (type $intype) ".(time-$timestart)." sec\n";}

#############################
### MAIN CODE         #######
#############################

my %counts;
my %counts_start;
my %counts_end;
my $counter=0;
my @all_nts = ("A", "T", "G", "C", "N");

while (my $read = $file->next_record) {
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
	my @sequence = split(//,$sequence);
	
	foreach my $nt (@sequence){
		if (($nt eq "N") and ($removeN)){next;}
		$counts{$length}{$nt}++;
	}
	
	for (my $i = 0; $i < $length; $i++){
		my $nt = $sequence[$i];
		$counts_start{$i+1}{$nt}++; #counts one based
		$counts_end{($length-$i)}{$nt}++; #counts one based from end
	}
	
	if (($counter % 1000000 == 0) and ($verbose)){warn "Read $counter entries from $infile (type $intype) - ".(time-$timestart)." sec\n";}
}

#############################
### WRITE OUTPUT      #######
#############################

if ($verbose){warn "Writing Output... ".(time-$timestart)." sec\n";}

print OUT1 join("\t", ("length", @all_nts))."\n";
foreach my $length (sort {$a <=> $b} keys %counts){
	print OUT1 $length;
	foreach my $nt (@all_nts){
		if (!exists $counts{$length}{$nt}){$counts{$length}{$nt} = 0;}
		print OUT1 "\t".$counts{$length}{$nt};
	}
	print OUT1 "\n";
}
close OUT1;

print OUT2 join("\t", ("position", @all_nts))."\n";
foreach my $position (sort {$a <=> $b} keys %counts_start){
	print OUT2 $position;
	foreach my $nt (@all_nts){
		if (!exists $counts_start{$position}{$nt}){$counts_start{$position}{$nt} = 0;}
		print OUT2 "\t".$counts_start{$position}{$nt};
	}
	print OUT2 "\n";
}
close OUT2;

print OUT3 join("\t", ("position", @all_nts))."\n";
foreach my $position (sort {$a <=> $b} keys %counts_end){
	print OUT3 $position;
	foreach my $nt (@all_nts){
		if (!exists $counts_end{$position}{$nt}){$counts_end{$position}{$nt} = 0;}
		print OUT3 "\t".$counts_end{$position}{$nt};
	}
	print OUT3 "\n";
}
close OUT3;

if ($verbose){warn "Done! ".(time-$timestart)." sec\n";}

###########################################
# Subroutines used
###########################################
sub usage {
	print "\nUsage:   $0 <options>\n\n".
	      "Options:\n\n".
	      "(Required)\n".
	      "    -infile      input file (FASTQ or FASTA format)\n".
	      "    -intype      input file type (can be FASTQ, FQ, FASTA or FA)\n".
	      "    -outfolder   output file folder\n\n".
	      "(Optional)\n".
	      "    -min_length  only count reads larger than this (integer)\n".
              "    -max_length  only count reads smaller than this (integer)\n".
	      "    -v           verbose\n".
	      "    -h           print this help\n\n";
	exit;
} 