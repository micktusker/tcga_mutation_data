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
 
 -- PostgreSQL-specific additions:
 CREATE SCHEMA tcga_mutation_analysis;
COMMENT ON SCHEMA tcga_mutation_analysis IS 'Stores mutation data and analysis of this data downloaded from Firebrowse Feb. 2017';

ALTER TABLE subject_mutations SET SCHEMA tcga_mutation_analysis;

ALTER TABLE tcga_mutation_analysis.directories
ADD CONSTRAINT directories_pk PRIMARY KEY(directory_id);

ALTER TABLE tcga_mutation_analysis.mutation_files
ADD CONSTRAINT mutation_files_pk PRIMARY KEY(mutation_file_id);

ALTER TABLE tcga_mutation_analysis.subject_mutations
ADD CONSTRAINT subject_mutations_pk PRIMARY KEY(subject_mutation_id);

ALTER TABLE tcga_mutation_analysis.mutation_files
ADD CONSTRAINT dir_mutfile_fk FOREIGN KEY(directory_id) REFERENCES tcga_mutation_analysis.directories(directory_id);

ALTER TABLE tcga_mutation_analysis.subject_mutations
ADD CONSTRAINT muts_mutfile_fk FOREIGN KEY(mutation_file_id) REFERENCES tcga_mutation_analysis.mutation_files(mutation_file_id);

CREATE INDEX mutation_files_fk_idx ON tcga_mutation_analysis.mutation_files(directory_id);
CREATE INDEX mutation_files_subject_id_idx ON tcga_mutation_analysis.mutation_files(subject_id);
CREATE INDEX subject_mutations_hugo_symbol_idx ON tcga_mutation_analysis.subject_mutations(hugo_symbol);
CREATE INDEX subject_mutations_file_id_idx ON tcga_mutation_analysis.subject_mutations(mutation_file_id);

COMMENT ON TABLE tcga_mutation_analysis.directories  IS 'Lists the directories created by script download_mutation_data.R. The TCGA code is extracted from the directory name. Transferred from SQLite to Pg by script transfer_tables_sqlite_to_pg.R.';
COMMENT ON TABLE tcga_mutation_analysis.mutation_files  IS 'Lists the mutation files in each downloaded directory. Generated by script write_files_to_sqlite.R. Transferred from SQLite to Pg by script transfer_tables_sqlite_to_pg.R';
COMMENT ON TABLE tcga_mutation_analysis.subject_mutations  IS 'Lists the mutations contained in the mutation files stored in table mutation_files. File was generated by script create_mutation_upload_file.R. Transferred from SQLite to Pg by script transfer_tables_sqlite_to_pg.R';

-- Extracting the participant identifers from the expression and the mutation data to study effect of neo-antigens
--  on expression of selected genes.

-- mutation data participants
CREATE MATERIALIZED VIEW tcga_mutation_analysis.tcga_mutation_participants_processed AS
SELECT
  (STRING_TO_ARRAY(mf.subject_id, E'-'))[2] tissue_source_site,
  (STRING_TO_ARRAY(mf.subject_id, E'-'))[3] participant,
  (STRING_TO_ARRAY(mf.subject_id, E'-'))[4] sample_vial,
  dir.tcga_code,
  mf.mutation_file_id
FROM 
  tcga_mutation_analysis.mutation_files mf
  JOIN tcga_mutation_analysis.directories dir ON mf.directory_id = dir.directory_id;

COMMENT ON MATERIALIZED VIEW tcga_mutation_analysis.tcga_mutation_participants_processed IS 'In this view the subject identifiers are split into their individual parts to allow joining with other data types. To be used to match missense mutations with mRNA expression.';
CREATE INDEX tcga_mutation_participants_processed_pcpt_idx ON tcga_mutation_analysis.tcga_mutation_participants_processed (participant);

