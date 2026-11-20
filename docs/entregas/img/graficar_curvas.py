import json, sys
import matplotlib; matplotlib.use("Agg")
from matplotlib import font_manager
font_manager._load_fontmanager(try_read_cache=False)
import matplotlib.pyplot as plt
c = json.load(open(sys.argv[1])); out = sys.argv[2]
# Paleta de la app (app/lib/tema.dart): granaDeep, cempasuchil, maguey — validada con validate_palette.js
COL = {"v1": "#9E2016", "v2": "#D97706", "v3": "#087A38"}
MK = {"v1": "o", "v2": "s", "v3": "^"}
INK, STONE, LINE = "#201B18", "#59413D", "#E3D8D3"
plt.rcParams.update({"font.family": "Work Sans", "font.size": 9, "axes.spines.top": False, "axes.spines.right": False,
                     "axes.edgecolor": STONE, "axes.labelcolor": STONE, "xtick.color": STONE, "ytick.color": STONE})
fig, ax = plt.subplots(1, 3, figsize=(10, 2.9))
for v, d in c.items():
    ep = sorted(d["por_epoca"], key=int)
    tl = [(int(e) + 1, d["por_epoca"][e]["train_loss_epoch"]) for e in ep if "train_loss_epoch" in d["por_epoca"][e]]
    vl = [(int(e) + 1, d["por_epoca"][e]["val_loss"]) for e in ep]
    vm = list(enumerate(d["val_mAP"][1:], 1))
    for a, s in zip(ax, (tl, vl, vm)):
        a.plot([x for x, _ in s], [y for _, y in s], color=COL[v], lw=2, marker=MK[v], ms=4, label=v,
               markeredgecolor="white", markeredgewidth=0.6)
titles = ("Pérdida de entrenamiento", "Pérdida de validación", "mAP@[.5:.95] de validación")
for a, t in zip(ax, titles):
    a.set_title(t, fontsize=9.5, color=INK, loc="left", fontweight="semibold"); a.set_xlabel("época")
    a.grid(axis="y", color=LINE, lw=0.8); a.set_xticks([1, 3, 6, 9, 12]); a.axvline(10, color="#B8A9A3", lw=0.8, ls=":")
    a.set_xlim(0.5, 13.6)
for v, d in c.items():   # etiqueta directa al final de la curva de mAP
    ax[2].annotate(v, (12, d["val_mAP"][-1]), xytext=(5, {"v1": 6, "v2": 0, "v3": -7}[v]), textcoords="offset points",
                   color=COL[v], fontsize=8, fontweight="semibold", va="center")
ax[0].legend(frameon=False, loc="upper right")
ax[1].text(10.15, ax[1].get_ylim()[1] * 0.97, "lr ×0.1", fontsize=7.5, color=STONE, va="top")
fig.tight_layout(); fig.savefig(f"{out}/curvas_dino.png", dpi=200)
