"""Prépare les fichiers Excel du HCP et d'INFORM en CSV simples pour SSIS.

Ce script ne fait QUE de l'extraction (Excel de publication -> tableau à une
ligne d'en-tête). Il ne calcule rien : les filtres, les recherches de clés et
les colonnes calculées sont faits dans SSIS.

Utilisation (depuis la racine du dépôt) :
    python scripts/preparer_donnees.py

Sorties dans data/prepare/ (séparateur « ; », UTF-8, décimales avec un point) :
    regions.csv                     12 régions, code HCP + code HAPI
    pays.csv                        191 pays (nom + score de risque INFORM 2026)
    hcp_indicateurs_region_2024.csv 12 régions x milieu (Ensemble, Urbain, Rural)
    hcp_pauvrete_region.csv         12 régions x milieu x année (2014, 2024)
"""
from pathlib import Path
import warnings

import pandas as pd

warnings.filterwarnings("ignore")  # avertissements de mise en forme d'openpyxl

RACINE = Path(__file__).resolve().parent.parent
HCP = RACINE / "data" / "hcp"
INFORM = RACINE / "data" / "inform" / "inform_risk_2026_v072.xlsx"
SORTIE = RACINE / "data" / "prepare"

# Correspondance vérifiée à la main : codes HCP (1-12) <-> codes HAPI (MA001-MA010).
# Laâyoune et Dakhla n'ont pas de code dans les fichiers HAPI.
REGIONS = [
    (1, "Tanger-Tétouan-Al Hoceima", "MA010", "Tangier Tetouan Al Hoceima"),
    (2, "Oriental", "MA007", "Oriental"),
    (3, "Fès-Meknès", "MA004", "Fez Meknes"),
    (4, "Rabat-Salé-Kénitra", "MA008", "Rabat Sale Kenitra"),
    (5, "Béni Mellal-Khénifra", "MA001", "Beni Mellal Khenifra"),
    (6, "Casablanca-Settat", "MA002", "Casablanca Settat"),
    (7, "Marrakech-Safi", "MA006", "Marrakech Safi"),
    (8, "Drâa-Tafilalet", "MA003", "Draa Tafilalet"),
    (9, "Souss-Massa", "MA009", "Souss Massa"),
    (10, "Guelmim-Oued Noun", "MA005", "Guelmim Oued Noun"),
    (11, "Laâyoune-Sakia El Hamra", None, None),
    (12, "Dakhla-Oued Ed-Dahab", None, None),
]

# Feuilles du fichier « Indicateurs » : une par milieu de résidence
FEUILLES_MILIEU = {
    "Ensemble": ("Population", "Ménages"),
    "Urbain": ("Population_Urbaine", "Ménages_Urbains"),
    "Rural": ("Population_Rurale", "Ménages_Ruraux"),
}

# Colonnes retenues dans les feuilles Population* (bloc « Sexe : Ensemble »)
# Indice de colonne -> nom dans le CSV. Vérifiées le 17/11/2026.
COLONNES_INDICATEURS = {
    2: "population_legale",
    22: "population_15_ans_plus",
    30: "taux_handicap_pct",
    32: "taux_scolarisation_6_11_pct",
    33: "population_10_ans_plus",
    34: "taux_analphabetisme_10_plus_pct",
    54: "population_active_15_plus",
    56: "taux_activite_pct",
    57: "taux_chomage_pct",
}


def code_region(serie):
    """Code géographique HCP (texte ou nombre) -> entier, ou None."""
    return pd.to_numeric(serie, errors="coerce")


def ecrire(df, nom):
    chemin = SORTIE / nom
    df.to_csv(chemin, sep=";", index=False, encoding="utf-8")
    print(f"{nom:36s} {len(df):5d} lignes")


def preparer_regions():
    df = pd.DataFrame(REGIONS, columns=["code_hcp", "nom_region", "code_hapi", "nom_hapi"])
    ecrire(df, "regions.csv")


