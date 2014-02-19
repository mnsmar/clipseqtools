#!/bin/bash

# Export used perl libraries
export PERL5LIB=$PERL5LIB:/home/mns/mylib/perl/workspace/v0.1.1/GenOO/ 

bin/count_tags_per_genic_element.pl -dev -database test_data/alignments.db -table sample -gtf /store/data/UCSC/hg19/annotation/UCSC_gene_parts.gtf -transcript_to_gene_file /store/data/UCSC/hg19/annotation/names.txt -ofile_prefix foo/counts_per_genic_element