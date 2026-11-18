# Guide SSAS - cube OLAP et requêtes MDX pas à pas

But : construire dans Visual Studio le cube **Humanitaire Maroc** sur `DW_Humanitaire_Maroc`, le déployer, puis lancer les 8 requêtes MDX de `ssas/mdx/requetes_mdx.mdx`.
Chaque étape dit quoi faire, pourquoi, et quelle capture prendre (📸).

**Le cube peut être construit AVANT que SSIS ait chargé les données** : il suffit que les tables existent (`sql/01`, `sql/02`). On le « traite » (*process*) une fois les données chargées.

## 0. Prérequis (une fois par PC)

1. `git pull`.
2. Dans SSMS (moteur de base de données) : exécuter `sql/01_creer_dw.sql`, `sql/02_remplir_dimensions_fixes.sql` et **`sql/05_droits_ssas.sql`**.
   > Pourquoi 05 : SSAS lit le DW avec le compte de son service Windows (`NT Service\MSSQLServerOLAPService`). Sans ce droit de lecture, le traitement du cube échoue (« Échec de l'ouverture de session »).
3. Vérifier que le serveur SSAS est en mode **multidimensionnel** : SSMS > Se connecter > Analysis Services > `localhost`.

## 1. Créer le projet (5 min)

Visual Studio > Créer un projet > **Projet multidimensionnel Analysis Services** (*Analysis Services Multidimensional Project*). Nom `MSBI_Cube`, emplacement `...\Projet_MSBI\ssas`, cocher « Placer la solution et le projet dans le même répertoire ».

## 2. Source de données (10 min)

Explorateur de solutions > **Sources de données** > Nouvelle source de données > Nouveau :
- Fournisseur : **Microsoft OLE DB Driver 19 for SQL Server** ; serveur `localhost` ; Authentification Windows ; base `DW_Humanitaire_Maroc` ; onglet **Tout** : **Trust Server Certificate = True**. (Plan B : *Microsoft OLE DB Provider for SQL Server*.)
- Informations d'emprunt d'identité (*Impersonation*) : **Utiliser le compte de service**.

📸 **Capture S1** : la source de données.

## 3. Vue de source de données (DSV) (10 min)

**Vues de source de données** > Nouvelle vue > ajouter les **11 tables** (6 `D_` + 5 `F_`).
Les relations sont créées automatiquement à partir des clés étrangères du DW. Vérifier :
- `F_Refugies` a **deux** liens vers `D_Pays` (pays_origine_key et pays_asile_key) ;
- `F_Pluie`, `F_Indicateurs_Region`, `F_Pauvrete` sont liées à `D_Region` ;
- toutes les tables de faits sont liées à `D_Date`.

📸 **Capture S2** : le diagramme de la DSV. **C'est l'image du schéma en constellation** : 5 tables de faits qui partagent des dimensions (Date, Région, Milieu).

> À dire : **constellation de faits** parce que nous avons plusieurs processus métier (réfugiés, conflits, pluie, recensement, pauvreté) avec des grains différents, mais des dimensions communes (temps, région). Une étoile unique aurait forcé un seul grain ; un flocon aurait normalisé les dimensions, inutile ici car elles sont petites.

## 4. Dimensions (40 min)

Clic droit **Dimensions** > Nouvelle dimension > **Utiliser une table existante**, une fois par table `D_` :

| Dimension | Table | Attribut clé (colonne clé -> colonne nom) | Autres attributs |
|---|---|---|---|
| **Date** | D_Date | `date_key` -> `date_complete`, renommer l'attribut **Date** | `annee` (renommer **Annee**), `mois` |
| **Region** | D_Region | `region_key` -> `nom_region`, renommer **Region** | aucun |
| **Milieu** | D_Milieu | `milieu_key` -> `milieu`, renommer **Milieu** | |
| **Pays** | D_Pays | `pays_key` -> `nom_pays`, renommer **Pays** | `inform_classe` (renommer **Classe de risque**) |
| **Groupe Population** | D_GroupePopulation | `groupe_key` -> `libelle`, renommer **Groupe** | |
| **Type Evenement** | D_TypeEvenement | `type_key` -> `libelle`, renommer **Type** | |

### La dimension Date et sa hiérarchie (le point le plus délicat)

Dans l'éditeur de la dimension Date :
1. Attribut **Mois** : propriété **KeyColumns** = `annee` **et** `mois` (deux colonnes) ; **NameColumn** = `nom_mois`.
   > Pourquoi : « janvier » existe dans chaque année. Avec la seule colonne `mois` comme clé, SSAS mélangerait janvier 2020 et janvier 2025 et le traitement échouerait (« clé d'attribut en double »).
2. Créer la hiérarchie **Calendrier** : glisser `Annee`, puis `Mois`, puis `Date`.
3. Onglet **Relations d'attributs** : `Date` -> `Mois` -> `Annee`.
   > Pourquoi : SSAS sait alors qu'un jour appartient à un seul mois et un mois à une seule année ; il pré-calcule les agrégations par année à partir des mois (plus rapide).

📸 **Capture S3** : la hiérarchie Calendrier et les relations d'attributs.

## 5. Cube (20 min)

Clic droit **Cubes** > Nouveau cube > **Utiliser des tables existantes** :
- Tables de groupes de mesures : les **5 tables `F_`**.
- Mesures : garder celles proposées (les colonnes numériques qui ne sont pas des clés).
- Dimensions : sélectionner les 6 dimensions existantes.
- Nom du cube : **Humanitaire Maroc**.

Dans l'onglet **Utilisation de la dimension** (*Dimension Usage*), la dimension Pays apparaît **deux fois** : renommer ces deux dimensions de cube **Pays Origine** et **Pays Asile**.
> À dire : **dimension à jeux de rôles** (*role-playing*) : une seule dimension physique, deux usages.

📸 **Capture S4** : l'onglet Utilisation de la dimension (la matrice faits x dimensions).

## 6. Renommer les groupes de mesures et les mesures (15 min)

Onglet **Structure du cube**, volet Mesures : renommer (F2) exactement comme ci-dessous. Les calculs et les requêtes MDX utilisent ces noms.

| Groupe (renommer) | Colonne du DW | Nom de la mesure | Visible |
|---|---|---|---|
| **Refugies** | nb_personnes | **Personnes** | oui |
| **Conflits** | nb_evenements | **Événements** | oui |
| | nb_morts | **Morts** | oui |
| **Pluie** | nb_pixels | **Pixels** | non |
| | pluie_x_pixels | **Pluie x pixels** | non |
| | moyenne_lt_x_pixels | **Normale x pixels** | non |
| **Indicateurs** | population_legale | **Population** | oui |
| | population_marocaine | **Marocains** | oui |
| | population_etrangere | **Étrangers** | oui |
| | nb_menages | **Ménages** | oui |
| | population_10_ans_plus | **Population 10 ans et plus** | non |
| | nb_analphabetes_10_plus | **Analphabètes** | oui |
| | population_15_ans_plus | **Population 15 ans et plus** | non |
| | population_active_15_plus | **Actifs** | oui |
| | nb_chomeurs | **Chômeurs** | oui |
| | nb_personnes_handicap | **Personnes handicapées** | oui |
| **Pauvrete** | indice_pauvrete_multidim | **Somme IPM** | non |
| | taux_pauvrete_pct | **Somme taux pauvreté** | non |
| | intensite_pauvrete_pct | **Somme intensité** | non |
| | taux_vulnerabilite_pct | **Somme vulnérabilité** | non |
| | (mesure « Nombre », AggregateFunction = Count) | **Lignes pauvreté** | non |

- Supprimer les autres mesures « Nombre » créées par l'assistant (Refugies, Conflits, Pluie, Indicateurs), ou les masquer.
- **est_provisoire** (BIT) : ne pas la garder comme mesure.

> Pourquoi des mesures cachées : elles servent seulement aux calculs. On n'affiche que les mesures qui ont un sens pour l'utilisateur.

## 7. Calculs (10 min)

Onglet **Calculs** > bouton **Vue Script** > coller le contenu de `ssas/calculs_cube.mdx` **sous** la ligne `CALCULATE;`.

> À dire : **un taux ne s'additionne pas**. Le DW stocke des effectifs (chômeurs, actifs) et des produits (pluie x pixels) qui s'additionnent ; le cube recalcule le taux à chaque niveau : `chômeurs / actifs` pour une région, pour un milieu ou pour tout le Maroc. C'est ce qui permet d'afficher le taux national 21,3 % sans l'avoir stocké.

📸 **Capture S5** : l'onglet Calculs.

## 8. Déployer et traiter (10 min)

1. Clic droit sur le projet > **Propriétés** > Déploiement : serveur `localhost`, base **MSBI_Cube**.
2. Une fois SSIS terminé (DW rempli) : clic droit sur le projet > **Déployer**. Le déploiement envoie la structure ET lance le traitement (chargement des données dans le cube).

📸 **Capture S6** : la fenêtre de progression du déploiement « Déploiement terminé ».

## 9. Navigateur du cube et MDX (20 min)

1. Onglet **Navigateur** (*Browser*) : glisser `Taux de chômage` + `Region` + `Milieu`. 📸 **Capture S7**.
2. SSMS > Se connecter > **Analysis Services** > `localhost` > base `MSBI_Cube` > **Nouvelle requête MDX**. Ouvrir `ssas/mdx/requetes_mdx.mdx`, exécuter les requêtes **une par une** (sélection + F5), comparer à `docs/resultats_attendus.md`.

📸 **Captures S8 à S15** : une par requête MDX (requête + résultat).

## 10. Dépannage

| Message | Cause | Solution |
|---|---|---|
| « Échec de l'ouverture de session pour NT Service\MSSQLServerOLAPService » | droit de lecture manquant | exécuter `sql/05_droits_ssas.sql` |
| « certificat non approuvé » | pilote OLE DB 19 | Trust Server Certificate = True dans la source de données |
| « Clé d'attribut en double » sur Mois | clé du mois = mois seul | KeyColumns = annee + mois |
| « La clé d'attribut est introuvable » | faits chargés avant les dimensions, ou cube traité pendant un rechargement | relancer 00_Master puis redéployer |
| Requête MDX : « membre introuvable » | nom de mesure différent du guide | renommer la mesure comme à l'étape 6 |
| Le serveur est en mode tabulaire | mauvaise instance | utiliser l'instance multidimensionnelle installée |

Puis : fermer Visual Studio, `git add ssas` / `git commit -m "ssas: cube Humanitaire Maroc + calculs + MDX"` / `git push`.
