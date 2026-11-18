/* =====================================================================
   04 - Vider les tables chargées par SSIS (avant un rechargement complet)
   Utilisé par la 1re tâche « Exécuter SQL » du package 00_Master.dtsx.
   Ordre obligatoire : les faits d'abord (ils pointent vers les dimensions).
   Les dimensions fixes (D_Date, D_Milieu, D_GroupePopulation, D_TypeEvenement)
   ne sont pas touchées : elles viennent de 02_remplir_dimensions_fixes.sql.
   ===================================================================== */
USE DW_Humanitaire_Maroc;
TRUNCATE TABLE dbo.F_Refugies;
TRUNCATE TABLE dbo.F_Conflits;
TRUNCATE TABLE dbo.F_Pluie;
TRUNCATE TABLE dbo.F_Indicateurs_Region;
TRUNCATE TABLE dbo.F_Pauvrete;
-- TRUNCATE est interdit sur une table référencée par une clé étrangère : DELETE
DELETE FROM dbo.D_Region;
DELETE FROM dbo.D_Pays;
