# Analyses


## Per library

* DONE - Distribution on genic elements (5'UTR, CDS, 3'UTR, Introns, Exons)
* DONE - Genome coverage (percent of genome covered by library)
* DONE - Genomic distribution (percent of reads on genomic elements - 5'UTR, CDS, Exons, Repeats, etc)
* DONE - Count reads on genic elements (Genes, Transcripts, 5'UTR, CDS, 3'UTR, Introns, Exons)
* DONE - Normalize counts with Upper Quartile

* ???? - location -> on exons (bins)  --- _MNS --- distribution_on_genic_parts.pl
* ???? - location -> on genes (bins)  --- ???? --- 
* ???? - location -> on elements / locations (arbirtrary bed file) --- ???? ---

* TODO - sequence -> number of Nmers on sequence                         --- ???? --- 
* TODO - sequence -> number of Nmers on sequence (on genes / exons etc)  --- ???? --- 
* TODO - sequence -> filter tags containing Nmer (list of Nmers)         --- ???? --- 

## Compare libraries

* DONE - Percent of overlap between two libraries.
* DONE - Read density of one library around the reads of another.
* TODO - counts -> compare per genomic element
* ???? - location -> compare loc on exons
* TODO - sequence -> Nmer comparison
* TODO - sequence -> Nmer (genes / exons etc) comparison


# Issues:

* DONE - simplify input (driver, host etc) since we know which db will be used
* DONE - standardize flags
* TO?? - speed
* TODO - use no custom files
* TODO - minimize external files usage (gtf etc)