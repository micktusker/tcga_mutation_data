# Defines a function that transfers a table from SQLite to PostgreSQL via an R data frame.
# 
# Steps:
# Connect to SQLite and PostgreSQL
# Pass the SQLite and PostgreSQL connection and the SQLite table name to a function.
# Call the function then does the actual transfer.

# Assumes:
# The ssh tunnel is set up to the Tusk Redhat Pg database.

# This works surprisingly well and can transfer tables with >1.5M rows quite quickly.

# Issues: I have not found a way to transfer the tables to a specific PostgreSQL schema other than "public"
# Need to do the schema transfer in Postgres itself.
# The SQL to do this is: ALTER TABLE subject_mutations SET SCHEMA tcga_mutation_analysis;

library(DBI)
library(RSQLite)
library(RPostgreSQL)
SQLITE_DB_NAME<- 'tcga_mutation.db'
SQLITE_PARENT_DIR <- '~/TCGA/tcga_mutation_data'
SQLITE_DB_PATH <- file.path(SQLITE_PARENT_DIR, SQLITE_DB_NAME)
# PostgreSQL connection parameters

pg.host <- 'localhost'
pg.user <- 'micktusker'
pg.port <- 5433
pg.dbname <- 'cd38'
sqlite.drv <- dbDriver("SQLite")
sqlite.conn <- dbConnect(sqlite.drv, SQLITE_DB_PATH)
pg.drv <- dbDriver("PostgreSQL")
pg.conn <- dbConnect(pg.drv, user = pg.user, port = pg.port, host = pg.host, dbname = pg.dbname)

transfer.table <- function(table.name) {
  table.as.df <- dbReadTable(sqlite.conn, table.name)
  dbWriteTable(pg.conn, table.name, table.as.df, row.names=FALSE)
}
#transfer.table('directories')
#transfer.table('mutation_files')
transfer.table('subject_mutations')
dbDisconnect(sqlite.conn)
dbDisconnect(pg.conn)