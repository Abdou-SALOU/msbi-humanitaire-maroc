# Résultats attendus (calculés depuis les fichiers sources)

Généré par `scripts/resultats_attendus.py`. Si le DW ou le cube donne autre chose, un package SSIS ou une mesure du cube est à revoir.

## Contrôles après SSIS (doivent correspondre à sql/03_controles.sql)
| contrôle                                       |   valeur attendue |
|:-----------------------------------------------|------------------:|
| F_Refugies : lignes                            |              2694 |
| F_Refugies : total personnes                   |            424489 |
| F_Conflits : lignes                            |              1074 |
| F_Conflits : total événements                  |             16872 |
| F_Pluie : lignes (décades)                     |              2610 |
| F_Pluie : total pixels                         |           2752854 |
| F_Indicateurs_Region : lignes (Urbain + Rural) |                24 |
| F_Indicateurs_Region : population              |          36828330 |
| F_Indicateurs_Region : chômeurs (calculés)     |           2373842 |
| F_Pauvrete : lignes                            |                72 |

## MDX 1 - Personnes accueillies au Maroc par année et par statut (2019-2025)
|   annee |   Demandeurs d'asile |   Réfugiés |
|--------:|---------------------:|-----------:|
|    2019 |                 3079 |       6642 |
|    2020 |                 7011 |       6505 |
|    2021 |                10956 |       7272 |
|    2022 |                10159 |       7907 |
|    2023 |                11340 |       8295 |
|    2024 |                11378 |       7470 |
|    2025 |                15033 |       7304 |

## MDX 2 - Top 5 des pays d'origine des personnes accueillies au Maroc en 2025
| pays          |   population |
|:--------------|-------------:|
| Sudan         |         5291 |
| Syria         |         5216 |
| Guinea        |         2366 |
| Côte d'Ivoire |         1780 |
| Senegal       |         1584 |

## MDX 3 - Top 5 des pays où des Marocains ont demandé l'asile ou sont réfugiés en 2025
| pays                     |   population |
|:-------------------------|-------------:|
| Italy                    |        13188 |
| Spain                    |         3790 |
| France                   |         2676 |
| Germany                  |         2606 |
| United States of America |         1824 |

## MDX 4 - Pluie moyenne par décade et anomalie par région en 2025
| nom_region                |   Pluie moyenne (mm/décade) |   Anomalie (% de la normale) |
|:--------------------------|----------------------------:|-----------------------------:|
| Marrakech-Safi            |                         7.9 |                         89.4 |
| Guelmim-Oued Noun         |                         3.7 |                         91.9 |
| Béni Mellal-Khénifra      |                        13.0 |                         94.5 |
| Casablanca-Settat         |                         9.5 |                         97.7 |
| Fès-Meknès                |                        11.3 |                         98.2 |
| Oriental                  |                         6.7 |                         98.3 |
| Drâa-Tafilalet            |                         8.4 |                        102.8 |
| Tanger-Tétouan-Al Hoceima |                        23.3 |                        115.1 |
| Rabat-Salé-Kénitra        |                        17.2 |                        116.7 |

## MDX 5 - Taux de chômage par région et milieu (2024) - Maroc entier : 21,3 %
| nom_region                |   Chômage Rural (%) |   Chômage Urbain (%) |
|:--------------------------|--------------------:|---------------------:|
| Béni Mellal-Khénifra      |                25.4 |                 28.0 |
| Casablanca-Settat         |                19.4 |                 18.6 |
| Dakhla-Oued Ed-Dahab      |                 1.2 |                 12.9 |
| Drâa-Tafilalet            |                22.2 |                 22.2 |
| Fès-Meknès                |                23.0 |                 23.4 |
| Guelmim-Oued Noun         |                38.2 |                 29.2 |
| Laâyoune-Sakia El Hamra   |                17.3 |                 26.9 |
| Marrakech-Safi            |                20.3 |                 21.3 |
| Oriental                  |                31.7 |                 29.9 |
| Rabat-Salé-Kénitra        |                18.4 |                 20.2 |
| Souss-Massa               |                19.6 |                 19.8 |
| Tanger-Tétouan-Al Hoceima |                20.3 |                 19.3 |

## MDX 6 - Taux de pauvreté multidimensionnelle par région, 2014 et 2024 (milieu Ensemble)
| nom_region                |   2014 |   2024 |   Évolution (points) |
|:--------------------------|-------:|-------:|---------------------:|
| Marrakech-Safi            |   15.8 |    7.9 |                 -7.9 |
| Béni Mellal-Khénifra      |   17.3 |    9.8 |                 -7.4 |
| Tanger-Tétouan-Al Hoceima |   13.9 |    7.1 |                 -6.8 |
| Drâa-Tafilalet            |   14.4 |    7.7 |                 -6.7 |
| Souss-Massa               |   11.2 |    5.7 |                 -5.5 |
| Guelmim-Oued Noun         |   10.3 |    4.9 |                 -5.4 |
| Oriental                  |   13.5 |    8.4 |                 -5.1 |
| Fès-Meknès                |   13.7 |    9.0 |                 -4.7 |
| Rabat-Salé-Kénitra        |    9.1 |    5.7 |                 -3.3 |
| Casablanca-Settat         |    6.7 |    4.3 |                 -2.3 |
| Dakhla-Oued Ed-Dahab      |    4.5 |    2.5 |                 -1.9 |
| Laâyoune-Sakia El Hamra   |    3.3 |    2.4 |                 -0.9 |

## MDX 7 - Événements de conflit par année et par type (2020-2025)
|   annee |   civilian_targeting |   demonstration |   political_violence |
|--------:|---------------------:|----------------:|---------------------:|
|    2020 |                   12 |            1341 |                   31 |
|    2021 |                   20 |            1583 |                   55 |
|    2022 |                   51 |            1359 |                   84 |
|    2023 |                   33 |            2133 |                   60 |
|    2024 |                   17 |            3654 |                   48 |
|    2025 |                   21 |            2776 |                   50 |
