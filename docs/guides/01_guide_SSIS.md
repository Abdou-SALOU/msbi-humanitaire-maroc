# Guide SSIS - chargement du Data Warehouse pas à pas

But : construire dans Visual Studio les 8 packages SSIS qui remplissent `DW_Humanitaire_Maroc`.
Chaque étape dit **quoi faire**, **pourquoi** (à savoir expliquer à l'oral) et **quelle capture prendre** (📸) pour le livrable.

Les noms des menus sont en français, avec le nom anglais entre parenthèses si ton Visual Studio est en anglais.

## 0. Avant de commencer (5 min)

1. `git pull` dans le dossier du projet.
2. Dans SSMS, vérifier que la base existe : `DW_Humanitaire_Maroc` avec 11 tables (sinon lancer `sql/01`, `sql/02`, `sql/05`).
3. Garder ouverts : ce guide, SSMS, et `docs/resultats_attendus.md`.

**Ce que fait l'ETL (à savoir dire en une phrase) :** SSIS lit 3 fichiers HAPI (ONU) et 7 fichiers préparés à partir des Excel du HCP et d'INFORM, les nettoie (filtres, conversions de types, valeurs manquantes), les fusionne (Union All, Merge Join), remplace les codes par les clés des dimensions (Lookup = jointure) et charge 2 dimensions et 5 tables de faits.

### Ordre de construction (et d'exécution)

| Package | Charge | Techniques montrées |
|---|---|---|
| `01_D_Region` | D_Region (12 lignes) | Source fichier plat, valeurs NULL |
| `02_D_Pays` | D_Pays (191 lignes) | Types numériques |
| `03_F_Refugies` | F_Refugies (2 694) | Fractionnement conditionnel, colonne dérivée, **2 Lookups sur la même dimension** (dimension à 2 rôles) |
| `04_F_Conflits` | F_Conflits (1 074) | Nettoyage d'une valeur « None » en NULL |
| `05_F_Pluie` | F_Pluie (2 610) | Filtre, calculs, booléen |
| `06_F_Indicateurs_Region` | F_Indicateurs_Region (24) | **Tri + Merge Join** (fusion de 2 fichiers HCP), conversion taux -> effectifs |
| `07_F_Pauvrete` | F_Pauvrete (72) | **Union All** (fusion de 3 fichiers) |
| `00_Master` | tout | Exécuter SQL + Exécuter package (orchestration) |

---

## 1. Créer le projet (10 min)

1. Visual Studio > **Créer un projet** > chercher **Integration Services** > **Projet Integration Services** (*Integration Services Project*).
2. Nom : `MSBI_ETL`. Emplacement : `...\Projet_MSBI\ssis`. Cocher **Placer la solution et le projet dans le même répertoire**.
3. Dans l'Explorateur de solutions, renommer `Package.dtsx` en `01_D_Region.dtsx`.

📸 **Capture 1** : l'Explorateur de solutions avec le projet `MSBI_ETL`.

### 1.1 Connexion au Data Warehouse (une seule fois, pour tous les packages)

1. Explorateur de solutions > clic droit sur **Gestionnaires de connexions** (*Connection Managers*) > **Nouveau gestionnaire de connexions** > **OLEDB** > **Ajouter** > **Nouveau**.
2. Fournisseur : **Microsoft OLE DB Driver 19 for SQL Server**.
3. Nom du serveur : `localhost` ; Authentification Windows ; base : `DW_Humanitaire_Maroc`.
4. **Important** : onglet **Tout** (*All*) > **Trust Server Certificate** = `True`. Sinon : erreur « chaîne de certificats non approuvée » (le pilote 19 chiffre la connexion par défaut).
5. **Tester la connexion** > OK. Renommer la connexion `DW`.

> Pourquoi au niveau du **projet** : tous les packages réutilisent la même connexion ; si le serveur change, on ne la modifie qu'une fois.
> Plan B si erreur persistante : fournisseur **Microsoft OLE DB Provider for SQL Server** (ancien, sans chiffrement).

📸 **Capture 2** : la fenêtre de connexion avec « Test de connexion réussi ».

### 1.2 Réglage commun de TOUS les fichiers plats (à refaire pour chaque fichier)

Dans chaque **Gestionnaire de connexions de fichiers plats** (*Flat File Connection Manager*), page **Général** :

| Réglage | Valeur | Pourquoi |
|---|---|---|
| Paramètres régionaux (*Locale*) | **Anglais (États-Unis)** | Les nombres des fichiers ont un point décimal (`13.18`). En français, SSIS attend une virgule et refuse la conversion. |
| Page de codes (*Code page*) | **65001 (UTF-8)** | Les fichiers sont en UTF-8 : sinon « Fès » devient « FÃ¨s ». |
| Format | Délimité | |
| Qualificateur de texte | `<aucun>` | Aucun champ n'est entre guillemets. |
| Délimiteur de ligne d'en-tête | `{CR}{LF}` | |
| **Noms des colonnes dans la première ligne de données** | coché | |

Page **Colonnes** : délimiteur **Virgule {,}** pour les fichiers `hapi`, **Point-virgule {;}** pour les fichiers `prepare`.

Page **Avancé** : régler le **DataType** des colonnes utilisées comme indiqué dans chaque package. Règle : **tout texte en `chaîne Unicode [DT_WSTR]`**.

> Pourquoi DT_WSTR : la base stocke les textes en `NVARCHAR` (Unicode). Si une colonne reste en `DT_STR`, SSIS refuse avec « impossible de convertir entre des types de données Unicode et non Unicode ».

---

## 2. Package `01_D_Region` (15 min)

**But :** charger les 12 régions (code HCP 1-12, code HAPI MA001-MA010).

1. Onglet **Flux de contrôle** : glisser une **Tâche de flux de données** (*Data Flow Task*), la renommer `Charger D_Region`, double-cliquer.
2. Glisser une **Source de fichier plat** > **Nouveau** gestionnaire : fichier `data\prepare\regions.csv`, nom `CSV regions`, réglages du 1.2 (point-virgule).
   Page Avancé :

   | Colonne | DataType | Longueur |
   |---|---|---|
   | code_hcp | entier non signé d'un octet [DT_UI1] | |
   | code_hapi | chaîne Unicode [DT_WSTR] | 5 |
   | nom_region | chaîne Unicode [DT_WSTR] | 60 |
   | nom_hapi | chaîne Unicode [DT_WSTR] | 60 |

3. Double-cliquer la source > cocher **Conserver les valeurs NULL de la source en tant que valeurs NULL dans le flux de données**.
   > Pourquoi : Laâyoune et Dakhla n'ont pas de code HAPI. Sans cette case, SSIS écrirait une chaîne vide `''` au lieu de NULL, ce qui fausserait les jointures avec la pluie.
4. Glisser une **Destination OLE DB**, relier la flèche bleue de la source vers elle. Double-cliquer : connexion `DW`, mode **Table ou vue - chargement rapide**, table `[dbo].[D_Region]`, cocher **Conserver les valeurs NULL**.
5. Page **Mappages** : vérifier code_hcp, code_hapi, nom_region, nom_hapi. `region_key` reste `<ignorer>` : c'est une **clé de substitution** (IDENTITY) générée par SQL Server.
6. Exécuter : **F5** (ou clic droit sur le package > Exécuter le package). Tout doit passer au vert avec **12 lignes**.

📸 **Capture 3** : le flux de données au vert avec « 12 lignes ».

Vérification SSMS : `SELECT * FROM D_Region;` (12 lignes, code_hapi NULL pour 11 et 12).

> Pour relancer un package de dimension : exécuter d'abord `sql/04_vider_avant_chargement.sql` (les faits pointent vers les dimensions).

---

## 3. Package `02_D_Pays` (10 min)

Clic droit sur **Packages SSIS** > **Nouveau package SSIS**, nom `02_D_Pays.dtsx`. Même schéma : Tâche de flux de données > Source fichier plat > Destination OLE DB `[dbo].[D_Pays]`.

Fichier `data\prepare\pays.csv` (point-virgule). Page Avancé :

| Colonne | DataType | Détail |
|---|---|---|
| iso3 | DT_WSTR | longueur 3 |
| nom_pays | DT_WSTR | longueur 80 |
| inform_risque_2026 | numérique [DT_NUMERIC] | précision 3, échelle 1 |
| inform_classe_risque | DT_WSTR | longueur 15 |
| inform_rang | entier signé de deux octets [DT_I2] | |

Mappages : `inform_classe_risque` -> `inform_classe`. Résultat attendu : **191 lignes**.

> À dire : les noms des pays viennent du fichier INFORM, utilisé comme **référentiel** ; il apporte aussi un score de risque par pays (attribut de la dimension).

📸 **Capture 4**.

---

## 4. Package `03_F_Refugies` (40 min)

**Flux de contrôle :**
1. **Tâche d'exécution de requêtes SQL** (*Execute SQL Task*) nommée `Vider F_Refugies` : connexion `DW`, requête `TRUNCATE TABLE dbo.F_Refugies;`.
2. Une **Tâche de flux de données** `Charger F_Refugies`, reliée par la flèche verte (*contrainte de précédence* : « en cas de succès »).

> Pourquoi vider d'abord : le package peut être relancé sans créer de doublons (chargement complet).

**Flux de données :**

1. **Source fichier plat** : `data\hapi\hdx_hapi_refugees_mar.csv`, **virgule**. Page Avancé :

   | Colonne | DataType | Longueur |
   |---|---|---|
   | origin_location_code | DT_WSTR | 3 |
   | asylum_location_code | DT_WSTR | 3 |
   | population_group | DT_WSTR | 3 |
   | gender | DT_WSTR | 5 |
   | age_range | DT_WSTR | 5 |
   | population | entier signé de quatre octets [DT_I4] | |
   | reference_period_start | DT_WSTR | 10 |

   Dans la source, page **Colonnes** : décocher les colonnes inutiles (has_hrp, in_gho, min_age, max_age, reference_period_end).

2. **Fractionnement conditionnel** (*Conditional Split*) `Garder les totaux` :
   - Sortie `Totaux` : `gender == "all" && age_range == "all"`
   - Sortie par défaut : `Detail_ignore`
   > Pourquoi : le fichier mélange des lignes « total » et des lignes « détail par sexe et âge ». Le détail est incomplet (il ne correspond au total que dans 1 477 cas sur 2 694) : additionner les deux compterait les gens deux fois. On garde les totaux.

3. **Colonne dérivée** (*Derived Column*) `Cle date` (relier la sortie `Totaux`) :
   - `date_key` = `(DT_I4)REPLACE(reference_period_start,"-","")`
   > `2025-01-01` -> `20250101`, la clé de D_Date.

4. **Recherche** (*Lookup*) `Pays origine` :
   - Général : **Cache complet** ; lignes sans correspondance : **Échec du composant**.
   - Connexion : `DW`, **Utiliser les résultats d'une requête SQL** : `SELECT pays_key, iso3 FROM dbo.D_Pays`
   - Colonnes : relier `origin_location_code` -> `iso3`, cocher `pays_key`, alias de sortie **`pays_origine_key`**.

5. **Recherche** `Pays asile` (sortie **Correspondance** du Lookup précédent) : même requête, relier `asylum_location_code` -> `iso3`, alias **`pays_asile_key`**.
   > À dire : **D_Pays est une dimension à deux rôles** (*role-playing dimension*) : la même table sert de pays d'origine ET de pays d'asile. Dans le cube, elle apparaîtra deux fois.

6. **Recherche** `Groupe` : `SELECT groupe_key, code_groupe FROM dbo.D_GroupePopulation`, relier `population_group` -> `code_groupe`, cocher `groupe_key`.

7. **Destination OLE DB** `[dbo].[F_Refugies]` (chargement rapide). Mappages : date_key, pays_origine_key, pays_asile_key, groupe_key, **population -> nb_personnes**.

Résultat attendu : **35 022 lignes lues, 2 694 dans `Totaux`, 2 694 chargées**.

📸 **Capture 5** : le flux de données complet au vert avec les nombres de lignes sur chaque flèche (c'est LA capture qui montre le nettoyage).
📸 **Capture 6** : l'éditeur du fractionnement conditionnel.
📸 **Capture 7** : l'éditeur du Lookup « Pays asile » (onglet Colonnes).

---

## 5. Package `04_F_Conflits` (25 min)

Flux de contrôle : `Vider F_Conflits` (`TRUNCATE TABLE dbo.F_Conflits;`) puis la tâche de flux de données.

1. Source : `data\hapi\hdx_hapi_conflict_event_mar.csv`, virgule. Avancé : event_type DT_WSTR 30, events DT_I4, **fatalities DT_WSTR 10**, reference_period_start DT_WSTR 10. Décocher les colonnes inutiles.
   > fatalities reste en texte à cette étape car il contient le mot `None` pour les manifestations : le convertir directement en nombre ferait échouer le package.
2. **Colonne dérivée** `Nettoyage` :
   - `date_key` = `(DT_I4)REPLACE(reference_period_start,"-","")`
   - `nb_morts` = `fatalities == "None" || fatalities == "" ? NULL(DT_I4) : (DT_I4)fatalities`
   > À dire : **nettoyage des valeurs manquantes** : « None » signifie « non applicable », on le transforme en vrai NULL (et pas en 0, qui voudrait dire « zéro mort »).
3. **Recherche** `Type evenement` : `SELECT type_key, code_type FROM dbo.D_TypeEvenement`, relier `event_type` -> `code_type`, cocher `type_key`.
4. Destination `[dbo].[F_Conflits]` : date_key, type_key, **events -> nb_evenements**, nb_morts. Cocher **Conserver les valeurs NULL**.

Résultat : **1 074 lignes**. 📸 **Capture 8** : l'éditeur de la colonne dérivée.

---

## 6. Package `05_F_Pluie` (30 min)

Flux de contrôle : `Vider F_Pluie` (`TRUNCATE TABLE dbo.F_Pluie;`) puis flux de données.

1. Source : `data\hapi\hdx_hapi_rainfall_mar.csv`, virgule. Avancé :

   | Colonne | DataType | Longueur |
   |---|---|---|
   | admin1_code | DT_WSTR | 5 |
   | provider_admin1_code | DT_WSTR | 10 |
   | aggregation_period | DT_WSTR | 10 |
   | rainfall | virgule flottante double précision [DT_R8] | |
   | rainfall_long_term_average | DT_R8 | |
   | number_pixels | DT_I4 | |
   | version | DT_WSTR | 15 |
   | reference_period_start | DT_WSTR | 10 |

2. **Fractionnement conditionnel** `Garder les decades` : sortie `Decades` = `aggregation_period == "dekad"`, défaut `Autres_periodes`.
   > Pourquoi : chaque date existe en 3 versions (décade, cumul 1 mois, cumul 3 mois) qui se chevauchent. Les additionner compterait la même pluie plusieurs fois. On garde la plus fine : la décade (10 jours).
3. **Colonne dérivée** `Calculs` :
   - `date_key` = `(DT_I4)REPLACE(reference_period_start,"-","")`
   - `pluie_x_pixels` = `(DT_NUMERIC,18,4)(rainfall * number_pixels)`
   - `moyenne_lt_x_pixels` = `(DT_NUMERIC,18,4)(rainfall_long_term_average * number_pixels)`
   - `est_provisoire` = `version == "preliminary"`
   > À dire : une région est couverte par 1 à 3 zones de mesure de tailles différentes (nombre de pixels satellite). On stocke « pluie × pixels » : dans le cube, `somme(pluie × pixels) / somme(pixels)` donne une **moyenne pondérée par la surface**, juste pour une région comme pour tout le Maroc. Une simple moyenne donnerait autant de poids à une petite zone qu'à une grande.
4. **Recherche** `Region` : `SELECT region_key, code_hapi FROM dbo.D_Region WHERE code_hapi IS NOT NULL`, relier `admin1_code` -> `code_hapi`, cocher `region_key`.
5. Destination `[dbo].[F_Pluie]` : date_key, region_key, **provider_admin1_code -> code_zone**, **number_pixels -> nb_pixels**, pluie_x_pixels, moyenne_lt_x_pixels, est_provisoire.

Résultat : **7 830 lignes lues, 2 610 décades chargées** (dont 45 provisoires). 📸 **Capture 9**.

---

## 7. Package `06_F_Indicateurs_Region` (45 min) - la fusion de fichiers

Flux de contrôle : `Vider F_Indicateurs_Region` (`TRUNCATE TABLE dbo.F_Indicateurs_Region;`) puis flux de données.

1. **Source 1** : `data\prepare\hcp_indicateurs_region_2024.csv` (point-virgule). Avancé :

   | Colonne | DataType |
   |---|---|
   | code_hcp | DT_UI1 |
   | milieu | DT_WSTR 10 |
   | annee, population_legale, population_15_ans_plus, population_10_ans_plus, population_active_15_plus | DT_I4 |
   | taux_handicap_pct, taux_scolarisation_6_11_pct, taux_analphabetisme_10_plus_pct, taux_activite_pct, taux_chomage_pct | DT_R8 |

2. **Source 2** : `data\prepare\hcp_population_legale_2024.csv` (point-virgule) : code_hcp DT_UI1, milieu DT_WSTR 10, population_marocaine / population_etrangere / nb_menages DT_I4.
   > Ce sont **deux fichiers différents du HCP** (le fichier des indicateurs et celui de la population légale). On les fusionne ligne à ligne sur (région, milieu).
3. Sous chaque source : une transformation **Tri** (*Sort*) sur `code_hcp` puis `milieu` (ordre croissant).
   > Pourquoi : la **Jointure de fusion** (*Merge Join*) exige deux entrées triées sur la clé de jointure, comme une fusion de deux listes triées.
4. **Jointure de fusion** : entrée gauche = tri de la source 1, entrée droite = tri de la source 2. Type **Jointure interne**, clés `code_hcp` + `milieu`. Cocher toutes les colonnes de gauche + population_marocaine, population_etrangere, nb_menages de droite.
5. **Fractionnement conditionnel** `Urbain et rural` : sortie `Urbain_Rural` = `milieu != "Ensemble"`, défaut `Ensemble_ignore`.
   > Pourquoi : « Ensemble » = Urbain + Rural. Charger les trois ferait compter la population deux fois. Le cube recalcule l'ensemble en additionnant.
6. **Colonne dérivée** `Taux vers effectifs` :
   - `date_key` = `annee * 10000 + 101`
   - `nb_chomeurs` = `(DT_I4)ROUND(population_active_15_plus * taux_chomage_pct / 100, 0)`
   - `nb_analphabetes_10_plus` = `(DT_I4)ROUND(population_10_ans_plus * taux_analphabetisme_10_plus_pct / 100, 0)`
   - `nb_personnes_handicap` = `(DT_I4)ROUND(population_legale * taux_handicap_pct / 100, 0)`
   > À dire : **un taux ne s'additionne pas** (19 % + 25 % ne fait pas 44 % de chômage). On stocke des effectifs, qui s'additionnent, et le cube recalcule le taux à n'importe quel niveau : `chômeurs / actifs`.
7. **Recherche** `Region` : `SELECT region_key, code_hcp FROM dbo.D_Region`, relier `code_hcp`, cocher `region_key`.
8. **Recherche** `Milieu` : `SELECT milieu_key, milieu FROM dbo.D_Milieu`, relier `milieu`, cocher `milieu_key`.
9. Destination `[dbo].[F_Indicateurs_Region]` : toutes les colonnes de la table (date_key, region_key, milieu_key, population_legale, population_marocaine, population_etrangere, nb_menages, population_10_ans_plus, nb_analphabetes_10_plus, population_15_ans_plus, **population_active_15_plus**, nb_chomeurs, nb_personnes_handicap).

Résultat : **36 + 36 lignes lues, 36 fusionnées, 24 chargées**. 📸 **Capture 10** : le flux complet (2 sources, 2 tris, Merge Join).

---

## 8. Package `07_F_Pauvrete` (30 min) - fusion par Union All

Flux de contrôle : `Vider F_Pauvrete` (`TRUNCATE TABLE dbo.F_Pauvrete;`) puis flux de données.

1. **Trois sources** fichier plat : `hcp_pauvrete_ensemble.csv`, `hcp_pauvrete_urbain.csv`, `hcp_pauvrete_rural.csv` (point-virgule, 3 gestionnaires de connexions). Avancé (identique pour les 3) : code_hcp DT_UI1, annee DT_I4, les 4 autres colonnes DT_R8.
2. Sous chaque source, une **Colonne dérivée** qui ajoute `milieu` : `(DT_WSTR,10)"Ensemble"` (puis `"Urbain"`, puis `"Rural"`).
   > Pourquoi : le milieu n'est pas dans les fichiers, il est dans leur NOM (une feuille Excel par milieu). On l'ajoute avant de fusionner, sinon on ne saurait plus d'où vient chaque ligne.
3. **Union totale** (*Union All*) : relier les 3 colonnes dérivées. Vérifier que les colonnes s'alignent.
   > À dire : **Union All empile** des fichiers de même structure (on ajoute des lignes), alors que **Merge Join juxtapose** deux fichiers sur une clé (on ajoute des colonnes).
4. **Colonne dérivée** `date_key` = `annee * 10000 + 101`.
5. **Recherches** `Region` et `Milieu` (comme au 7).
6. Destination `[dbo].[F_Pauvrete]` : date_key, region_key, milieu_key, indice_pauvrete_multidim, taux_pauvrete_pct, intensite_pauvrete_pct, taux_vulnerabilite_pct.

Résultat : **24 + 24 + 24 = 72 lignes**. 📸 **Capture 11**.

---

## 9. Package `00_Master` : tout lancer d'un coup (20 min)

1. Nouveau package `00_Master.dtsx`.
2. **Tâche d'exécution de requêtes SQL** `Vider les tables` : connexion `DW`, coller le contenu de `sql/04_vider_avant_chargement.sql`.
3. **Tâche d'exécution de package** (*Execute Package Task*) pour chaque package : ReferenceType = **Référence de projet**, choisir le package. Les enchaîner avec des flèches vertes : `Vider` -> `01_D_Region` -> `02_D_Pays` -> les 5 packages de faits.
   > Bonus à l'oral : les 5 packages de faits peuvent partir **en parallèle** (5 flèches depuis `02_D_Pays`) car ils sont indépendants entre eux ; seules les dimensions doivent être chargées avant.
4. F5 : tout doit passer au vert.

📸 **Capture 12** : le flux de contrôle du Master au vert.

## 10. Vérification finale (5 min)

Dans SSMS, ouvrir et exécuter `sql/03_controles.sql` : **toutes les lignes doivent avoir `ok = 1`**. Le taux de chômage recalculé doit être **21,3 %** (le chiffre officiel du HCP).

📸 **Capture 13** : le résultat de `03_controles.sql`.

Puis : fermer Visual Studio, `git add ssis` / `git commit -m "ssis: 8 packages, DW chargé et contrôlé"` / `git push`.

---

## Dépannage rapide

| Message | Cause | Solution |
|---|---|---|
| « chaîne de certificats ... non approuvée » | Pilote OLE DB 19 | Connexion > Tout > Trust Server Certificate = True |
| « impossible de convertir entre des types Unicode et non Unicode » | une colonne texte est restée en DT_STR | page Avancé du fichier plat : DT_WSTR |
| « La conversion des données a échoué ... statut 2 » sur un nombre | point décimal lu en français | Paramètres régionaux = Anglais (États-Unis) |
| « Accents illisibles (FÃ¨s) » | mauvaise page de codes | 65001 (UTF-8) |
| Lookup : « aucune correspondance trouvée » | dimension pas encore chargée, ou espaces/type différents | lancer 01 et 02 d'abord ; vérifier DT_WSTR et longueur |
| « Violation de la contrainte FOREIGN KEY » | date_key absente de D_Date ou dimension vide | vérifier la colonne dérivée date_key ; relancer sql/02 |
| « DELETE ... en conflit avec la contrainte REFERENCE » | relance d'une dimension alors que des faits existent | lancer sql/04 d'abord (ou passer par 00_Master) |
| « Troncation » | longueur DT_WSTR trop petite | augmenter la longueur dans Avancé |
