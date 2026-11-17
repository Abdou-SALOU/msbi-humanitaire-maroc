/* =====================================================================
   Projet MSBI - Data Warehouse « Humanitaire Maroc »
   01 - Création de la base, des dimensions et des faits (constellation)

   À exécuter dans SSMS (ou sqlcmd). Le script peut être relancé :
   il supprime puis recrée toutes les tables (les données sont perdues,
   il suffit de relancer ensuite 02 puis les packages SSIS).
   ===================================================================== */

IF DB_ID(N'DW_Humanitaire_Maroc') IS NULL
    CREATE DATABASE DW_Humanitaire_Maroc;
GO
USE DW_Humanitaire_Maroc;
GO

/* ---------- Suppression (faits d'abord, puis dimensions) ---------- */
DROP TABLE IF EXISTS dbo.F_Refugies;
DROP TABLE IF EXISTS dbo.F_Conflits;
DROP TABLE IF EXISTS dbo.F_Pluie;
DROP TABLE IF EXISTS dbo.F_Indicateurs_Region;
DROP TABLE IF EXISTS dbo.F_Pauvrete;
DROP TABLE IF EXISTS dbo.D_Date;
DROP TABLE IF EXISTS dbo.D_Region;
DROP TABLE IF EXISTS dbo.D_Milieu;
DROP TABLE IF EXISTS dbo.D_Pays;
DROP TABLE IF EXISTS dbo.D_GroupePopulation;
DROP TABLE IF EXISTS dbo.D_TypeEvenement;
GO

/* =============================== DIMENSIONS =============================== */

-- Calendrier 1997-2026, une ligne par jour (rempli par 02_remplir_dimensions_fixes.sql)
CREATE TABLE dbo.D_Date (
    date_key        INT          NOT NULL PRIMARY KEY,   -- AAAAMMJJ, ex. 20241101
    date_complete   DATE         NOT NULL,
    annee           SMALLINT     NOT NULL,
    semestre        TINYINT      NOT NULL,
    trimestre       TINYINT      NOT NULL,
    mois            TINYINT      NOT NULL,
    nom_mois        NVARCHAR(10) NOT NULL,
    decade_du_mois  TINYINT      NOT NULL,                -- 1 (j 1-10), 2 (j 11-20), 3 (j 21-fin)
    jour            TINYINT      NOT NULL
);

-- 12 régions du Maroc (chargée par SSIS depuis data/prepare/regions.csv)
CREATE TABLE dbo.D_Region (
    region_key      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    code_hcp        TINYINT      NOT NULL UNIQUE,         -- code officiel HCP 1..12
    code_hapi       CHAR(5)      NULL,                    -- MA001..MA010 (vide pour Laâyoune et Dakhla)
    nom_region      NVARCHAR(60) NOT NULL,
    nom_hapi        NVARCHAR(60) NULL
);

-- Milieu de résidence (rempli par 02)
CREATE TABLE dbo.D_Milieu (
    milieu_key      TINYINT      NOT NULL PRIMARY KEY,
    milieu          NVARCHAR(10) NOT NULL UNIQUE          -- Ensemble, Urbain, Rural
);

-- Pays (chargée par SSIS depuis data/prepare/pays.csv) ; dimension « jouant deux rôles »
-- dans F_Refugies : pays d'origine et pays d'asile
CREATE TABLE dbo.D_Pays (
    pays_key            INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    iso3                CHAR(3)       NOT NULL UNIQUE,
    nom_pays            NVARCHAR(80)  NOT NULL,
    inform_risque_2026  DECIMAL(3,1)  NULL,               -- 0 à 10
    inform_classe       NVARCHAR(15)  NULL,               -- Very Low .. Very High
    inform_rang         SMALLINT      NULL
);

-- Statut des personnes déplacées (rempli par 02)
CREATE TABLE dbo.D_GroupePopulation (
    groupe_key      TINYINT      NOT NULL PRIMARY KEY,
    code_groupe     CHAR(3)      NOT NULL UNIQUE,         -- REF, ASY, OOC
    libelle         NVARCHAR(60) NOT NULL
);

-- Type d'événement de conflit (rempli par 02)
CREATE TABLE dbo.D_TypeEvenement (
    type_key        TINYINT      NOT NULL PRIMARY KEY,
    code_type       VARCHAR(30)  NOT NULL UNIQUE,         -- valeur du CSV ACLED
    libelle         NVARCHAR(60) NOT NULL
);
GO

/* ================================= FAITS ================================= */

