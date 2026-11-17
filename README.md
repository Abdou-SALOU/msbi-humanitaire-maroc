# Projet MSBI - Indicateurs humanitaires et socio-économiques au Maroc

Projet décisionnel du module **ETL et Data Warehousing** (Pr Mohammed HANINE), 3ᵉ année du cycle ingénieur IABD, ISGA Casablanca.

**Binôme :** Abdou SALOU ABDOU et Essorong BADJAMLA

Chaîne complète : **SSIS** (ETL) → **SQL Server** (Data Warehouse) → **SSAS** (cube OLAP + MDX) → **Tableau** (dashboards).

## Sources (figées le 17/11/2026)

| Dossier | Fichier | Contenu | Utilisé pour |
|---|---|---|---|
| `data/hapi/` | `hdx_hapi_refugees_mar.csv` | Réfugiés et demandeurs d'asile (UNHCR, via [HDX HAPI](https://data.humdata.org/dataset/hdx-hapi-mar)), 2001-2025 | `F_Refugies` |
| `data/hapi/` | `hdx_hapi_conflict_event_mar.csv` | Événements de conflit (ACLED), Maroc entier, 1997-2026 par mois | `F_Conflits` |
| `data/hapi/` | `hdx_hapi_rainfall_mar.csv` | Pluviométrie (WFP), 9 régions, 2022-2026 | `F_Pluie` |
| `data/hcp/` | `hcp_population_legale_2024.xlsx` | Population légale RGPH 2024 (HCP) : Marocains, étrangers, ménages | `F_Indicateurs_Region` |
| `data/hcp/` | `hcp_indicateurs_rgph_2024.xlsx` | Indicateurs démographiques et socio-économiques RGPH 2024 (HCP) | `F_Indicateurs_Region` |
| `data/hcp/` | `hcp_pauvrete_multidimensionnelle_2014_2024.xls` | Cartographie de la pauvreté multidimensionnelle (HCP, mai 2025) | `F_Pauvrete` |
| `data/inform/` | `inform_risk_2026_v072.xlsx` | INFORM Risk 2026 v0.7.2 (31/03/2026) | `D_Pays` (noms des pays + score de risque) |

- `data/archive/` : anciens fichiers HAPI population (2014, 6 régions), pauvreté (OPHI 2011/2017) et risque national (INFORM 2025), **remplacés** par les fichiers HCP et INFORM 2026. Non utilisés.
- `data/hapi/` contient aussi `returnees` et `data_availability`, **non utilisés** (hors périmètre).
- `data/prepare/` : CSV simples produits par `scripts/preparer_donnees.py` à partir des Excel HCP et INFORM (extraction seulement, aucun calcul). **Ce sont ces fichiers que SSIS lit**, avec les CSV de `data/hapi/`. Pour les régénérer : `python scripts/preparer_donnees.py`.

### Règles de nettoyage (à appliquer dans SSIS)

- **Réfugiés** : garder seulement `gender = all` ET `age_range = all` (le détail par sexe et âge est incomplet : il ne correspond au total que dans 1 477 cas sur 2 694).
- **Pluie** : garder seulement `aggregation_period = dekad` (les périodes 1 mois et 3 mois se chevauchent). Une région a 1 à 3 zones de mesure (`provider_admin1_code`) : on garde une ligne par zone. `version = preliminary` -> `est_provisoire = 1`.
- **Conflits** : `fatalities` vide pour les manifestations -> NULL. Ne pas additionner les types (violence politique et violence contre les civils se recoupent).
- **Indicateurs 2024** : charger seulement Urbain et Rural (Ensemble = Urbain + Rural). Convertir les taux en effectifs (Derived Column).
- **Régions** : correspondance code HCP (1-12) et code HAPI (MA001-MA010) dans `data/prepare/regions.csv`. Laâyoune et Dakhla n'ont pas de code HAPI et pas de données de pluie.

## Modèle : constellation de faits

