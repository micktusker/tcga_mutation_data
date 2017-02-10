library(RSQLite)
library(digest)
parent.dir <- '~/TCGA/tcga_mutation_data'
subdir.paths <- list.dirs(path = parent.dir, full.names = TRUE, recursive = TRUE)
db.path <- file.path(parent.dir, 'tcga_mutation.db')
drv <- dbDriver("SQLite")
sqlite.conn <- dbConnect(drv, db.path)
dbBegin(sqlite.conn)
for (my.dir in subdir.paths) {
  directory.id <- digest(object = my.dir, algo = 'md5')
  tcga.code <- gsub("[^A-Z]", "", regmatches(my.dir, gregexpr("[._][A-Z]{2,}[._]", my.dir)))
  insert.dirs <- "INSERT INTO directories(directory_id, directory_path, tcga_code) VALUES('%s', '%s', '%s')"
  insert.files <- "INSERT INTO mutation_files(mutation_file_id, directory_id, file_path, subject_id) VALUES('%s', '%s', '%s', '%s')"
  mutation.files <- list.files(my.dir, full.names = TRUE)
  qry1 <- dbSendQuery(conn = sqlite.conn, sprintf(insert.dirs, directory.id, my.dir, tcga.code))
  dbClearResult(qry1)
  for (my.file in mutation.files) {
    mutation.file.id <- digest(object = my.file, algo = 'md5')
    if(!grepl("maf\\.txt$", my.file)) {
      next
    }
    subject.id <- sub('.hg19.oncotator.hugo_entrez_remapped.maf.txt', '', basename(my.file))
    qry2 <- dbSendQuery(conn = sqlite.conn, sprintf(insert.files, mutation.file.id, directory.id, my.file, subject.id))
    dbClearResult(qry2)
  }
}

dbCommit(sqlite.conn)
dbDisconnect(sqlite.conn)