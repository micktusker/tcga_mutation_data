CREATE TABLE directories(
  directory_id TEXT PRIMARY KEY, 
  directory_path TEXT, 
  tcga_code TEXT);

CREATE TABLE mutation_files(
  mutation_file_id TEXT PRIMARY KEY, 
  directory_id TEXT, file_path TEXT, 
  subject_id TEXT, 
  FOREIGN KEY(directory_id) REFERENCES directories(directory_id));
  
CREATE TABLE subject_mutations( subject_mutation_id INTEGER PRIMARY KEY,
 mutation_file_id TEXT,
 hugo_symbol TEXT,
 entrez_gene_id INTEGER,
 ncbi_build INTEGER,
 chromosome TEXT,
 start_position INTEGER,
 end_position INTEGER,
 variant_classification TEXT,
 variant_type TEXT,
 reference_allele TEXT,
 tumor_seq_allele1 TEXT,
 tumor_seq_allele2 TEXT,
 dbsnp_rs TEXT,
 tumor_sample_barcode TEXT,
 matched_norm_sample_barcode TEXT,
 FOREIGN KEY(mutation_file_id) REFERENCES mutation_files(mutation_file_id));
 