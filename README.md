# Projet MSBI - Indicateurs humanitaires et socio-économiques au Maroc

Projet décisionnel du module **ETL et Data Warehousing** (Pr Mohammed HANINE), 3ᵉ année du cycle ingénieur IABD, ISGA Casablanca.

**Binôme :** Abdou SALOU ABDOU et Essorong BADJAMLA

Chaîne complète : **SSIS** (ETL) → **SQL Server** (Data Warehouse) → **SSAS** (cube OLAP + MDX) → **Tableau** (dashboards).

## Jeu de données

[HDX HAPI - Maroc](https://data.humdata.org/dataset/hdx-hapi-mar) (OCHA) : 8 fichiers CSV dans `data/`.

| Fichier | Contenu | Niveau géographique | Période |
|---|---|---|---|
| `hdx_hapi_refugees_mar.csv` | Réfugiés et demandeurs d'asile (UNHCR), dans les deux sens | Pays | 2001-2025, annuel |
| `hdx_hapi_returnees_mar.csv` | Rapatriés (UNHCR) | Maroc | 2024-2025 |
| `hdx_hapi_conflict_event_mar.csv` | Événements de conflit (ACLED) | Maroc entier | 1997-2026, mensuel |
| `hdx_hapi_rainfall_mar.csv` | Pluviométrie (WFP) | 9 régions | 2022-2026, décade / mois / trimestre |
| `hdx_hapi_poverty_rate_mar.csv` | Pauvreté multidimensionnelle (Oxford OPHI) | 12 régions + national | 2011 et 2017 |
| `hdx_hapi_population_mar.csv` | Population de base (OCHA) | 6 régions, 31 provinces | 2014 |
| `hdx_hapi_national_risk_mar.csv` | Indice de risque INFORM | Maroc | 2025 (1 ligne) |
| `hdx_hapi_data_availability_mar.csv` | Métadonnées de disponibilité | - | - |

### Points de nettoyage repérés

- Pluie : 3 périodes d'agrégation qui se chevauchent et 2 versions (final / preliminary) → garder la décade et la version finale.
- Pauvreté : encodage latin-1 (accents) ; Dakhla et Laâyoune sans `admin1_code`.
- Réfugiés, rapatriés, population : lignes « all » (genre, âge) à ne pas additionner avec le détail.
- Conflits : pas de découpage régional → membre « Maroc (national) » dans la géographie.

## Modèle : constellation de faits

- **Faits :** `F_Refugies`, `F_Conflits`, `F_Pluie`, `F_Pauvrete`, `F_Population`
- **Dimensions partagées :** `D_Date`, `D_Geographie` (Maroc > Région > Province), `D_Pays` (rôle origine / asile), `D_Genre`, `D_TrancheAge`, `D_TypeEvenement`, `D_GroupePopulation`

## Organisation du dépôt

| Dossier | Contenu |
|---|---|
| `data/` | Fichiers sources (ne pas modifier) |
| `sql/` | Scripts de création du Data Warehouse |
| `ssis/` | Projet Visual Studio SSIS (packages `.dtsx`) |
| `ssas/` | Projet Visual Studio SSAS (cube) ; `ssas/mdx/` pour les requêtes MDX |
| `tableau/` | Classeurs Tableau (`.twb` / `.twbx`) |
| `docs/` | Livrable, diapos, `captures/` pour les captures d'écran |
| `installer_outils_msbi.ps1` | Installe tous les logiciels (clic droit > Exécuter avec PowerShell, en administrateur) |

## Répartition

| | Abdou | Essorong |
|---|---|---|
| SQL Server | Script du DW + dimensions Date, Géographie, Pays | - |
| SSIS | Réfugiés + rapatriés, Population, Pauvreté | Conflits, Pluie, Risque national |
| Analyse | Tableau | Cube SSAS + requêtes MDX |
| Livrable | Ses sections + captures | Ses sections + assemblage |

## Planning

| Date | Étape |
|---|---|
| 14-15/11 | Installation des outils ; schéma figé ensemble |
| 16/11 | Script du DW, début du cube |
| 17-18/11 | Packages SSIS |
| 19/11 | Tableau, cube complet, MDX |
| 20/11 | Intégration complète |
| 21/11 | Rédaction du livrable |
| 22/11 | Échange croisé (chacun explique sa partie à l'autre), envoi |

## Règles de travail

1. **Toujours commencer par `git pull`** avant de travailler.
2. Commits petits et fréquents, avec un message clair : `ssis: package F_Pluie (filtre décade + version finale)`.
3. **Fermer Visual Studio avant de faire un commit** sur un projet SSIS ou SSAS.
4. Ne jamais travailler à deux en même temps sur le même package `.dtsx` ou le même cube : ces fichiers XML se fusionnent mal.
5. Noter dans la section « Journal » ci-dessous ce qui est fini et ce qui bloque.

## Journal

| Date | Qui | Fait | Reste / blocage |
|---|---|---|---|
| 13/11 | Abdou | Dataset téléchargé et analysé | - |
| 14/11 | Abdou | Dépôt créé, installation des outils lancée | - |
