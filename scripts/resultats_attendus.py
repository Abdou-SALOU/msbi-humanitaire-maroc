"""Calcule, directement depuis les fichiers sources, les résultats que doivent donner
le DW (après SSIS) et les requêtes MDX du cube. Sert de « corrigé » pour vérifier.

Utilisation (depuis la racine du dépôt) :  python scripts/resultats_attendus.py
Sortie : docs/resultats_attendus.md
"""
from pathlib import Path
import pandas as pd

R = Path(__file__).resolve().parent.parent
H, P = R / "data" / "hapi", R / "data" / "prepare"
out = []


def titre(t):
    out.append(f"\n## {t}\n")


def table(df, decimales=1):
    out.append(df.to_markdown(index=False, floatfmt=f".{decimales}f") + "\n")


pays = pd.read_csv(P / "pays.csv", sep=";").set_index("iso3")["nom_pays"]
reg = pd.read_csv(P / "regions.csv", sep=";")

# ---------- Réfugiés (lignes « all / all » seulement) ----------
ref = pd.read_csv(H / "hdx_hapi_refugees_mar.csv")
ref = ref[(ref.gender == "all") & (ref.age_range == "all")].copy()
ref["annee"] = ref.reference_period_start.str[:4].astype(int)

titre("Contrôles après SSIS (doivent correspondre à sql/03_controles.sql)")
con = pd.read_csv(H / "hdx_hapi_conflict_event_mar.csv")
pl = pd.read_csv(H / "hdx_hapi_rainfall_mar.csv")
pl = pl[pl.aggregation_period == "dekad"].copy()
ind = pd.read_csv(P / "hcp_indicateurs_region_2024.csv", sep=";")
leg = pd.read_csv(P / "hcp_population_legale_2024.csv", sep=";")
ind = ind.merge(leg, on=["code_hcp", "milieu"])          # = Merge Join SSIS
ind = ind[ind.milieu != "Ensemble"].copy()                # = Conditional Split
ind["nb_chomeurs"] = (ind.population_active_15_plus * ind.taux_chomage_pct / 100).round()
pv = pd.concat([pd.read_csv(P / f"hcp_pauvrete_{m}.csv", sep=";").assign(milieu=m.capitalize())
                for m in ("ensemble", "urbain", "rural")])  # = Union All SSIS
table(pd.DataFrame([
    ["F_Refugies : lignes", len(ref)], ["F_Refugies : total personnes", ref.population.sum()],
    ["F_Conflits : lignes", len(con)], ["F_Conflits : total événements", con.events.sum()],
    ["F_Pluie : lignes (décades)", len(pl)], ["F_Pluie : total pixels", pl.number_pixels.sum()],
    ["F_Indicateurs_Region : lignes (Urbain + Rural)", len(ind)],
    ["F_Indicateurs_Region : population", ind.population_legale.sum()],
    ["F_Indicateurs_Region : chômeurs (calculés)", int(ind.nb_chomeurs.sum())],
    ["F_Pauvrete : lignes", len(pv)],
], columns=["contrôle", "valeur attendue"]), 0)

# ---------- Requêtes MDX ----------
titre("MDX 1 - Personnes accueillies au Maroc par année et par statut (2019-2025)")
m = ref[(ref.asylum_location_code == "MAR") & (ref.annee >= 2019)]
t = m.pivot_table(index="annee", columns="population_group", values="population", aggfunc="sum", fill_value=0)
t = t.rename(columns={"REF": "Réfugiés", "ASY": "Demandeurs d'asile", "OOC": "Autres (HCR)"}).reset_index()
table(t, 0)

titre("MDX 2 - Top 5 des pays d'origine des personnes accueillies au Maroc en 2025")
m = ref[(ref.asylum_location_code == "MAR") & (ref.annee == 2025)]
t = m.groupby("origin_location_code").population.sum().nlargest(5).reset_index()
t["pays"] = t.origin_location_code.map(pays)
table(t[["pays", "population"]], 0)

titre("MDX 3 - Top 5 des pays où des Marocains ont demandé l'asile ou sont réfugiés en 2025")
m = ref[(ref.origin_location_code == "MAR") & (ref.annee == 2025)]
t = m.groupby("asylum_location_code").population.sum().nlargest(5).reset_index()
t["pays"] = t.asylum_location_code.map(pays)
table(t[["pays", "population"]], 0)

titre("MDX 4 - Pluie moyenne par décade et anomalie par région en 2025")
m = pl[pl.reference_period_start.str[:4] == "2025"].copy()
m["px_r"], m["px_lt"] = m.rainfall * m.number_pixels, m.rainfall_long_term_average * m.number_pixels
g = m.groupby("admin1_code")[["px_r", "px_lt", "number_pixels"]].sum()
g["Pluie moyenne (mm/décade)"] = g.px_r / g.number_pixels
g["Anomalie (% de la normale)"] = 100 * g.px_r / g.px_lt
g = g.join(reg.set_index("code_hapi")["nom_region"]).sort_values("Anomalie (% de la normale)")
table(g[["nom_region", "Pluie moyenne (mm/décade)", "Anomalie (% de la normale)"]].reset_index(drop=True), 1)

titre("MDX 5 - Taux de chômage par région et milieu (2024) - Maroc entier : 21,3 %")
g = ind.groupby(["code_hcp", "milieu"])[["nb_chomeurs", "population_active_15_plus",
                                          "population_etrangere", "population_legale"]].sum()
g["Taux de chômage (%)"] = 100 * g.nb_chomeurs / g.population_active_15_plus
g["Part des étrangers (%)"] = 100 * g.population_etrangere / g.population_legale
g = g.reset_index().merge(reg[["code_hcp", "nom_region"]])
t = g.pivot_table(index="nom_region", columns="milieu", values=["Taux de chômage (%)"]).round(1)
t.columns = [f"Chômage {b} (%)" for _, b in t.columns]
table(t.reset_index(), 1)

titre("MDX 6 - Taux de pauvreté multidimensionnelle par région, 2014 et 2024 (milieu Ensemble)")
m = pv[pv.milieu == "Ensemble"].merge(reg[["code_hcp", "nom_region"]])
t = m.pivot_table(index="nom_region", columns="annee", values="taux_pauvrete_pct").reset_index()
t["Évolution (points)"] = t[2024] - t[2014]
table(t.sort_values("Évolution (points)"), 1)

titre("MDX 7 - Événements de conflit par année et par type (2020-2025)")
con["annee"] = con.reference_period_start.str[:4].astype(int)
t = con[con.annee.between(2020, 2025)].pivot_table(index="annee", columns="event_type",
                                                    values="events", aggfunc="sum").reset_index()
table(t, 0)

(R / "docs").mkdir(exist_ok=True)
(R / "docs" / "resultats_attendus.md").write_text(
    "# Résultats attendus (calculés depuis les fichiers sources)\n\n"
    "Généré par `scripts/resultats_attendus.py`. Si le DW ou le cube donne autre chose, "
    "un package SSIS ou une mesure du cube est à revoir.\n" + "".join(out), encoding="utf-8")
print("docs/resultats_attendus.md écrit")
