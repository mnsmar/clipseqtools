use Modern::Perl;
use autodie;
use Getopt::Long;
use lib '/home/pan.alexiou/mylib/perl/GenOO/v1.1/GenOO/lib/';
use GenOO::Data::File::FASTQ;
use GenOO::Data::File::FASTA;

my $help;
my @indexes;
my @outfiles;
my $verbose;
my $interactive;
my $infile;
my $intype;
my $statsfile;

GetOptions(
	'infile=s'         => \$infile,
        'type=s'           => \$intype,
        'index=s'          => \@indexes,
        'outfiles=s'       => \@outfiles,
        'statsfile=s'      => \$statsfile,
        'v'                => \$verbose,
#         'i'                => \$interactive,
        'h'                => \$help,
) or usage();
usage() if $help;

# my $all_input_ok == 0;
# if ($interactive){
# 	while ($all_input_ok == 0){
# 		warn "\nEntering Interactive Mode\n\n";
# 
# 		if (!defined $infile){
# 			warn "Input File Name:\n";}
# 		}
# 	# 	if (!defined $intype){
# 	# 		if ($verbose) {warn "\nATTENTION: Input file TYPE not provided - dying\n";}
# 	# 		die usage();
# 	# 	}
# 	# 	if ($#indexes < 0){
# 	# 		if ($verbose) {warn "\nATTENTION: Indexes array not provided - dying\n";}
# 	# 		die usage();
# 	# 	}
# 	# 	if ($#indexes != $#outfiles){
# 	# 		if ($verbose) {warn "\nATTENTION: Uneven number of Indexes and Outfiles provided - dying\n";}
# 	# 		die usage();
# 	# 	}
# 	}
# }

if ($verbose){warn "Checking Input\n";}
if (!defined $infile){
	if ($verbose) {warn "\nATTENTION: Input file not provided - dying\n";}
	die usage();
}

if (!defined $intype){
	if ($verbose) {warn "\nATTENTION: Input file TYPE not provided - dying\n";}
	die usage();
}
if ($#indexes < 0){
	if ($verbose) {warn "\nATTENTION: Indexes array not provided - dying\n";}
	die usage();
}

if ($#indexes != $#outfiles){
	if ($verbose) {warn "\nATTENTION: Uneven number of Indexes and Outfiles provided - dying\n";}
	die usage();
}

# 
my $timestart = time;
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
else{
	if ($verbose) {warn "\nATTENTION: Input file TYPE not correct - type is $intype not in accepted list [FA, FASTA, FQ, FASTQ] - dying\n";}
	die usage();
}
if ($verbose){warn "Validating input file $infile (type $intype) ".(time-$timestart)." sec\n";}

my %counts;
my %already_found;
$counts{"total"} = 0;

my @out_filehandles;
for (my $i = 0; $i < @outfiles; $i++) {
	my $outfile = $outfiles[$i];
	open ($out_filehandles[$i], ">", $outfile);
}

while (my $read = $file->next_record) {
	$counts{"total"}++;
	if (($counts{"total"} % 100 == 0) and ($verbose)){warn "Reads parsed:\t".$counts{"total"}." in ".int((time-$timestart)/60)." min\n";}
	for (my $i = 0; $i < @outfiles; $i++) {
		
		my $seq = $read->sequence;
		
		my $id;
		if ($intype eq "FQ"){ $id = '@'.$read->name; }
		elsif ($intype eq "FA"){ $id = '>'.$read->header; }

		my $chopped_seq;
		my $index = $indexes[$i];
		if ($index eq "NONE"){$index = "";}
		if ($seq =~ /^($index)([AGCTN]+)/) {
			$chopped_seq = $2;
			my $outread;
			if ($intype eq "FQ"){$outread = join("\n", ($id, $chopped_seq, "+", substr($read->quality, 0+length($index))));}
			elsif ($intype eq "FA"){$outread = join("\n", ($id, $chopped_seq));}
			$out_filehandles[$i]->print($outread."\n");
			my $outfile = $outfiles[$i];
			$counts{$outfile}++;
			last;
		}
	}
}

if ($statsfile){
	open OUTSTATS, ">",$statsfile;
	print OUTSTATS join("\t",("infile", "outfile", "index", "counts", "totalcounts", "ratio"))."\n";
}
for (my $i = 0; $i < @outfiles; $i++) {
	my $outfile = $outfiles[$i];
	my $index = $indexes[$i];
	if ($verbose){warn "$outfile\t".$counts{$outfile}."\t".$counts{"total"}."\t".int(100*($counts{$outfile}/$counts{"total"}))."%\t".$index."\n";}
	if ($statsfile){
		print OUTSTATS join("\t",($infile,$outfile,$index,$counts{$outfile},$counts{"total"},($counts{$outfile}/$counts{"total"})))."\n";
	}
}

if ($verbose){warn "total run time = ".int((time-$timestart)/60)." min\n";}

###########################################
# Subroutines used
###########################################
sub usage {
	print "\nUsage:   $0 <options>\n\n".
	      "Options:\n".
	      "    -infile	input file (FASTQ or FASTA format)\n".
	      "    -type	input file type (can be FASTQ, FQ, FASTA or FA)\n".
	      "    -index 	array of multiplex sequence (if no sequence - it should be NONE)\n".
	      "    -outfile 	array of output files - same order as index\n".
	      "    -statsfile   optional stats output file\n".
	      "    -v		verbose\n".
	      "    -h           print this help\n\n";
	exit;
} 
