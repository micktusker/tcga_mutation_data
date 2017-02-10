# Concatenate all the upload files into one long, slimmed file for upload into SQLite.
# Steps
# Get the file paths from the SQLitre database.
# Process each file by removing first four lines and selecting first 19 columns.
# Create a primary key column and prepend it to the 19 selected columns
# Write the 20 columns to a tab-delimited file.
# Execute a system command to load this file into the SQLite table.
# Create indexes on the table.

# Links:
# https://www.tutorialspoint.com/sqlite/sqlite_vacuum.htm
# http://stackoverflow.com/questions/11965515/how-to-define-a-vectorized-function-in-r
# https://nsaunders.wordpress.com/2010/08/20/a-brief-introduction-to-apply-in-r/
# http://stackoverflow.com/questions/6627235/sqlite-import-tab-file-is-import-doing-one-insert-per-row-or-grouping-them-wit
# http://cran.fhcrc.org/web/packages/RSQLite/vignettes/RSQLite.html Read this one especially

library(RSQLite)
library(digest)

# Extract required elements and return them as a tab-delimited string.
make.line.to.print <- function(element) {
  lsplit <- strsplit(element, "\t", fixed = TRUE)
  vsplit <- unlist(lsplit)
  vsplit.slim <- vsplit[1:19]
  return(paste0(vsplit.slim, sep = "\t", collapse = ''))
}
parent.dir <- '~/TCGA/tcga_mutation_data'
db.path <- file.path(parent.dir, 'tcga_mutation.db')
drv <- dbDriver("SQLite")
sqlite.conn <- dbConnect(drv, db.path)
sql = 'SELECT mutation_file_id, file_path FROM mutation_files'
file.out.path <- file.path(parent.dir, 'mutation_file_for_sqlite.tsv')
file.out.con <- file(file.out.path, "w")
rows <- dbGetQuery(sqlite.conn, sql)
mutation.file.ids <- rows$mutation_file_id
mutation.file.paths <- rows$file_path
file.id.idx <- 1
for (mutation.file.path in mutation.file.paths) {
  lines <- readLines(mutation.file.path)
  lines.body <- lines[-c(1, 1, 2, 3, 4)]
  mutation.file.id <- mutation.file.ids[file.id.idx]
  for (line.out in lines.body) {
    line.out.to.print <- trimws(paste0(c(mutation.file.id, make.line.to.print(line.out)), sep = "\t", collapse = ''), "both")
    writeLines(line.out.to.print,file.out.con)
  }
  file.id.idx <- file.id.idx + 1
}

close(file.out.con)
dbDisconnect(sqlite.conn)