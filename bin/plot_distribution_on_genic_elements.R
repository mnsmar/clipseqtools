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
pdf(figfile, width=21)
par(mfrow = c(1, 3), cex.lab=1.5, cex.axis=1.5, cex.main=1.5, lwd=1.5, oma=c(0, 0, 2, 0), mar=c(5.1, 5.1, 4.1, 3.1))
plot(idata$bin[idata$element == 'utr5'], idata$avg_rpkm[idata$element   == 'utr5'], type="b", ylim=c(0, max(idata$avg_rpkm)),   col=mypalette[1], main="5'UTR", xlab="Bin", ylab="Average RPKM")
plot(idata$bin[idata$element == 'cds'],  idata$avg_rpkm[idata$element   == 'cds'],  type="b", ylim=c(0, max(idata$avg_rpkm)),   col=mypalette[2], main="CDS",   xlab="Bin", ylab="Average RPKM")
plot(idata$bin[idata$element == 'utr3'], idata$avg_rpkm[idata$element   == 'utr3'], type="b", ylim=c(0, max(idata$avg_rpkm)),   col=mypalette[4], main="3'UTR", xlab="Bin", ylab="Average RPKM")
plot(idata$bin[idata$element == 'utr5'], idata$avg_counts[idata$element == 'utr5'], type="b", ylim=c(0, max(idata$avg_counts)), col=mypalette[1], main="5'UTR", xlab="Bin", ylab="Average number of reads")
plot(idata$bin[idata$element == 'cds'],  idata$avg_counts[idata$element == 'cds'],  type="b", ylim=c(0, max(idata$avg_counts)), col=mypalette[2], main="CDS",   xlab="Bin", ylab="Average number of reads")
plot(idata$bin[idata$element == 'utr3'], idata$avg_counts[idata$element == 'utr3'], type="b", ylim=c(0, max(idata$avg_counts)), col=mypalette[4], main="3'UTR", xlab="Bin", ylab="Average number of reads")
dev.off()
