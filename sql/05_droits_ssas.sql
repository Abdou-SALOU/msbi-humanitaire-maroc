/* =====================================================================
   05 - Autoriser SSAS (Analysis Services) à LIRE le Data Warehouse
   Sans ça, le traitement du cube échoue avec « Échec de la connexion
   de l'utilisateur NT Service\MSSQLServerOLAPService ».
   SSAS lit le DW avec le compte de son service Windows.
   À lancer une fois sur chaque PC (dans SSMS, en administrateur SQL).
   ===================================================================== */
USE master;
IF SUSER_ID(N'NT Service\MSSQLServerOLAPService') IS NULL
    CREATE LOGIN [NT Service\MSSQLServerOLAPService] FROM WINDOWS;
GO
USE DW_Humanitaire_Maroc;
IF USER_ID(N'NT Service\MSSQLServerOLAPService') IS NULL
    CREATE USER [NT Service\MSSQLServerOLAPService] FOR LOGIN [NT Service\MSSQLServerOLAPService];
ALTER ROLE db_datareader ADD MEMBER [NT Service\MSSQLServerOLAPService];
GO
PRINT N'SSAS peut maintenant lire DW_Humanitaire_Maroc (lecture seule).';
