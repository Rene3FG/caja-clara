"""Construye el engine TensorRT FP16 del detector DINO (Caja Clara) desde el ONNX de TAO.
Uso: python3 construir_engine.py B_modelo.onnx dino_rtx2060_fp16.engine
"""
import hashlib, json, sys, time
import tensorrt as trt

onnx_path, out_path = sys.argv[1], sys.argv[2]
log = trt.Logger(trt.Logger.WARNING)
try:
    trt.init_libnvinfer_plugins(log, "")
except Exception as e:
    print("aviso init plugins:", e)

reg = trt.get_plugin_registry()
creadores = getattr(reg, "all_creators", None) or reg.plugin_creator_list
plugins = [c.name for c in creadores]
print("TensorRT", trt.__version__, "| plugin DINO:",
      "MultiscaleDeformableAttnPlugin_TRT" in plugins)

builder = trt.Builder(log)
net = builder.create_network(0)
parser = trt.OnnxParser(net, log)
with open(onnx_path, "rb") as f:
    if not parser.parse(f.read()):
        for i in range(parser.num_errors):
            print("ERROR ONNX:", parser.get_error(i))
        sys.exit(1)

cfg = builder.create_builder_config()
cfg.set_memory_pool_limit(trt.MemoryPoolType.WORKSPACE, 2 << 30)
try:
    cfg.set_flag(trt.BuilderFlag.FP16)
    precision = "fp16"
except AttributeError:
    print("aviso: esta versión de TensorRT no tiene la bandera FP16; se construye con los tipos del ONNX")
    precision = "tipos_del_onnx"

prof = None
for i in range(net.num_inputs):
    t = net.get_input(i)
    shape = list(t.shape)
    print("entrada:", t.name, shape)
    if -1 in shape:
        prof = prof or builder.create_optimization_profile()
        fijo = [1 if (d == -1 and j == 0) else d for j, d in enumerate(shape)]
        if -1 in fijo:
            sys.exit(f"Dimensión dinámica no soportada en {t.name}: {shape}")
        prof.set_shape(t.name, fijo, fijo, fijo)
if prof:
    cfg.add_optimization_profile(prof)
for i in range(net.num_outputs):
    print("salida:", net.get_output(i).name, list(net.get_output(i).shape))

t0 = time.time()
ser = builder.build_serialized_network(net, cfg)
if ser is None:
    sys.exit("Falló la construcción del engine")
with open(out_path, "wb") as f:
    f.write(ser)
sha = hashlib.sha256(open(out_path, "rb").read()).hexdigest()
info = {"onnx": onnx_path, "engine": out_path, "tensorrt": trt.__version__,
        "precision": precision, "minutos": round((time.time() - t0) / 60, 1),
        "sha256_engine": sha, "fecha": time.strftime("%Y-%m-%d %H:%M:%S")}
json.dump(info, open(out_path + ".json", "w"), indent=2, ensure_ascii=False)
print(json.dumps(info, indent=2, ensure_ascii=False))
