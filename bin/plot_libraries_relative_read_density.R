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


## Convert values to density
idata$norm_counts_with_copy_number_sense     = idata$counts_with_copy_number_sense    / sum(as.numeric(idata$counts_with_copy_number_sense))
idata$norm_counts_no_copy_number_sense       = idata$counts_no_copy_number_sense      / sum(as.numeric(idata$counts_no_copy_number_sense))
idata$norm_counts_with_copy_number_antisense = idata$counts_with_copy_number_antisense/ sum(as.numeric(idata$counts_with_copy_number_antisense))
idata$norm_counts_no_copy_number_antisense   = idata$counts_no_copy_number_antisense  / sum(as.numeric(idata$counts_no_copy_number_antisense))

ylimit = max(idata$norm_counts_with_copy_number_sense, idata$norm_counts_no_copy_number_sense, idata$norm_counts_with_copy_number_antisense, idata$norm_counts_no_copy_number_antisense)


## Plot
pdf(figfile, width=28)
par(mfrow = c(1, 4), cex.lab=1.8, cex.axis=1.7, cex.main=2, lwd=1.5, oma=c(0, 0, 2, 0), mar=c(5.1, 5.1, 4.1, 3.1))

plot(idata$relative_position, idata$norm_counts_with_copy_number_sense, type="o", main="Sense records (with copy number)", xlab="Relative position", ylab="Density", col=mypalette[1], ylim=c(0,ylimit))
abline(v=0, lty=2, col="grey", lwd=1.5)
plot(idata$relative_position, idata$norm_counts_no_copy_number_sense, type="o", main="Sense records (no copy number)", xlab="Relative position", ylab="Density", col=mypalette[2], ylim=c(0,ylimit))
abline(v=0, lty=2, col="grey", lwd=1.5)
plot(idata$relative_position, idata$norm_counts_with_copy_number_antisense, type="o", main="Anti-sense records (with copy number)", xlab="Relative position", ylab="Density", col=mypalette[3], ylim=c(0,ylimit))
abline(v=0, lty=2, col="grey", lwd=1.5)
plot(idata$relative_position, idata$norm_counts_no_copy_number_antisense, type="o", main="Anti-sense records (no copy number)", xlab="Relative position", ylab="Density", col=mypalette[4], ylim=c(0,ylimit))
abline(v=0, lty=2, col="grey", lwd=1.5)

mtext(figfile, outer = TRUE, cex = 1.5)
dev.off()
