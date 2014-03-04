#!/bin/bash

# Export used perl libraries
export PERL5LIB=$PERL5LIB:/home/mns/mylib/perl/workspace/v0.1.1/GenOO/ 


### FINISHED

# bin/count_tags_per_genic_element.pl -database test_data/alignments.db -table sample -gtf /store/data/UCSC/hg19/annotation/UCSC_gene_parts.gtf -transcript_to_gene_file /store/data/UCSC/hg19/annotation/names.txt -ofile_prefix foo/sample1_counts_per_genic_element &
# 
# bin/count_tags_per_genic_element.pl -database test_data/alignments2.db -table sample -gtf /store/data/UCSC/hg19/annotation/UCSC_gene_parts.gtf -transcript_to_gene_file /store/data/UCSC/hg19/annotation/names.txt -ofile_prefix foo/sample2_counts_per_genic_element &
# 
# wait

### TESTING


# bin/normalize_tables_with_UQ.pl -key transcript_id -key transcript_location -key transcript_length -key gene_name -key transcript_exonic_length -val transcript_exonic_count_per_nt -ifile foo/sample1_counts_per_genic_element.counts.transcript.tab -ifile foo/sample2_counts_per_genic_element.counts.transcript.tab -ofile foo/sample1_counts_per_genic_element.counts.transcript.uq.tab -ofile foo/sample2_counts_per_genic_element.counts.transcript.uq.tab

../bin/annotate_db_sample_with_deletions.pl -driver SQLite -database data/alignments.db -table sample