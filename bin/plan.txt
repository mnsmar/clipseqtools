Analyses:

*** 1 sample

counts
	
	genomic element totals (repeats, genes, noncoding etc) --- DONE --- count_tags_per_genic_element.pl
	introns/exons  					       --- DONE --- count_tags_per_genic_element.pl
	genes/transcripts (total / exons) 		       --- DONE --- count_tags_per_genic_element.pl
		normalization (quartile, rpkm)		       --- DONE --- normalize_tables_with_UQ.pl
	UTR,CDS (total / exons) 			       --- DONE --- count_tags_per_genic_element.pl

	notes: maybe we can add the option to filter by a list of genes/transcripts

location

	on exons (bins)					       --- _MNS --- distribution_on_genic_parts.pl
	on genes (bins)					       --- ???? --- 
	on elements / locations (arbirtrary bed file)	       --- ???? ---
	genome coverage					       --- _MNS --- genome_coverage.pl

sequence

	number of Nmers on sequence		      	       --- ???? --- 
	number of Nmers on sequence (on genes / exons etc)     --- ???? --- 
	filter tags containing Nmer (list of Nmers)            --- ???? --- 

*** 2 samples

counts

	compare per genomic element
	...


location

	compare loc on exons
	...

sequence

	Nmer comparison
	Nmer (genes / exons etc) comparison
	

-----------------------------------------------

Issues:

* simplify input (driver, host etc) since we know which db will be used
* standardize flags
* speed
* using NO custom files
* using as FEW external files (gtf etc)