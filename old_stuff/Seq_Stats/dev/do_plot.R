# if(require("getopt", quietly=TRUE)) {
# 	opt <- getopt(matrix(c(
# 		'ifiletotal', 'i', 1, "character", "inputfile",
# 		'ifilestart', 'j', 1, "character", "inputfile2",
# 		'ifileend', 'k', 1, "character", "inputfile3",
# 		'figfile', 'a', 1, "character", "plot"
# 	), ncol=5, byrow=TRUE))
# 	if(!is.null(opt$ifiletotal)) {
# 		ifiletotal <- opt$ifiletotal
# 		ifilestart <- opt$ifilestart
# 		ifileend <- opt$ifileend
# 		figfile <- opt$figfile
# 	}
# }
# 
# pdf(figfile, width = 7, height = 7)
# 
# idatatotal = read.delim(ifiletotal)
# idatatotal$records_with_length = idatatotal$A + idatatotal$C + idatatotal$G + idatatotal$T + idatatotal$N
# idatatotal$A_composition = idatatotal$A/idatatotal$records_with_length
# idatatotal$C_composition = idatatotal$C/idatatotal$records_with_length
# idatatotal$G_composition = idatatotal$G/idatatotal$records_with_length
# idatatotal$T_composition = idatatotal$T/idatatotal$records_with_length
# idatatotal.nt_position_groups = levels(as.factor(idatatotal$length))
# for(nucl_pos in as.integer(idatatotal.nt_position_groups)) {
# 	selected = (idatatotal$length == nucl_pos)
# 	plot( idatatotal$length[selected], idatatotal$A_composition[selected], type="o")
# 
# }
# 
# 
# idatastart = read.delim(ifilestart)
# idataend = read.delim(ifileend)
# 
# dev.off()
