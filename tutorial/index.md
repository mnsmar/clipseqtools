---
layout: default
title: CLIPSeqTools-Tutorial
---

# Available Toolboxes

## A) clipseqtools-preprocess

The _CLIPSeqTools_ toolboxes require that the alignment data are stored in a
database (e.g. SQLite, MySQL, etc.). The advantages of following this approach
come from the fact that databases support efficient range queries and at the
same time allow for straightforward annotation of the reads. The importance of
the former is evident - almost all analyses require running some sort of range
query on the datasets. The latter, is especially important for CLIP-Seq
analysis. The reason is that in certain cases an analysis might need to be
limited on a particular subset of the data probably corresponding to a
specific annotation (e.g. genic areas) or exclude an annotation (e.g. reads
overlapping with repeat elements) or maybe a combination of both cases.
Databases allow to do such selections particularly easy with usually no or
small additional computational load.

`clipseqtools-preprocess` is a module that is used to prepare the files
(database) that `clipseqtools` and `clipseqtools-compare` require. It will
get from a FastQ file with CLIP-Seq data to an SQLite database with most
critical default annotations included. In more detail, it will process the
FastQ file, align the reads on a reference genome, annotate the alignments
with genic, repeat masker and evolutionary conservation information and
finally prepare an SQLite database compatible with `clipseqtools` and
`clipseqtools-compare`.

### Supported commands

Each command of `clipseqtools-preprocess` is designed to perform a well
defined task. To invoke a command use:

    clipseqtools-compare <command>

`clipseqtools-preprocess` supports the following commands which can run
independently or as a predefined pipeline.

1. `all` - Will run all of the commands as a pipeline. This is probably the
most common option to use unless you need very fine-grained control on what is
happening.

2. `cut_adaptor` - Remove the adaptor sequence from the 3'end of reads using
the _cutadapt_ program.

3. `star_alignment` - Align the reads on a reference genome using the _STAR_
program.

4. `cleanup_alignment` - Sort STAR alignments and keep only a single record
for multimappers.

5. `sam_to_sqlite` - Load the SAM file with the alignments in an SQLite
database.

6. `annotate_with_deletions` - Annotate alignments with deletions.

7. `annotate_with_file` - Annotate alignments contained within regions from a
BED/SAM file.

