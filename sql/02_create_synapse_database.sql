/*==============================================================================
  02_create_synapse_database.sql
  Target : Azure Synapse Analytics SERVERLESS SQL pool (built-in endpoint)
  Purpose: Creates the 'udacity' database.
  Run    : Step 1 connected to 'master'. Then switch the Synapse Studio
           "Use database" dropdown to 'udacity' for the next script.
  Rerun  : Safe (existence check).
  Notes  : No dedicated SQL pool is used or required.

  AUTHENTICATION MODEL (no secrets in this repository)
  ----------------------------------------------------
  The external data source in 03_create_synapse_external_objects.sql has NO
  credential, so serverless SQL reads ADLS using the identity of the signed-in
  Microsoft Entra user (user pass-through). Requirement: that user holds
  "Storage Blob Data Reader/Contributor/Owner" on the storage account
  (the lab user already has Storage Blob Data Owner).

  OPTIONAL ALTERNATIVES (only if pass-through does not work):
  a) Workspace managed identity: grant it "Storage Blob Data Reader" on the
     storage account, then in database udacity create:
       CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<MASTER_KEY_PASSWORD>';  -- type it yourself, never commit
       CREATE DATABASE SCOPED CREDENTIAL cred_nycpayroll_adls WITH IDENTITY = 'Managed Identity';
     and add CREDENTIAL = cred_nycpayroll_adls to the external data source.
  b) SAS token (placeholder only; never commit the real token):
       CREATE DATABASE SCOPED CREDENTIAL cred_nycpayroll_adls
       WITH IDENTITY = 'SHARED ACCESS SIGNATURE', SECRET = '<SAS_TOKEN_WITHOUT_LEADING_QUESTION_MARK>';
==============================================================================*/

-- Step 1 (connected to: master) ---------------------------------------------
IF DB_ID(N'udacity') IS NULL
    CREATE DATABASE udacity COLLATE Latin1_General_100_BIN2_UTF8;
GO

-- Verification (any database) ------------------------------------------------
SELECT name, collation_name FROM sys.databases WHERE name = N'udacity';