-- mRNA expression data participants
CREATE MATERIALIZED VIEW expression.tcga_mrna_participants_processed AS
SELECT
  samples.tcga_mrna_normalized_samples_id,
  samples.sample_index,
  (STRING_TO_ARRAY(samples.sample_id, E'-'))[2] tissue_source_site,
  (STRING_TO_ARRAY(samples.sample_id, E'-'))[3] participant,
  (STRING_TO_ARRAY(samples.sample_id, E'-'))[4] sample_vial,
  (STRING_TO_ARRAY(samples.sample_id, E'-'))[5] portion_analyte,
  (STRING_TO_ARRAY(samples.sample_id, E'-'))[6] plate,
  (STRING_TO_ARRAY(samples.sample_id, E'-'))[7] center,
  samples.file_code,
  lu.tcga_cancer_code
FROM
  expression.tcga_mrna_normalized_samples samples
  JOIN
    expression.tcga_file_cancer_code_lookup lu ON samples.file_code = lu.file_code
WHERE
  sample_index > 0;
  
COMMENT ON MATERIALIZED VIEW expression.tcga_mrna_participants_processed IS 'In this view the barcodes are split into their individual parts to allow joining with other data types. To be used to match missense mutations with mRNA expression.';
CREATE INDEX tcga_mrna_participants_processed_pcpt_idx ON expression.tcga_mrna_participants_processed(participant);

-- Get mRNA expression data for participant-gene-cancer combination.

CREATE OR REPLACE FUNCTION user_defined_functions.get_mrna_expression_for_participant_gene_cancer(p_participant TEXT, p_gene_name TEXT, p_tcga_cancer_code TEXT)
RETURNS REAL
AS
$$
DECLARE
  l_sample_index INTEGER;
  l_expression_value INTEGER;
BEGIN
  SELECT
    sample_index INTO l_sample_index
  FROM
    expression.tcga_mrna_participants_processed
  WHERE
    participant = p_participant
    AND
      tcga_cancer_code = p_tcga_cancer_code;
  SELECT
    tmnm.expression_values[l_sample_index] INTO l_expression_value
  FROM
    expression.tcga_mrna_normalized_matrices tmnm
    JOIN
      expression.tcga_file_cancer_code_lookup tcga_lu ON tmnm.file_code = tcga_lu.file_code
  WHERE
    tmnm.gene_name = p_gene_name
    AND
      tcga_lu.tcga_cancer_code = p_tcga_cancer_code;
  RETURN l_expression_value;
END;
$$
LANGUAGE plpgsql;
COMMENT ON FUNCTION user_defined_functions.get_mrna_expression_for_participant_gene_cancer(TEXT, TEXT, TEXT)
IS 'Given a participant name (in MV expression.tcga_mrna_participants_processed), an uppercase gene name that must appear in table "expression.tcga_mrna_normalized_matrices", and a recognized TCGA cancer code, return the indivual mRNA expression value for that combination of arguments. Example call: SELECT user_defined_functions.get_mrna_expression_for_participant_gene_cancer("A5JA", "CD38", "ACC")';

CREATE TABLE expression.tcga_participant_mrna_expr_vals(
  tcga_participant_mrna_expr_vals_id SERIAL PRIMARY KEY,
  participant TEXT,
  tcga_cancer_code TEXT,
  sample_index INTEGER,
  gene_name TEXT,
  expression_value REAL
);
COMMENT ON TABLE expression.tcga_participant_mrna_expr_vals IS
'Contains the indivual mRNA expression levels for a given gene-cancer combination. Used to investigate potential relationship between expression of specific genes (PD-1 and PD-L1 specifically) and the number of missense (potential neo-antigens) in that sample.';

INSERT INTO expression.tcga_participant_mrna_expr_vals(participant, tcga_cancer_code, sample_index, gene_name, expression_value)
SELECT
  participant,
  tcga_cancer_code,
  sample_index,
  'PDCD1'::TEXT gene_name,
  user_defined_functions.get_mrna_expression_for_participant_gene_cancer(participant, 'PDCD1', tcga_cancer_code) expression_value
FROM
  expression.tcga_mrna_participants_processed;




