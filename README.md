# CLIPSeqTools


## Summary
CLIPSeqTools is a collection of command line applications used for the analysis of CLIP-Seq (UV cross-linking and immunoprecipitation with high-throughput sequencing) data.
It offers a wide range of analyses (eg. genome read coverage, motif enrichment, relative positioning of reads of two libraries, etc).
The toolbox is primarily oriented for bioinfromaticians but the commands are simple enough for non experts to use.

## Installation
* **Using CPAN**
  1. If you have cpanm installed. `cpanm CLIPSeqTools`.
  2. If you do not have cpanm. See [here](http://www.cpan.org/modules/INSTALL.html).
* **Using Git** - Preferred so you may contribute
  1. Install git ([directions](http://git-scm.com/downloads)).
  2. Install dependencies (listed below) from CPAN. [How to install CPAN modules](http://www.cpan.org/modules/INSTALL.html).
  3. Clone the repository on your machine
     `git clone https://github.com/palexiou/GenOO-CLIP.git`.

## Dependencies (maybe not exhaustive)
* GenOO
* Pod::Usage
* Modern::Perl
* GenOOx::Data::File::SAMstar
* GenOOx::Data::File::SAMbwa
* DBD::SQLite
* MooseX::Getopt
* IO::Interactive

## Usage examples
To process a fastq file, align the reads on the reference genome, annotate the alignments with genic, repeat masker and PhyloP conservation information and more.

```bash
clipseqtools-preprocess all \
--adaptor <5_END_ADAPTOR> \
--fastq <FASTQ_FILE> \
--gtf <GTF_FILE_WITH_TRANSCRIPTS> \
--rmsk <REPEAT_MASKER_BED_FILE> \
--star_genome <STAR_INDEX_DIR> \
--phyloP_dir <PHYLOP_DTA_DIR> \
--rname_sizes <CHROMOSOME_SIZES_FILE> \
--o_prefix <OUTPUT_DIR> \
--threads <NUMBER_OF_PROCESSORS> \
-v
```

To run all clipseqtools analyses.

```bash
clipseqtools all \
--database <DATABASE_FILE_FROM_PREVIOUS_STEP> \ 
--gtf <GTF_FILE_WITH_TRANSCRIPTS> \
--rname_sizes <CHROMOSOME_SIZES_FILE> \
--o_prefix <OUTPUT_DIR> \
--plot \
-v
```

The two commands will create all the required files to run clipseqtools and
will run all analysis producing tables and figure files in the output
directory.

## State
The toolbox is under heavy development and functionality is added regularly.
Consider it unstable.

## Copyright
Copyright (c) 2014 Emmanouil "Manolis" Maragkakis and Panagiotis Alexiou.

## License
This library is free software and may be distributed under the same terms as perl itself.

This library is distributed in the hope that it will be useful, but **WITHOUT ANY WARRANTY**; without even the implied warranty of merchantability or fitness for a particular purpose.
