# Data management

## Database import
* DONE - Import SAM to database

## Annotation
* DONE - Annotate with transcript/genic info
* DONE - Annotate with RMSK
* DONE - Annotate with deletions
* TODO - Annotate with T->C mutations


# Analyses

## Per library
* DONE - Distribution on genic elements (5'UTR, CDS, 3'UTR, Introns, Exons)
* DONE - Genome coverage (percent of genome covered by library)
* DONE - Genomic distribution (percent of reads on genomic elements - 5'UTR, CDS, Exons, Repeats, etc)
* DONE - Count reads on genic elements (Genes, Transcripts, 5'UTR, CDS, 3'UTR, Introns, Exons)
* DONE - Normalize counts with Upper Quartile
* DONE - Nmer counts and enrichment
* DONE - Cluster size distribution
* DONE - Intron (Ns in reads) size distribution
* DONE - Size distribution
* DONE - Nucleotide composition

* TODO - Cluster characterization
* TODO - location -> on elements / locations (arbirtrary bed file)

## Compare libraries
* DONE - Percent of overlap between two libraries.
* DONE - Read density of one library around the reads of another.
* TODO - counts -> compare per genomic element

# Issues:
* simplify input (driver, host etc) since we know which db will be used
* standardize flags
* speed
* use no custom files
* minimize external files usage (gtf etc)