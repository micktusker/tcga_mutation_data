# This script writes the directory paths and their mutation files that were down loaded by script "download_mutation_data.R"
# to an SQLite database. It populates two tables, one for parent directories, the other for the muttation files
# in those directories. The directories and mutaion files tables use the directory ID (MD5 hash of the full path to 
# link the tables.

# Steps:
# Connect to an SQLite database
# Open a transaction
# Loop over all the directories in the parent directory used by script "download_mutation_data.R"
# Create an MD5 hash key of the directory name to be used as a database primary key.
# Extract the TCGA cancer code using a regular expression.
# Get a list of the files in each sub-directory.
# Extract the TCGA subject ID from the file name.
# Calculate an MD5 hash key for the file name (full path) to be used as a primary key for a second table.
# Execute two INSERT SQL statements to load the directory and mutation file details.
# Commit and disconnect.

# Usage:
# Expects the database to exist with the target tables already present.
# Change the variable DB_NAME if the script is to use a different database but make sure it contains the target tables.

library(DBI)
library(digest)
DB_NAME <- 'tcga_mutation_test.db'
parent.dir <- '~/TCGA/tcga_mutation_data'
subdir.paths <- list.dirs(path = parent.dir, full.names = TRUE, recursive = TRUE)
db.path <- file.path(parent.dir, DB_NAME)
drv <- dbDriver("SQLite")
sqlite.conn <- dbConnect(drv, db.path)
dbBegin(sqlite.conn)
for (my.dir in subdir.paths) {
  directory.id <- digest(object = my.dir, algo = 'md5')
  tcga.code <- gsub("[^A-Z]", "", regmatches(my.dir, gregexpr("[._][A-Z]{2,}[._]", my.dir)))
  insert.dirs <- "INSERT INTO directories(directory_id, directory_path, tcga_code) VALUES(:directory_id, :directory_path, :tcga_code)"
  insert.files <- "INSERT INTO mutation_files(mutation_file_id, directory_id, file_path, subject_id) VALUES(:mutation_file_id, :directory_id, :file_path, :subject_id)"
  mutation.files <- list.files(my.dir, full.names = TRUE)
  qry1 <- dbSendStatement(conn = sqlite.conn, insert.dirs)
  dbBind(qry1, params = list(directory_id = directory.id, directory_path = my.dir, tcga_code = tcga.code))
  dbClearResult(qry1)
  for (my.file in mutation.files) {
    mutation.file.id <- digest(object = my.file, algo = 'md5')
    if(!grepl("maf\\.txt$", my.file)) {
      next
    }
    subject.id <- sub('.hg19.oncotator.hugo_entrez_remapped.maf.txt', '', basename(my.file))
    qry2 <- dbSendStatement(conn = sqlite.conn, insert.files)
    dbBind(qry2, params = list(mutation_file_id = mutation.file.id, directory_id = directory.id, file_path = my.file, subject_id = subject.id))
    dbClearResult(qry2)
  }
}

dbCommit(sqlite.conn)
dbDisconnect(sqlite.conn)