-- Réfugiés et demandeurs d'asile (UNHCR), un total par an / origine / asile / groupe.
-- Source : lignes gender = 'all' ET age_range = 'all' seulement (le détail est incomplet).
CREATE TABLE dbo.F_Refugies (
    date_key            INT     NOT NULL REFERENCES dbo.D_Date(date_key),       -- 1er janvier de l'année
    pays_origine_key    INT     NOT NULL REFERENCES dbo.D_Pays(pays_key),
    pays_asile_key      INT     NOT NULL REFERENCES dbo.D_Pays(pays_key),
    groupe_key          TINYINT NOT NULL REFERENCES dbo.D_GroupePopulation(groupe_key),
    nb_personnes        INT     NOT NULL
);

-- Événements de conflit (ACLED), Maroc entier, par mois et par type.
-- Attention : political_violence et civilian_targeting se recoupent -> ne pas additionner les types.
CREATE TABLE dbo.F_Conflits (
    date_key        INT     NOT NULL REFERENCES dbo.D_Date(date_key),           -- 1er jour du mois
    type_key        TINYINT NOT NULL REFERENCES dbo.D_TypeEvenement(type_key),
    nb_evenements   INT     NOT NULL,
    nb_morts        INT     NULL                                                -- vide pour les manifestations
);

-- Pluviométrie (WFP) par décade, par zone de mesure (une région = 1 à 3 zones).
-- Les mesures sont multipliées par le nombre de pixels : la moyenne pondérée se calcule
-- dans le cube par SUM(pluie_x_pixels) / SUM(nb_pixels), juste à tous les niveaux.
CREATE TABLE dbo.F_Pluie (
    date_key                INT           NOT NULL REFERENCES dbo.D_Date(date_key),  -- 1er jour de la décade
    region_key              INT           NOT NULL REFERENCES dbo.D_Region(region_key),
    code_zone               VARCHAR(10)   NOT NULL,                                  -- provider_admin1_code
    nb_pixels               INT           NOT NULL,
    pluie_x_pixels          DECIMAL(18,4) NOT NULL,                                  -- rainfall * pixels (mm)
    moyenne_lt_x_pixels     DECIMAL(18,4) NOT NULL,                                  -- moyenne long terme * pixels
    est_provisoire          BIT           NOT NULL                                   -- version = preliminary
);

-- Indicateurs socio-économiques du recensement 2024 (HCP), par région et milieu.
-- Seuls Urbain et Rural sont chargés (Ensemble = Urbain + Rural, sinon double compte).
-- Les taux du HCP sont convertis en effectifs dans SSIS ; les taux sont recalculés dans le cube.
CREATE TABLE dbo.F_Indicateurs_Region (
    date_key                    INT     NOT NULL REFERENCES dbo.D_Date(date_key),   -- 20240101
    region_key                  INT     NOT NULL REFERENCES dbo.D_Region(region_key),
    milieu_key                  TINYINT NOT NULL REFERENCES dbo.D_Milieu(milieu_key),
    population_legale           INT     NOT NULL,
    population_marocaine        INT     NOT NULL,
    population_etrangere        INT     NOT NULL,
    nb_menages                  INT     NOT NULL,
    population_10_ans_plus      INT     NOT NULL,
    nb_analphabetes_10_plus     INT     NOT NULL,   -- population_10_ans_plus * taux / 100
    population_15_ans_plus      INT     NOT NULL,
    population_active_15_plus   INT     NOT NULL,
    nb_chomeurs                 INT     NOT NULL,   -- population_active * taux_chomage / 100
    nb_personnes_handicap       INT     NOT NULL    -- population_legale * taux_handicap / 100
);

-- Pauvreté multidimensionnelle (HCP), 2014 et 2024, par région et milieu (Ensemble, Urbain, Rural).
-- Ce sont des taux : NON additifs (dans le cube, agrégation = None ou moyenne, jamais Sum).
CREATE TABLE dbo.F_Pauvrete (
    date_key                    INT          NOT NULL REFERENCES dbo.D_Date(date_key),   -- 20140101 ou 20240101
    region_key                  INT          NOT NULL REFERENCES dbo.D_Region(region_key),
    milieu_key                  TINYINT      NOT NULL REFERENCES dbo.D_Milieu(milieu_key),
    indice_pauvrete_multidim    DECIMAL(9,6) NOT NULL,   -- IPM = H x A, entre 0 et 1
    taux_pauvrete_pct           DECIMAL(9,4) NOT NULL,   -- H : % de la population pauvre
    intensite_pauvrete_pct      DECIMAL(9,4) NOT NULL,   -- A : % moyen de privations des pauvres
    taux_vulnerabilite_pct      DECIMAL(9,4) NOT NULL
);
GO

PRINT N'Base DW_Humanitaire_Maroc créée : 6 dimensions, 5 tables de faits.';
