# Plan du livrable (document de captures commentées)

Le prof demande un document avec les **captures d'écran commentées de toutes les étapes**, envoyé 2 à 3 jours avant l'oral (objectif : **lundi 23/11**).
Format : Word, modèle de rapport habituel d'Abdou. Chaque capture : un titre, la capture, 2 à 4 lignes de commentaire (ce qu'on voit + pourquoi ce choix).
Les captures sont rangées dans `docs/captures/` avec leur numéro (ex. `05_F_Refugies_flux.png`).

## 1. Présentation du projet (1 page)

**Sujet :** analyse de la situation humanitaire et socio-économique du Maroc : réfugiés et demandeurs d'asile, conflits et manifestations, pluviométrie, indicateurs du recensement 2024 et pauvreté multidimensionnelle.

**Question décisionnelle :** quelles régions cumulent les vulnérabilités (pauvreté, chômage, sécheresse) et comment évoluent les flux de personnes accueillies au Maroc et de Marocains à l'étranger ?

**Chaîne :** SSIS (ETL) -> SQL Server (Data Warehouse) -> SSAS (cube OLAP, MDX) -> Tableau (tableaux de bord). Schéma de la chaîne en image.

## 2. Les sources de données (1 page)

| Source | Fichier(s) | Contenu | Période |
|---|---|---|---|
| HDX HAPI (OCHA, ONU) | 3 CSV | réfugiés (UNHCR), conflits (ACLED), pluie (WFP) | 1997-2026 |
| HCP, recensement 2024 (RGPH) | 2 Excel | population légale, indicateurs socio-économiques par région et milieu | 2024 |
| HCP, cartographie de la pauvreté (mai 2025) | 1 Excel | pauvreté multidimensionnelle | 2014 et 2024 |
| INFORM Risk 2026 (IASC et Commission européenne, Centre commun de recherche) | 1 Excel | référentiel des pays + score de risque | 2026 |

Commentaire à écrire : plusieurs fichiers de formats différents (CSV et Excel), d'organismes différents, avec des codes différents pour les mêmes régions (HCP 1-12, HAPI MA001-MA010) : il a fallu une table de correspondance et des jointures.

Préparation des Excel (une phrase) : les Excel du HCP sont des tableaux de publication (en-têtes sur plusieurs lignes, arabe et français, plusieurs niveaux géographiques mélangés). Un court script les extrait en CSV simples, sans aucun calcul ; toutes les transformations sont faites dans SSIS.

## 3. Modélisation du Data Warehouse (2 pages)

- **Schéma retenu : constellation de faits** (image : diagramme de la DSV SSAS, capture S2, ou diagramme SSMS).
- **Justification :** 5 processus métier avec des grains différents (un total annuel par couple de pays, un mois par type d'événement, une décade par zone de mesure, une région par milieu) qui partagent des dimensions conformes (Date, Région, Milieu). Une étoile aurait imposé un seul grain ; un flocon n'apporte rien ici (dimensions petites, sans hiérarchie à normaliser).
- Tableau des 5 faits (grain, mesures, dimensions) : reprendre celui du README.
- Choix importants à commenter :
  - **clés de substitution** (IDENTITY) dans les dimensions, indépendantes des codes sources ;
  - **dimension à deux rôles** : D_Pays sert de pays d'origine et de pays d'asile ;
  - **mesures additives** : les taux du HCP sont convertis en effectifs (chômeurs, analphabètes), la pluie est stockée en « pluie x pixels », pour que les totaux soient justes à tout niveau ;
  - **dimension Date** générée par script (1997-2026, avec la décade du mois).
- script `sql/01_creer_dw.sql` dans SSMS, et la liste des 11 tables.

## 4. ETL avec SSIS (4 à 5 pages) - captures 1 à 13 du guide SSIS

Pour chaque package : la capture du flux au vert avec le nombre de lignes, et le commentaire.

| Capture | Commentaire (idée principale) |
|---|---|
| 1-2 | Projet et connexion partagée au DW (gestionnaire de connexions de projet) |
| 3-4 | Dimensions Région et Pays ; NULL conservés pour Laâyoune et Dakhla |
| 5-7 | Réfugiés : 35 022 lignes lues -> 2 694 totaux (le détail sexe/âge est incomplet) ; 3 Lookups dont 2 sur D_Pays |
| 8 | Conflits : « None » transformé en NULL (et non en 0) |
| 9 | Pluie : filtre sur les décades (7 830 -> 2 610) ; pluie x pixels pour la moyenne pondérée |
| 10 | Indicateurs : **fusion de 2 fichiers HCP par Tri + Merge Join**, puis taux -> effectifs |
| 11 | Pauvreté : **fusion de 3 fichiers par Union All**, milieu ajouté par colonne dérivée |
| 12 | Package Master : vidage puis enchaînement (dimensions avant faits) |
| 13 | Contrôles SQL : toutes les vérifications à 1, taux de chômage recalculé = 21,3 % (chiffre officiel) |

## 5. Cube OLAP avec SSAS (3 pages) - captures S1 à S7

Source de données, DSV (constellation), dimension Date (hiérarchie Calendrier, clé composée du mois), utilisation des dimensions (Pays Origine / Pays Asile), mesures et membres calculés (pourquoi un taux est recalculé et jamais additionné), déploiement, navigateur.

## 6. Requêtes MDX (3 pages) - captures S8 à S15

Pour chaque requête : la question métier en une phrase, la requête, le résultat, la notion MDX utilisée (axes, WHERE, TOPCOUNT, ORDER, WITH MEMBER, PrevMember) et l'enseignement (ex. « la pauvreté a baissé dans les 12 régions »).

## 7. Tableaux de bord Tableau (3 pages) - captures T1 à T6

Une capture par tableau de bord + 2 lignes : la question à laquelle il répond et ce qu'il montre.

## 8. Conclusion (1/2 page)

Principaux enseignements chiffrés (3 ou 4), difficultés rencontrées et solutions (codes de régions différents, détail incomplet des réfugiés, chevauchement des périodes de pluie, taux non additifs), améliorations possibles (chargement incrémental, cartographie, mise à jour automatique depuis l'API HAPI).

---

### Rappels de forme

- Rédaction au « nous » (binôme), phrases simples.
- Pas de paragraphe sur les versions des logiciels.
- Une capture = un numéro + un titre + un commentaire. Recadrer les captures sur la partie utile.
- Taille finale < 20 Mo (captures en PNG compressées si besoin).
