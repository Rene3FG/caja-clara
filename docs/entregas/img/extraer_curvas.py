import re, json, sys
L = sys.argv[1]
out = {}
for v in (1, 2, 3):
    t = open(f"{L}/entrenamiento_dino_v{v}.log", errors="replace").read()
    vm = [float(x) for x in re.findall(r"Validation mAP : ([0-9.]+)", t)]
    v50 = [float(x) for x in re.findall(r"Validation mAP50 : ([0-9.]+)", t)]
    # último estado de la barra al 100% por época
    ep = {}
    for m in re.finditer(r"Epoch (\d+): 100%\|[^\]]*\]([^E]*?)(?=Epoch|\Z)", t):
        pass
    for m in re.finditer(r"Epoch (\d+): 100%[^\n]*?val_loss=([0-9.]+)(?:, train_loss_epoch=([0-9.]+))?", t):
        e = int(m.group(1)); ep.setdefault(e, {})["val_loss"] = float(m.group(2))
        if m.group(3): ep[e]["train_loss_epoch"] = float(m.group(3))
    out[f"v{v}"] = {"val_mAP": vm, "val_mAP50": v50, "por_epoca": ep}
    print(v, len(vm), vm[:3], len(ep), {k: ep[k] for k in sorted(ep)[-2:]})
json.dump(out, open(sys.argv[2], "w"), indent=1)
