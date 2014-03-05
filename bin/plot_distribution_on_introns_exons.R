#!/usr/bin/env Rscript

library(RColorBrewer)

## Get options
if(require("getopt", quietly=TRUE)) {
	opt <- getopt(matrix(c(
		'ifile', 'i', 1, "character", "input table file",
		'figfile', 'f', 1, "character", "figure file"
	), ncol=5, byrow=TRUE))
	if(!is.null(opt$ifile)) {
		ifile <- opt$ifile
		figfile <- opt$figfile
	}
}

## Prepare palette
mypalette<-brewer.pal(4, "RdYlBu")


## Read data
idata = read.delim(ifile)


## Plot using vector graphics.
pdf(figfile, width=14)
par(mfrow = c(1, 2), cex.lab=1.5, cex.axis=1.5, cex.main=1.5, lwd=1.5, oma=c(0, 0, 2, 0), mar=c(5.1, 5.1, 4.1, 3.1))
plot(idata$bin[idata$element == 'exon'], idata$avg_rpkm[idata$element   == 'exon'], type="b", ylim=c(0, max(idata$avg_rpkm)),   col=mypalette[1], main="Exon", xlab="Bin", ylab="Average RPKM")
plot(idata$bin[idata$element == 'intron'],  idata$avg_rpkm[idata$element   == 'intron'],  type="b", ylim=c(0, max(idata$avg_rpkm)),   col=mypalette[2], main="Intron",   xlab="Bin", ylab="Average RPKM")
plot(idata$bin[idata$element == 'exon'], idata$avg_counts[idata$element == 'exon'], type="b", ylim=c(0, max(idata$avg_counts)), col=mypalette[1], main="Exon", xlab="Bin", ylab="Average number of reads")
plot(idata$bin[idata$element == 'intron'],  idata$avg_counts[idata$element == 'intron'],  type="b", ylim=c(0, max(idata$avg_counts)), col=mypalette[2], main="Intron",   xlab="Bin", ylab="Average number of reads")
dev.off()
