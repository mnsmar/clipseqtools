if(require("getopt", quietly=TRUE)) {
	opt <- getopt(matrix(c(
		'ifile', 'i', 1, "character", "inputfile",
		'figfile', 'a', 1, "character", "plot"
	), ncol=5, byrow=TRUE))
	if(!is.null(opt$ifile)) {
		ifile <- opt$ifile
		figfile <- opt$figfile
	}
}

idata = read.delim(ifile)
pdf(figfile, width = 7, height = 7)
	barplot( idata$counts, names.arg= idata$index, col=c("white"), ylab="Number of Reads", xlab="Index" )
	pie(idata$counts, labels= idata$index, main="Number of Reads per Index")
#	pie(idata$counts, labels= idata$index, main="Number of Reads per Index", col=c("white")) #white pie chart
dev.off()