def preparer_pays():
    brut = pd.read_excel(INFORM, sheet_name="INFORM Risk 2026 (a-z)", header=None, skiprows=3)
    df = brut[[1, 0, 2, 3, 4]].copy()
    df.columns = ["iso3", "nom_pays", "inform_risque_2026", "inform_classe_risque", "inform_rang"]
    df = df[df["iso3"].astype("string").str.fullmatch(r"[A-Z]{3}", na=False)]
    ecrire(df, "pays.csv")


def preparer_indicateurs():
    fichier = HCP / "hcp_indicateurs_rgph_2024.xlsx"
    legale = pd.read_excel(HCP / "hcp_population_legale_2024.xlsx", header=None)
    lignes = []
    for milieu, (f_pop, f_men) in FEUILLES_MILIEU.items():
        pop = pd.read_excel(fichier, sheet_name=f_pop, header=None)
        men = pd.read_excel(fichier, sheet_name=f_men, header=None)
        pop["code"] = code_region(pop[0])
        men["code"] = code_region(men[0])
        pop = pop[pop["code"].between(1, 12)]
        men = men[men["code"].between(1, 12)].set_index("code")

        # Population légale : Marocains / Étrangers, une ligne par région et par milieu
        suffixe = {"Ensemble": "", "Urbain": "(milieu urbain)", "Rural": "(milieu rural)"}[milieu]
        lib = legale[0].astype("string")
        leg = legale[code_region(legale[6]).between(1, 12) & lib.str.startswith("Région")]
        leg = leg[lib.str.endswith(suffixe)] if suffixe else leg[~lib.str.contains("milieu", na=False)]
        # Le fichier répète les régions dans plusieurs tableaux (valeurs identiques) : on garde la 1re
        leg = leg.assign(code=code_region(leg[6])).drop_duplicates("code").set_index("code")

        for _, r in pop.iterrows():
            c = int(r["code"])
            ligne = {"code_hcp": c, "milieu": milieu, "annee": 2024}
            for i, nom in COLONNES_INDICATEURS.items():
                ligne[nom] = r[i]
            ligne["nb_menages"] = men.loc[c, 3]
            ligne["population_marocaine"] = leg.loc[c, 1]
            ligne["population_etrangere"] = leg.loc[c, 2]
            lignes.append(ligne)
    df = pd.DataFrame(lignes)

    # Contrôle : Urbain + Rural = Ensemble pour la population légale
    piv = df.pivot(index="code_hcp", columns="milieu", values="population_legale")
    assert (piv["Urbain"] + piv["Rural"] == piv["Ensemble"]).all(), "Urbain + Rural != Ensemble"
    assert (df["population_marocaine"] + df["population_etrangere"] == df["population_legale"]).all()
    ecrire(df, "hcp_indicateurs_region_2024.csv")


def preparer_pauvrete():
    fichier = HCP / "hcp_pauvrete_multidimensionnelle_2014_2024.xls"
    morceaux = []
    for milieu, feuille in [("Ensemble", "Ensemble"), ("Urbain", "Urbain"), ("Rural", "Rural")]:
        brut = pd.read_excel(fichier, sheet_name=feuille, header=None, skiprows=6)
        brut = brut[brut[2] == "région"]
        df = pd.DataFrame({
            "code_hcp": code_region(brut[1]).astype(int),
            "milieu": milieu,
            "annee": brut[3].astype(int),
            "indice_pauvrete_multidim": brut[4],
            "taux_pauvrete_pct": brut[5],
            "intensite_pauvrete_pct": brut[6],
            "taux_vulnerabilite_pct": brut[7],
        })
        morceaux.append(df)
    df = pd.concat(morceaux, ignore_index=True)
    assert len(df) == 12 * 3 * 2, f"{len(df)} lignes au lieu de 72"
    ecrire(df, "hcp_pauvrete_region.csv")


if __name__ == "__main__":
    SORTIE.mkdir(parents=True, exist_ok=True)
    preparer_regions()
    preparer_pays()
    preparer_indicateurs()
    preparer_pauvrete()
