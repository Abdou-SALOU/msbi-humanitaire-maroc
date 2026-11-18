# Guide Tableau - tableaux de bord

But : 4 tableaux de bord + 1 synthèse, branchés sur le **cube SSAS** (la chaîne demandée par le prof : SSIS -> DW -> SSAS -> Tableau).

**Essai Tableau :** 14 jours à partir du 1er lancement. Ouvert le vendredi 20/11, il dure jusqu'au 4 décembre : assez pour l'oral.

## 1. Connexion au cube (5 min)

Tableau Desktop > Se connecter > À un serveur > **Microsoft Analysis Services** : serveur `localhost`, sécurité intégrée Windows. Base **MSBI_Cube**, cube **Humanitaire Maroc**.

- Si Tableau demande un pilote : installer le **fournisseur OLE DB Microsoft Analysis Services** depuis la page des pilotes de Tableau (lien proposé par le message d'erreur).
- Les mesures calculées du cube (Taux de chômage, Pluie moyenne...) apparaissent comme des mesures normales : **ne pas les recalculer dans Tableau**.

📸 **Capture T1** : l'écran de connexion avec le cube sélectionné.

> À dire : Tableau ne lit pas les tables, il envoie des **requêtes MDX** au cube. Les calculs (taux, moyennes pondérées) sont faits une seule fois dans le cube, et tous les tableaux de bord affichent les mêmes chiffres.

**Limite connue des cubes dans Tableau :** pas de carte automatique (les rôles géographiques ne s'appliquent pas aux dimensions d'un cube). Si vous voulez une carte, ajouter une 2e source directement sur le DW SQL Server (`DW_Humanitaire_Maroc`) et tester si Tableau reconnaît les 12 régions. Sinon, des barres triées suffisent.

## 2. Règles communes (pour que l'assemblage soit propre)

| Élément | Règle |
|---|---|
| Couleurs | Réfugiés = bleu ; Demandeurs d'asile = orange ; Urbain = gris foncé ; Rural = vert ; anomalie de pluie : divergente rouge (sec) - bleu (humide), centrée sur **100** |
| Titres | Une phrase qui dit ce qu'on voit : « La pauvreté a baissé dans les 12 régions entre 2014 et 2024 » plutôt que « Pauvreté par région » |
| Nombres | séparateur de milliers, 1 décimale pour les taux |
| Filtres | Année et Milieu en haut à droite, appliqués à toutes les feuilles du tableau de bord |
| Noms de feuilles | préfixe `R-`, `G-`, `P-`, `C-` selon le tableau de bord (Réfugiés, réGions, Pluie, Conflits) |

## 3. Tableaux de bord d'Abdou

### TdB 1 « Réfugiés et demandeurs d'asile au Maroc »

| Feuille | Colonnes | Lignes | Marques / filtres |
|---|---|---|---|
| `R-Evolution` | Date > Annee | Personnes | Courbe, couleur = Groupe ; filtre Pays Asile = Morocco ; années 2010-2025 |
| `R-Top origines` | Personnes | Pays Origine > Pays (Top 10 par Personnes) | Barres ; filtre Pays Asile = Morocco ; filtre Annee |
| `R-Marocains a l'etranger` | Personnes | Pays Asile > Pays (Top 10) | Barres ; filtre Pays Origine = Morocco ; filtre Annee |
| `R-KPI` | | | Texte : Personnes (2025) et Évolution annuelle personnes |

Message à faire passer : le nombre de personnes accueillies au Maroc a plus que doublé depuis 2019 (9 721 -> 22 337), surtout des demandeurs d'asile venus du Soudan et de Syrie ; dans l'autre sens, les Marocains demandent surtout l'asile en Italie.

### TdB 2 « Régions : pauvreté et emploi »

| Feuille | Construction |
|---|---|
| `G-Pauvrete 2014-2024` | Lignes : Region ; Colonnes : Taux de pauvreté ; Couleur : Annee (2014 gris, 2024 bleu) ; filtre Milieu = Ensemble ; tri par 2024. Variante « haltère » : cercles + ligne entre 2014 et 2024 |
| `G-Chomage urbain rural` | Lignes : Region ; Colonnes : Taux de chômage ; Couleur : Milieu (Urbain / Rural) ; barres côte à côte |
| `G-Etrangers` | Lignes : Region ; Colonnes : Part des étrangers ; barres triées |
| `G-KPI` | Population 2024, Taux de chômage national, Taux de pauvreté moyen 2024 |

Message : la pauvreté a baissé partout ; le chômage reste très élevé dans l'Oriental (30 %) et à Guelmim-Oued Noun (38 % en rural).

## 4. Tableaux de bord d'Esso

### TdB 3 « Pluviométrie »

| Feuille | Construction |
|---|---|
| `P-Anomalie par region et annee` | Carte de chaleur : Lignes Region, Colonnes Annee, Couleur Anomalie pluie (divergente centrée sur 100) |
| `P-Saison` | Courbe : Colonnes Date > Calendrier (mois), Lignes Pluie moyenne et Normale de pluie, filtre Region |
| `P-Classement 2025` | Barres Anomalie pluie par région, filtre Annee = 2025 |

### TdB 4 « Conflits et tensions »

| Feuille | Construction |
|---|---|
| `C-Evenements par an` | Barres empilées : Annee x Événements, couleur Type ; **attention : ne pas sommer les types**, montrer côte à côte ou choisir un type |
| `C-Manifestations par mois` | Courbe mensuelle des manifestations 2020-2026 |
| `C-Morts` | Morts par an (violence politique) |

## 5. Synthèse (ensemble)

Un tableau de bord d'une page avec les 4 chiffres clés et un graphique par thème, chacun cliquable (action de filtre sur l'année).

## 6. Assemblage

Chacun travaille dans son classeur (`tableau/abdou.twb`, `tableau/essorong.twb`). À la fin : ouvrir un classeur, copier les feuilles de l'autre (clic droit > Copier / Coller), puis **Fichier > Enregistrer sous > `tableau/final.twbx`** (format empaqueté).

📸 **Captures T2 à T6** : chaque tableau de bord en plein écran.
