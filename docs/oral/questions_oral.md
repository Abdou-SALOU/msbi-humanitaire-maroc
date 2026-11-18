# Préparation à l'oral - questions probables du Pr Hanine

Le prof interroge **un seul membre** sur **n'importe quelle partie**. Chacun doit savoir répondre à TOUTES ces questions, avec ses mots. Réponses courtes : une idée, un exemple tiré du projet.

## Données et sujet

1. **Pourquoi ce jeu de données ?** Plusieurs fichiers de sources différentes (ONU, HCP, INFORM), de formats différents (CSV, Excel) et récents (recensement 2024) : il faut vraiment nettoyer, fusionner et joindre, ce qui est le cœur d'un ETL.
2. **Quelle question décisionnelle ?** Quelles régions cumulent pauvreté, chômage et déficit de pluie, et comment évoluent les flux de réfugiés.
3. **Quelle difficulté dans les données ?** Exemples : les mêmes régions ont des codes différents selon la source (HCP 1-12, HAPI MA001-MA010) ; le détail par sexe et âge des réfugiés est incomplet ; la pluie existe en 3 périodes qui se chevauchent ; les Excel du HCP ont des en-têtes sur plusieurs lignes.

## Modélisation

4. **Quel schéma et pourquoi ?** Constellation de faits : 5 processus avec des grains différents, qui partagent des dimensions (Date, Région, Milieu).
5. **Différence étoile / flocon / constellation ?** Étoile : 1 fait, dimensions dénormalisées. Flocon : dimensions normalisées en plusieurs tables. Constellation : plusieurs faits qui partagent des dimensions.
6. **Qu'est-ce que le grain ?** Ce que représente UNE ligne de fait. F_Pluie : une décade pour une zone de mesure.
7. **Pourquoi des clés de substitution ?** Indépendantes des codes sources (qui diffèrent selon les fichiers et peuvent changer), entiers courts donc jointures rapides.
8. **Qu'est-ce qu'une dimension à jeux de rôles ?** Une même dimension utilisée deux fois par un fait : D_Pays = pays d'origine ET pays d'asile dans F_Refugies.
9. **Mesure additive, semi-additive, non additive ?** Additive : s'additionne partout (personnes). Non additive : un taux (chômage, pauvreté). Nous convertissons les taux en effectifs pour les rendre additifs, et le cube recalcule le taux.
10. **Pourquoi « pluie x pixels » ?** Pour une moyenne pondérée par la surface : somme(pluie x pixels) / somme(pixels), juste à tous les niveaux.

## ETL (SSIS)

11. **Différence flux de contrôle / flux de données ?** Contrôle : l'ordre des tâches (vider, charger, enchaîner les packages). Données : le chemin des lignes (source -> transformations -> destination).
12. **À quoi sert un Lookup ?** À remplacer un code source par la clé de la dimension (c'est une jointure). Ex. `MA003` -> `region_key`.
13. **Merge Join ou Union All ?** Merge Join juxtapose deux fichiers sur une clé (ajoute des colonnes, entrées triées obligatoires). Union All empile des fichiers de même structure (ajoute des lignes).
14. **Pourquoi un Tri avant le Merge Join ?** Le Merge Join compare les deux entrées dans l'ordre de la clé, comme on fusionne deux listes triées.
15. **Qu'avez-vous nettoyé ?** Filtrage des lignes détail (réfugiés) et des périodes en double (pluie), « None » -> NULL (conflits), NULL conservés (régions sans code HAPI), conversions de types, suppression du milieu « Ensemble » pour éviter le double compte.
16. **Pourquoi « None » devient NULL et pas 0 ?** 0 voudrait dire « zéro mort » ; NULL veut dire « information non applicable ». Le cube ne compte pas les NULL dans les sommes.
17. **Comment évitez-vous les doublons si on relance ?** Chaque package vide sa table de faits avant de la recharger (TRUNCATE) ; le Master vide tout puis recharge dans l'ordre dimensions -> faits.
18. **Comment savez-vous que le chargement est juste ?** Le script `03_controles.sql` compare le DW aux totaux calculés depuis les fichiers (424 489 personnes, 16 872 événements...) ; le taux de chômage recalculé donne 21,3 %, le chiffre officiel du HCP.
19. **Pourquoi les dimensions avant les faits ?** Les faits ont des clés étrangères vers les dimensions et les Lookups ont besoin des clés existantes.

## Cube et MDX (SSAS)

20. **Qu'est-ce qu'un cube OLAP ?** Une structure qui pré-agrège les mesures selon toutes les combinaisons de dimensions, pour répondre vite à des analyses multidimensionnelles.
21. **Qu'est-ce que la DSV ?** La vue de source de données : les tables du DW et leurs relations, vues par SSAS.
22. **Hiérarchie et relations d'attributs ?** Calendrier : Année > Mois > Jour. Les relations (jour -> mois -> année) permettent à SSAS d'agréger efficacement. La clé du mois est (année, mois) sinon tous les « janvier » se confondent.
23. **Membre calculé ?** Une mesure définie par une formule MDX, calculée à la volée : Taux de chômage = Chômeurs / Actifs x 100.
24. **Expliquer une requête MDX** : SELECT ... ON COLUMNS / ON ROWS (les axes), FROM [cube], WHERE (le découpage, ex. une année). TOPCOUNT garde les N premiers ; ORDER trie ; WITH MEMBER crée un calcul pour la requête ; PrevMember = la période précédente.
25. **MOLAP, ROLAP, HOLAP ?** MOLAP : données et agrégations stockées dans le cube (notre cas, le plus rapide). ROLAP : tout reste dans le DW. HOLAP : données dans le DW, agrégations dans le cube.

## Visualisation (Tableau)

26. **Pourquoi brancher Tableau sur le cube et pas sur le DW ?** Les calculs sont faits une seule fois dans le cube, identiques partout ; Tableau envoie des requêtes MDX.
27. **Que montre votre tableau de bord ?** Une phrase par tableau de bord, avec un chiffre : « les personnes accueillies au Maroc sont passées de 9 721 en 2019 à 22 337 en 2025 ».

## Chiffres à connaître par cœur

- 424 489 personnes dans F_Refugies, 2 694 lignes ; 22 337 personnes accueillies au Maroc en 2025 (+18,5 %).
- Pauvreté multidimensionnelle : en baisse dans les 12 régions entre 2014 et 2024 (Marrakech-Safi : 15,8 % -> 7,9 %).
- Chômage 2024 : 21,3 % au niveau national ; 38,2 % en rural à Guelmim-Oued Noun.
- Pluie 2025 : Marrakech-Safi la plus déficitaire (89 % de la normale), Rabat-Salé-Kénitra la plus arrosée (117 %).
- 3 654 manifestations recensées en 2024, le maximum de la période.
