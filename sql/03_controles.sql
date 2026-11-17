/* =====================================================================
   03 - Contrôles après chargement SSIS
   Chaque ligne compare ce qui est dans le DW à ce qu'on attend des
   fichiers sources (valeurs calculées sur les CSV le 17/11/2026).
   Colonne « ok » = 1 si tout va bien. Une ligne à 0 = package à revoir.
   ===================================================================== */
USE DW_Humanitaire_Maroc;
GO

WITH controles AS (
    SELECT 'D_Region : nb lignes'                 AS controle, CAST(COUNT(*) AS DECIMAL(18,2)) AS dans_dw, 12        AS attendu FROM dbo.D_Region
    UNION ALL SELECT 'D_Pays : nb lignes',                COUNT(*),                   191      FROM dbo.D_Pays
    UNION ALL SELECT 'F_Refugies : nb lignes',            COUNT(*),                   2694     FROM dbo.F_Refugies
    UNION ALL SELECT 'F_Refugies : total personnes',      SUM(nb_personnes),          424489   FROM dbo.F_Refugies
    UNION ALL SELECT 'F_Conflits : nb lignes',            COUNT(*),                   1074     FROM dbo.F_Conflits
    UNION ALL SELECT 'F_Conflits : total evenements',     SUM(nb_evenements),         16872    FROM dbo.F_Conflits
    UNION ALL SELECT 'F_Conflits : total morts',          SUM(nb_morts),              569      FROM dbo.F_Conflits
    UNION ALL SELECT 'F_Pluie : nb lignes (decades)',     COUNT(*),                   2610     FROM dbo.F_Pluie
    UNION ALL SELECT 'F_Pluie : total pixels',            SUM(nb_pixels),             2752854  FROM dbo.F_Pluie
    UNION ALL SELECT 'F_Pluie : lignes provisoires',      SUM(CAST(est_provisoire AS INT)), 45 FROM dbo.F_Pluie
    UNION ALL SELECT 'F_Indicateurs : nb lignes',         COUNT(*),                   24       FROM dbo.F_Indicateurs_Region
    UNION ALL SELECT 'F_Indicateurs : population',        SUM(population_legale),     36828330 FROM dbo.F_Indicateurs_Region
    UNION ALL SELECT 'F_Indicateurs : etrangers',         SUM(population_etrangere),  148152   FROM dbo.F_Indicateurs_Region
    UNION ALL SELECT 'F_Pauvrete : nb lignes',            COUNT(*),                   72       FROM dbo.F_Pauvrete
)
SELECT controle, dans_dw, attendu,
       CASE WHEN dans_dw = attendu THEN 1 ELSE 0 END AS ok
FROM controles;

-- Chômeurs : calculés à partir de taux arrondis à 0,1 point, donc écart faible normal.
-- Attendu ~2 373 842 (taux national officiel 21,3 % de 11 137 688 actifs = 2 372 327).
SELECT SUM(nb_chomeurs) AS nb_chomeurs,
       CAST(100.0 * SUM(nb_chomeurs) / SUM(population_active_15_plus) AS DECIMAL(5,1)) AS taux_chomage_recalcule
FROM dbo.F_Indicateurs_Region;

-- Clés orphelines : doit renvoyer 0 partout (sinon un Lookup SSIS a échoué)
SELECT 'F_Pluie sans region'   AS controle, COUNT(*) AS lignes FROM dbo.F_Pluie p LEFT JOIN dbo.D_Region r ON r.region_key = p.region_key WHERE r.region_key IS NULL
UNION ALL
SELECT 'F_Refugies sans pays', COUNT(*) FROM dbo.F_Refugies f LEFT JOIN dbo.D_Pays o ON o.pays_key = f.pays_origine_key WHERE o.pays_key IS NULL;

-- Vérification de bon sens : population 2024 par région (Casablanca-Settat doit être 1re, 7 688 967)
SELECT r.nom_region, SUM(f.population_legale) AS population_2024
FROM dbo.F_Indicateurs_Region f JOIN dbo.D_Region r ON r.region_key = f.region_key
GROUP BY r.nom_region
ORDER BY population_2024 DESC;