Base SQL Server **`DW_Humanitaire_Maroc`** (scripts dans `sql/`, à lancer dans l'ordre).

| Fait | Grain | Mesures | Dimensions |
|---|---|---|---|
| `F_Refugies` | année x pays d'origine x pays d'asile x groupe | `nb_personnes` | D_Date, D_Pays (2 rôles), D_GroupePopulation |
| `F_Conflits` | mois x type d'événement | `nb_evenements`, `nb_morts` | D_Date, D_TypeEvenement |
| `F_Pluie` | décade x zone de mesure | `nb_pixels`, `pluie_x_pixels`, `moyenne_lt_x_pixels` | D_Date, D_Region |
| `F_Indicateurs_Region` | 2024 x région x milieu (Urbain, Rural) | population, étrangers, ménages, actifs, chômeurs, analphabètes, handicap | D_Date, D_Region, D_Milieu |
| `F_Pauvrete` | 2014/2024 x région x milieu | IPM, taux, intensité, vulnérabilité (**taux non additifs**) | D_Date, D_Region, D_Milieu |

**Dans le cube :** les taux sont des membres calculés, jamais des sommes :
pluie moyenne = `pluie_x_pixels / nb_pixels`, taux de chômage = `nb_chomeurs / population_active_15_plus`, etc. Les mesures de `F_Pauvrete` ont l'agrégation `None` (affichées au niveau région seulement).

| Script | Rôle |
|---|---|
| `sql/01_creer_dw.sql` | Crée la base, les 6 dimensions et les 5 faits (relançable) |
| `sql/02_remplir_dimensions_fixes.sql` | Remplit D_Date (1997-2026), D_Milieu, D_GroupePopulation, D_TypeEvenement |
| `sql/03_controles.sql` | Après SSIS : compare le DW aux totaux attendus des fichiers sources (colonne `ok`) |

## Organisation du dépôt

| Dossier | Contenu |
|---|---|
| `data/` | Sources (`hapi/`, `hcp/`, `inform/`), fichiers préparés (`prepare/`), anciens fichiers (`archive/`) |
| `scripts/` | `preparer_donnees.py` : extraction des Excel HCP et INFORM en CSV |
| `sql/` | Scripts de création du Data Warehouse |
| `ssis/` | Projet Visual Studio SSIS (packages `.dtsx`) |
| `ssas/` | Projet Visual Studio SSAS (cube) ; `ssas/mdx/` pour les requêtes MDX |
| `tableau/` | Classeurs Tableau (`.twb` / `.twbx`) |
| `docs/` | Livrable, diapos, `captures/` pour les captures d'écran |
| `installer_outils_msbi.ps1` | Installe tous les logiciels (clic droit > Exécuter avec PowerShell, en administrateur) |

## Répartition

| | Abdou | Essorong |
|---|---|---|
| SQL Server | Script du DW (fait le 17/11) | - |
| SSIS | Tous les packages (dimensions + 5 faits) | Relecture |
| SSAS | Relecture | Cube SSAS + requêtes MDX |
| Tableau | Tableaux de bord « Réfugiés » + « Régions » | Tableaux de bord « Pluie » + « Conflits » |
| Livrable et oral | À deux | À deux |

Le schéma du DW est figé : Essorong peut construire le cube dès maintenant (lancer `sql/01` et `sql/02` sur son PC), sans attendre les données.

### Travailler à deux sur Tableau

Un classeur Tableau (`.twb`) est un fichier XML que Git fusionne mal : **chacun travaille dans son propre classeur**, branché sur le même cube / DW (`tableau/abdou.twb`, `tableau/essorong.twb`), puis assemblage dans `tableau/final.twbx`. Mêmes couleurs, polices et noms de champs.

## Planning

| Date | Étape |
|---|---|
| Mar 17/11 | Sources figées, DW créé |
| Mer 18/11 | SSIS : dimensions Région et Pays + début des faits / cube : projet SSAS sur les tables |
| Jeu 19/11 | SSIS : les 5 faits chargés, `03_controles.sql` tout à 1 / cube : dimensions, mesures |
| Ven 20/11 | Cube terminé + 5 ou 6 requêtes MDX |
| Sam 21/11 | Tableau |
| Dim 22/11 | Document de captures commentées |
| Lun 23/11 | **Envoi au Pr Hanine** |
| 24-25/11 | Diapos + répétition (chacun sait expliquer toute la chaîne) |

## Règles de travail

1. **Toujours commencer par `git pull`** avant de travailler.
2. Commits petits et fréquents, avec un message clair : `ssis: package F_Pluie (filtre décade + version finale)`.
3. **Fermer Visual Studio avant de faire un commit** sur un projet SSIS ou SSAS.
4. Ne jamais travailler à deux en même temps sur le même package `.dtsx` ou le même cube : ces fichiers XML se fusionnent mal.
