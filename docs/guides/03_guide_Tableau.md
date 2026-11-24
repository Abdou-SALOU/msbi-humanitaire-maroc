# Guide Tableau - tableaux de bord

But : 4 tableaux de bord + 1 synthèse, branchés sur le **cube SSAS** (la chaîne demandée par le prof : SSIS -> DW -> SSAS -> Tableau).

**Essai Tableau :** 14 jours à partir du 1er lancement. Ouvert le vendredi 20/11, il dure jusqu'au 4 décembre : assez pour l'oral.

## 1. Connexion au cube (5 min)

Tableau Desktop > Se connecter > À un serveur > **Microsoft Analysis Services** : serveur `localhost`, sécurité intégrée Windows. Base **MSBI_Cube**, cube **Humanitaire Maroc**.

- Si Tableau demande un pilote : installer le **fournisseur OLE DB Microsoft Analysis Services** depuis la page des pilotes de Tableau (lien proposé par le message d'erreur).
- Les mesures calculées du cube (Taux de chômage, Pluie moyenne...) apparaissent comme des mesures normales : **ne pas les recalculer dans Tableau**.

**Capture T1** : l'écran de connexion avec le cube sélectionné.

> À dire : Tableau ne lit pas les tables, il envoie des **requêtes MDX** au cube. Les calculs (taux, moyennes pondérées) sont faits une seule fois dans le cube, et tous les tableaux de bord affichent les mêmes chiffres.

**Limites des sources de type cube dans Tableau :** pas d'extraits, pas d'expressions LOD, de courbes de tendance, de prévisions ni de clusters, et les hiérarchies doivent être définies dans le cube. Pour une carte, ajouter une 2e source directement sur le DW SQL Server (`DW_Humanitaire_Maroc`) et tester si Tableau reconnaît les 12 régions. Sinon, des barres triées suffisent.

## 2. Règles communes (pour que l'assemblage soit propre)

| Élément | Règle |
|---|---|
| Couleurs | Réfugiés = bleu ; Demandeurs d'asile = orange ; Urbain = gris foncé ; Rural = vert ; anomalie de pluie : divergente rouge (sec) - bleu (humide), centrée sur **100** |
| Titres | Une phrase qui dit ce qu'on voit : « La pauvreté a baissé dans les 12 régions entre 2014 et 2024 » plutôt que « Pauvreté par région » |
| Nombres | séparateur de milliers, 1 décimale pour les taux |
| Filtres | Année et Milieu en haut à droite, appliqués à toutes les feuilles du tableau de bord |
| Noms de feuilles | préfixe `R-`, `G-`, `P-`, `C-` selon le tableau de bord (Réfugiés, réGions, Pluie, Conflits) |

## 3. Réfugiés et régions

### TdB 1 « Réfugiés et demandeurs d'asile au Maroc »

| Feuille | Colonnes | Lignes | Marques / filtres |
|---|---|---|---|
| `R-Evolution` | Date > Annee | Personnes | Courbe, couleur = Groupe Key ; filtre Pays Asile = Morocco ; années 2010-2025 |
| `R-Top origines` | Personnes | Pays Origine > Pays Key (tri décroissant) | Barres ; filtre Pays Asile = Morocco ; filtre Annee |
| `R-Marocains à l'étranger` | Personnes | Pays Asile > Pays Key (tri décroissant) | Barres ; filtre Pays Origine = Morocco ; filtre Annee |
| `R-KPI` | | | Texte : Personnes (2025) et Évolution annuelle personnes |

Message à faire passer : le nombre de personnes accueillies au Maroc a plus que doublé depuis 2019 (9 721 -> 22 337), surtout des demandeurs d'asile venus du Soudan et de Syrie ; dans l'autre sens, les Marocains demandent surtout l'asile en Italie.

### TdB 2 « Régions : pauvreté et emploi »

| Feuille | Construction |
|---|---|
| `G-Pauvreté` | Lignes : Region Key, Annee ; Colonnes : Taux de pauvreté ; Couleur : Annee (2014 gris, 2024 bleu) ; filtre Milieu = Ensemble ; tri par 2024. Variante « haltère » : cercles + ligne entre 2014 et 2024 |
| `G-Chômage urbain rural` | Lignes : Region Key, Milieu Key ; Colonnes : Taux de chômage ; Couleur : Milieu Key (Urbain / Rural) ; barres côte à côte |
| `G-Étrangers` | Lignes : Region Key ; Colonnes : Part des étrangers ; barres triées |
| `G-KPI` | Population 2024, Taux de chômage national, Taux de pauvreté moyen 2024 |

Message : la pauvreté a baissé partout ; le chômage reste très élevé dans l'Oriental (30 %) et à Guelmim-Oued Noun (38 % en rural).

## 4. Pluie et conflits

### TdB 3 « Pluviométrie »

| Feuille | Construction |
|---|---|
| `P-Anomalie` | Carte de chaleur : Lignes Region Key, Colonnes Annee, Couleur Anomalie pluie (divergente centrée sur 100) |
| `P-Saison` | Courbe : Colonnes Date > Calendrier (mois), Lignes Pluie moyenne et Normale de pluie, filtre Annee = 2025 |
| `P-Classement` | Barres Anomalie pluie par région, filtre Annee = 2025, tri croissant |

Pourquoi 2025 : dernière année avec 12 mois de pluie (2026 s'arrête en octobre).

### TdB 4 « Conflits et tensions »

| Feuille | Construction |
|---|---|
| `C-Evenements par an` | Barres empilées : Annee x Événements, couleur Type Key ; **attention : ne pas sommer les types**, montrer côte à côte ou choisir un type |
| `C-Manifestations par mois` | Courbe mensuelle des manifestations 2020-2026 |
| `C-Morts` | Morts par an (violence politique) |

## 5. Assemblage

Classeur final : `tableau/Humanitaire_Maroc_Tableau.twb` (14 feuilles, 4 tableaux de bord : TdB Réfugiés, TdB Régions, TdB Pluie, TdB Conflits), connecté en direct au cube `Humanitaire Maroc` sur `localhost`.

**Captures T2 à T6** : chaque tableau de bord en plein écran.