8. `annotate_with_genic_elements` - Annotate alignments with genic information
(transcripts, exons, 3'UTRs, etc).

9. `annotate_with_conservation` - Annotate alignments with phastCons
conservation scores.

### Details for database

`clipseqtools-preprocess` will create a database compatible with
`clipseqtools`. The fields of the database table are extracted directly from
the SAM file with the alignments. Not all information are extracted from the
SAM file. Only the information that is required by `clipseqtools`.

Specifically the fields that are included in the database are:

- `id` - An autoincrement id.

- `strand` - Can be +1 for "+" strand and -1 for "-" strand depending on where
  the read alinged to.

- `rname` - Name of the reference sequence on which the read aligned to.
  Usually a chromosome name.

- `start` - Position on reference sequence where the alignment starts, 0-based
  inclusive.

- `stop` - Position on reference sequence where the alignment stops, 0-based
  inclusive.

- `copy_number` - Number of reads with the same sequence that align on this
  position.

- `sequence` - Sequence of the read.

- `cigar` - CIGAR alignment string - see SAM file format documentation for
  details.

- `mdz` - MD:Z alignment tag - see the SAM file format documentation for
  details.

- `number_of_mappings` - Number of alternative places in which the read aligns
  to.

- `query_length` - Length of the read.

- `alignment_length` - Length of the alignment - can be different from read
  length due to insertions or deletions.

Extra columns will be added to the database, if and when the annotation
commands run. These annotation columns are:

- `transcript` - Defined if the read is contained in a transcript and not
  defined otherwise.

- `coding_transcript` - Defined if the read is contained in a coding
  transcript and not defined otherwise.

- `exon` - Defined if the read is contained in an exon and not defined
  otherwise.

- `utr5` - Defined if the read is contained in a 5'UTR and not defined
  otherwise.

- `cds` - Defined if the read is contained in a coding sequence and not
  defined otherwise.

- `utr3` - Defined if the read is contained in a 3'UTR and not defined
  otherwise.

- `rmsk` - Defined if the read is contained in a repeat element (Repeat
  Masker) and not defined otherwise.

- `deletion` - Defined if the read alignment has a deletion and not defined
  otherwise.

- `conservation` - Conservation score for the read. The score is calculated as
  the average phastCons score of all the nucleotides of the read. To minimize
  storage needs, the phastCons conservation score is multiplied by 1000 to
  convert it from floating point number to integer.

## B) clipseqtools

`clipseqtools` is the main toolbox of the _CLIPSeqTools_ suite. It runs
analyses on a single dataset. It offers a wide selection of tools that cover
many aspects of a CLIP-Seq analysis pipeline.

### Supported commands

Each command of `clipseqtools` is designed to perform a well defined task. To
invoke a command use:

    clipseqtools <command>

`clipseqtools` supports the following commands which can run independently or
as a predefined pipeline.

1. `all` Will run all of the commands as a pipeline. This is probably the
  most common option to use unless you need very fine-grained control on what
  is happening.

2. `reads_long_gaps_size_distribution` Measure the size distribution of
  long alignment gaps (eg. alignment on exon-exon junctions) produced by a gap
  aware aligner.

3. `size_distribution` Measure the size distribution for reads.

4. `cluster_size_and_score_distribution` Assemble reads in clusters and
  measure their size and number of contained reads distribution.

5. `count_reads_on_genic_elements` Count reads on transcripts, genes,
  exons and introns.

6. `distribution_on_genic_elements` Measure how reads are distributed
  along the length of 5'UTR, CDS and 3'UTR.

7. `distribution_on_introns_exons` Measure how reads are distributed along
  the length of exons and introns.

8. `genome_coverage` Measure percent of genome covered by reads.

9. `genomic_distribution` Count reads on genes, repeats, exons , introns,
  5'UTRs, ...

10. `nmer_enrichment_over_shuffled` Measure the enrichment of Nmers within
  the reads over shuffled reads.

11. `nucleotide_composition` Measure the nucleotide composition along
  reads.

12. `conservation_distribution` Measure the number of reads at each
  conservation level.

### Running analysis on subsets of data

Since `clipseqtools` relies on database tables, the filtering and run of an
analysis on subsets of data is particularly straightforward. The only thing a
user has to do is give the filtering criteria when executing each of the
commands. The syntax for the filtering criteria is easy and intuitive and
probably best explained with an example.

Example:

To run an analysis only on reads that are highly conserved, have a deletion
and are not repeats, the following flags should be added when running a
command:

    --filter conservation=">500" --filter deletion="def" --filter rmsk="undef"

The supported operators for creating a filter are: `>, >=, <, <=, =, !=,
def, undef`.

## C) clipseqtools-compare

datasets with each other.

### Supported commands

`clipseqtools-compare` supports the following commands which can run
independently.

1. `all` - Will run all of the commands as a pipeline. This is probably the
most common option to use unless you need very fine-grained control on what is
happening.

2. `libraries_overlap_stats` - Count the reads of library A that overlap those
of **reference** library B.

3. `libraries_relative_read_density` - Measure the density of reads of library
A around the reads of a reference library B.

4. `compare_counts` - Do Upper Quartile normalization upon specified columns
(containing counts) of tables.

    **Note:** This command when called by the `all` command will compare the
    counts for genes, transcripts, exons and introns.

## D) clipseqtools-plot

`clipseqtools-plot` is an application that can be used to create figures from
the output of `clipseqtools` and `clipseqtools-compare`.

**NOTE:** Usually you don't need to run any of these commands because they are
automatically called from the corresponding `clipseqtools` or
`clipseqtools-compare` commands when the `--plot` flag is given.

### Supported commands

`clipseqtools-plot` supports the following commands which run independently.

1. `cluster_size_and_score_distribution` - Create plots for script
cluster\_size\_and\_score\_distribution.

2. `distribution_on_genic_elements` - Create plots for script
distribution\_on\_genic\_elements.

3. `distribution_on_introns_exons` - Create plots for script
distribution\_on\_introns\_exons.

4. `genomic_distribution` - Create plots for script genomic\_distribution.

5. `libraries_relative_read_density` - Create plots for script
libraries\_relative\_read\_density.

6. `nucleotide_composition` - Create plots for script nucleotide\_composition.

7. `reads_long_gaps_size_distribution` - Create plots for script
reads\_long\_gaps\_size\_distribution.

8. `size_distribution` - Create plots for script size\_distribution.

# Need More Details?

The most up-to-date information regarding any of the toolboxes and the
commands can be found in the application itself. To find more information for
a particular toolbox, just run the toolbox invoking the `help` command.
Alternativelly if you want to see the full manual you can invoke the `man`
command.

Example:

    clipseqtools help
    clipseqtools man

If you want to get information for a particular command then execute the
command with the `--help` flag. Alternativelly if you want to see the full
manual you can invoke the `man` command followed by the command name.

Example:

    clipseqtools genome_coverage --helpcommands
    clipseqtools man genome_coverage
