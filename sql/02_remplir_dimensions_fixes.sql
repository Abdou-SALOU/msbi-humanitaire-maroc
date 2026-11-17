/* =====================================================================
   02 - Remplissage des dimensions fixes (qui ne viennent d'aucun fichier)
   D_Date (1997-2026), D_Milieu, D_GroupePopulation, D_TypeEvenement.
   D_Region et D_Pays sont chargées par SSIS.
   ===================================================================== */
USE DW_Humanitaire_Maroc;
GO
SET LANGUAGE French;   -- pour les noms de mois en français
GO

DELETE FROM dbo.D_Date;
DECLARE @d DATE = '1997-01-01';
WHILE @d <= '2026-12-31'
BEGIN
    INSERT INTO dbo.D_Date
    VALUES (
        CONVERT(INT, FORMAT(@d, 'yyyyMMdd')),
        @d,
        YEAR(@d),
        CASE WHEN MONTH(@d) <= 6 THEN 1 ELSE 2 END,
        DATEPART(QUARTER, @d),
        MONTH(@d),
        DATENAME(MONTH, @d),
        CASE WHEN DAY(@d) <= 10 THEN 1 WHEN DAY(@d) <= 20 THEN 2 ELSE 3 END,
        DAY(@d)
    );
    SET @d = DATEADD(DAY, 1, @d);
END;

DELETE FROM dbo.D_Milieu;
INSERT INTO dbo.D_Milieu VALUES (1, N'Ensemble'), (2, N'Urbain'), (3, N'Rural');

DELETE FROM dbo.D_GroupePopulation;
INSERT INTO dbo.D_GroupePopulation VALUES
    (1, 'REF', N'Réfugiés'),
    (2, 'ASY', N'Demandeurs d''asile'),
    (3, 'OOC', N'Autres personnes relevant du HCR');

DELETE FROM dbo.D_TypeEvenement;
INSERT INTO dbo.D_TypeEvenement VALUES
    (1, 'political_violence', N'Violence politique'),
    (2, 'civilian_targeting', N'Violence contre les civils'),
    (3, 'demonstration',      N'Manifestations');
GO

SELECT 'D_Date' AS dimension, COUNT(*) AS lignes FROM dbo.D_Date
UNION ALL SELECT 'D_Milieu', COUNT(*) FROM dbo.D_Milieu
UNION ALL SELECT 'D_GroupePopulation', COUNT(*) FROM dbo.D_GroupePopulation
UNION ALL SELECT 'D_TypeEvenement', COUNT(*) FROM dbo.D_TypeEvenement;
