parent.dir.for.download <- '~/TCGA/tcga_mutation_data'
url.tmpl <- 'http://gdac.broadinstitute.org/runs/stddata__2016_01_28/data/%s/20160128/gdac.broadinstitute.org_%s.Mutation_Packager_Oncotated_Calls.Level_3.2016012800.0.0.tar.gz'
for (tcga.code in c('ACC','BLCA','BRCA','CESC','CHOL','COAD','COADREAD','DLBC','ESCA','GBM','GBMLGG','HNSC','KICH','KIPAN','KIRC','LAML','LGG','LIHC','LUAD','LUSC','MESO','OV','PAAD','PCPG','PRAD','READ','SARC','SKCM','STAD','STES','TGCT','THCA','THYM','UCEC','UCS','UVM'
)) {
  url.target.file <- sprintf(url.tmpl, tcga.code, tcga.code)
  dest.file <- file.path(parent.dir.for.download, basename(url.target.file))
  if(file.exists(dest.file)) {
    next
  }
  try({
    download.file(url = url.target.file, destfile = dest.file, quiet = TRUE)
    untar(dest.file, exdir = dirname(dest.file))
  })
}


