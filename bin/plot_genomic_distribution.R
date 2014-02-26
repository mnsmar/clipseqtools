#!/usr/bin/Rscript

library(plotrix)
library(RColorBrewer)

## Get options
if(require("getopt", quietly=TRUE)) {
	opt <- getopt(matrix(c(
		'ifile', 'i', 1, "character", "input table file",
		'figfile', 'f', 1, "character", "figure file"
	), ncol=5, byrow=TRUE))
	
	ifile <- opt$ifile
	figfile <- opt$figfile
}

## Prepare palette
mypalette<-brewer.pal(4, "RdYlBu")


## Read data
idata = read.delim(ifile)

## Calculate percent
idata$percent = (idata$count / idata$total) * 100

## Create a barplot
pdf(figfile, width=14, height=7);
par(mfrow = c(1, 2), mar=c(9.5, 4.1, 4.1, 2.1));
barp(height=idata$percent, names.arg=idata$category, col=c(rep("black",2), rep("darkgrey",3), rep("grey",3), rep("lightgrey",3), rep("lightblue",3)), staxx=TRUE, srt=45, ylim=c(0,100), ylab="Percent of total reads");
barp(height=idata$count, names.arg=idata$category, col=c(rep("black",2), rep("darkgrey",3), rep("grey",3), rep("lightgrey",3), rep("lightblue",3)), staxx=TRUE, srt=45, ylab="Number of reads");
dev.off();
