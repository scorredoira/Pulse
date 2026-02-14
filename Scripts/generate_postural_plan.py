#!/usr/bin/env python3
"""
Generate postural_routines.json with embedded Base64 images.

Usage:
    python3 Scripts/generate_postural_plan.py

Output:
    Scripts/postural_routines.json
"""

import base64
import json
import os
import sys
import urllib.request

LOCAL_IMG_DIR = os.path.expanduser("~/Documents/post/img")
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "postural_routines.json")

# Cache downloaded images to avoid re-downloading
CACHE_DIR = os.path.join(os.path.dirname(__file__), ".img_cache")


def load_local_image(filename: str) -> str:
    path = os.path.join(LOCAL_IMG_DIR, filename)
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


def download_image(url: str) -> str:
    os.makedirs(CACHE_DIR, exist_ok=True)
    cache_key = base64.urlsafe_b64encode(url.encode()).decode("ascii")[:80]
    cache_path = os.path.join(CACHE_DIR, cache_key)

    if os.path.exists(cache_path):
        with open(cache_path, "rb") as f:
            return base64.b64encode(f.read()).decode("ascii")

    print(f"  Downloading: {url[:80]}...")
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
    })
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = resp.read()
        with open(cache_path, "wb") as f:
            f.write(data)
        return base64.b64encode(data).decode("ascii")
    except Exception as e:
        print(f"  WARNING: Failed to download {url}: {e}")
        return ""


def img(source: str) -> list:
    """Return a list with one Base64-encoded image string."""
    if source.startswith("http"):
        b64 = download_image(source)
    else:
        b64 = load_local_image(source)
    return [b64] if b64 else []


def exercise(name, sort_order, duration_seconds=0, description="", icon="figure.walk",
             sets=1, rest_seconds=15, rest_after_seconds=30, images=None,
             reps=0, seconds_per_rep=5):
    return {
        "name": name,
        "durationSeconds": duration_seconds,
        "description": description,
        "iconName": icon,
        "sortOrder": sort_order,
        "sets": sets,
        "restSeconds": rest_seconds if sets > 1 else 0,
        "restAfterSeconds": rest_after_seconds,
        "images": images or [],
        "reps": reps if reps > 0 else None,
        "secondsPerRep": seconds_per_rep if reps > 0 else None,
    }


def build_routines():
    print("Building postural plan routines...")

    # ===================== FASE 1 =====================
    fase1 = {
        "name": "Fase 1 - Movilidad y activacion",
        "isDefault": False,
        "intervalMinutes": 45,
        "isActive": False,
        "exercises": [
            exercise(
                "Foam roller toracico", 0,
                duration_seconds=120,
                description="Apoya la parte alta de la espalda sobre el rodillo (de la mitad de la espalda hasta los omoplatos). Brazos cruzados sobre el pecho. Rueda lentamente arriba y abajo.",
                icon="figure.cooldown",
                images=img("7753-m-crop.png"),
                rest_after_seconds=15,
            ),
            exercise(
                "Estiramiento flexores de cadera", 1,
                duration_seconds=45,
                description="Rodilla trasera en el suelo. Pie delantero a 90 grados. Aprieta gluteo del lado trasero y avanza la cadera hacia delante. No arquees la lumbar.",
                icon="figure.flexibility",
                sets=3, rest_seconds=10, rest_after_seconds=15,
                images=img("https://spotebi.com/wp-content/uploads/2015/03/hip-flexor-stretch-exercise-illustration.jpg"),
            ),
            exercise(
                "Estiramiento pectoral en puerta", 2,
                duration_seconds=30,
                description="De pie en marco de puerta. Antebrazos en los laterales con codos a 90 grados. Avanza un pie y deja que el torso pase entre los brazos.",
                icon="figure.flexibility",
                sets=3, rest_seconds=10, rest_after_seconds=15,
                images=img("https://spotebi.com/wp-content/uploads/2015/06/chest-stretch-exercise-illustration.jpg"),
            ),
            exercise(
                "Chin tucks (retraccion cervical)", 3,
                description="De pie contra la pared. Lleva la barbilla hacia atras como si hicieras doble papada. Manten 5 segundos cada repeticion.",
                icon="figure.cooldown",
                sets=3, rest_seconds=15, rest_after_seconds=15,
                reps=10, seconds_per_rep=5,
                images=img("https://www.shutterstock.com/image-vector/chin-tuck-head-text-neck-600nw-2158119513.jpg"),
            ),
            exercise(
                "Cat-cow", 4,
                description="En cuadrupedia. Inspira arqueando la espalda (cow). Espira redondeando la espalda (cat). Movimiento lento sincronizado con la respiracion.",
                icon="figure.flexibility",
                sets=2, rest_seconds=15, rest_after_seconds=15,
                reps=10, seconds_per_rep=6,
                images=img("https://spotebi.com/wp-content/uploads/2014/10/cat-back-stretch-exercise-illustration.jpg"),
            ),
            exercise(
                "Glute bridge", 5,
                description="Tumbado boca arriba, pies apoyados. Empuja con talones para levantar la cadera. Aprieta gluteos arriba 3 segundos. Baja controladamente.",
                icon="figure.strengthtraining.functional",
                sets=3, rest_seconds=15, rest_after_seconds=15,
                reps=15, seconds_per_rep=5,
                images=img("https://spotebi.com/wp-content/uploads/2015/01/glute-bridge-exercise-illustration.jpg"),
            ),
            exercise(
                "Dead bug", 6,
                description="Tumbado boca arriba, brazos al techo, rodillas a 90 grados. Extiende un brazo y la pierna contraria lentamente. La espalda baja pegada al suelo.",
                icon="figure.core.training",
                sets=3, rest_seconds=15, rest_after_seconds=15,
                reps=8, seconds_per_rep=6,
                images=img("https://spotebi.com/wp-content/uploads/2015/05/dead-bug-exercise-illustration.jpg"),
            ),
            exercise(
                "Band pull-apart", 7,
                description="De pie, banda elastica a la altura del pecho con brazos extendidos. Separa las manos apretando las escapulas. Manten 2 segundos.",
                icon="figure.strengthtraining.functional",
                sets=3, rest_seconds=15, rest_after_seconds=15,
                reps=15, seconds_per_rep=4,
                images=img("https://spotebi.com/wp-content/uploads/2017/11/resistance-band-mid-back-pull-exercise-illustration-spotebi.jpg"),
            ),
            exercise(
                "Wall slides", 8,
                description="De pie con espalda, cabeza, codos y munecas contra la pared. Posicion W, sube a Y deslizando por la pared. Baja controladamente.",
                icon="figure.cooldown",
                sets=3, rest_seconds=15, rest_after_seconds=0,
                reps=10, seconds_per_rep=5,
                images=img("10249-m-crop.png"),
            ),
        ],
    }

    # ===================== FASE 2 DIA A =====================
    fase2_a = {
        "name": "Fase 2 - Dia A (Cadena posterior)",
        "isDefault": False,
        "intervalMinutes": 45,
        "isActive": False,
        "exercises": [
            exercise(
                "Hip thrust con carga", 0,
                description="Espalda alta en banco. Barra sobre cadera. Empuja con talones, aprieta gluteos arriba 2 segundos. No hiperextiendas la lumbar.",
                icon="figure.strengthtraining.functional",
                sets=4, rest_seconds=60, rest_after_seconds=60,
                reps=12, seconds_per_rep=5,
                images=img("6548-m-crop.png"),
            ),
            exercise(
                "Peso muerto rumano (mancuernas)", 1,
                description="De pie con mancuernas. Empuja caderas hacia atras manteniendo espalda neutra. Baja hasta sentir estiramiento en isquiotibiales. Vuelve apretando gluteos.",
                icon="figure.strengthtraining.functional",
                sets=4, rest_seconds=60, rest_after_seconds=60,
                reps=10, seconds_per_rep=5,
                images=img("https://spotebi.com/wp-content/uploads/2015/05/romanian-deadlift-exercise-illustration.jpg"),
            ),
            exercise(
                "Pallof press", 2,
                description="De pie perpendicular al punto de anclaje. Extiende brazos al frente resistiendo la rotacion. Manten 2 segundos con brazos extendidos.",
                icon="figure.core.training",
                sets=3, rest_seconds=45, rest_after_seconds=60,
                reps=10, seconds_per_rep=5,
                images=img("9377-m-crop.png"),
            ),
            exercise(
                "Face pull", 3,
                description="Polea alta con cuerda. Tira hacia la cara con codos altos. Rota externamente los hombros separando la cuerda. Aprieta escapulas 2 segundos.",
                icon="figure.strengthtraining.functional",
                sets=4, rest_seconds=45, rest_after_seconds=60,
                reps=15, seconds_per_rep=4,
                images=img("2652-m-crop.png"),
            ),
            exercise(
                "Pull-ups", 4,
                description="Agarre prono. Inicia deprimiendo escapulas antes de doblar codos. Sube hasta que la barbilla pase la barra. Baja controlado 3 segundos.",
                icon="figure.strengthtraining.functional",
                sets=3, rest_seconds=90, rest_after_seconds=0,
                reps=8, seconds_per_rep=6,
                images=img("1157-m-crop.png"),
            ),
        ],
    }

    # ===================== FASE 2 DIA B =====================
    fase2_b = {
        "name": "Fase 2 - Dia B (Cadena anterior)",
        "isDefault": False,
        "intervalMinutes": 45,
        "isActive": False,
        "exercises": [
            exercise(
                "Sentadilla goblet", 0,
                description="Mancuerna al pecho. Pies mas anchos que hombros. Baja controlando, rodillas hacia fuera. Sube empujando con talones.",
                icon="figure.strengthtraining.functional",
                sets=4, rest_seconds=60, rest_after_seconds=60,
                reps=12, seconds_per_rep=5,
                images=img("1735-m-crop.png"),
            ),
            exercise(
                "Push-up con protraction", 1,
                description="Flexion normal. Al llegar arriba, empuja EXTRA redondeando la espalda alta y separando omoplatos. Activa el serrato anterior.",
                icon="figure.strengthtraining.functional",
                sets=3, rest_seconds=60, rest_after_seconds=60,
                reps=12, seconds_per_rep=4,
                images=img("https://spotebi.com/wp-content/uploads/2014/10/push-up-exercise-illustration.jpg"),
            ),
            exercise(
                "Remo con cable", 2,
                description="Sentado en maquina de remo. Agarre neutro. Tira codos hacia atras juntando escapulas. Torso erguido. Excentrica 2-3 segundos.",
                icon="figure.strengthtraining.functional",
                sets=3, rest_seconds=60, rest_after_seconds=60,
                reps=15, seconds_per_rep=4,
                images=img("1729-m-crop.png"),
            ),
            exercise(
                "Bird-dog", 3,
                description="En cuadrupedia. Extiende un brazo al frente y pierna contraria hacia atras. Manten 3 segundos con espalda plana. Alterna.",
                icon="figure.core.training",
                sets=3, rest_seconds=30, rest_after_seconds=60,
                reps=10, seconds_per_rep=6,
                images=img("https://spotebi.com/wp-content/uploads/2014/10/bird-dogs-exercise-illustration.jpg"),
            ),
            exercise(
                "Plancha lateral", 4,
                duration_seconds=25,
                description="Apoyado sobre antebrazo y lateral del pie. Cuerpo en linea recta. No dejes caer la cadera. Manten respirando normalmente.",
                icon="figure.core.training",
                sets=3, rest_seconds=30, rest_after_seconds=60,
                images=img("https://spotebi.com/wp-content/uploads/2014/10/side-plank-exercise-illustration.jpg"),
            ),
            exercise(
                "YTW en prono", 5,
                description="Tumbado boca abajo. Forma Y (brazos al frente), T (brazos a los lados), W (codos flexionados con rotacion externa). Sin peso al principio.",
                icon="figure.strengthtraining.functional",
                sets=3, rest_seconds=45, rest_after_seconds=60,
                reps=8, seconds_per_rep=5,
                images=img("https://assets.caliverse.app/eyJidWNrZXQiOiJjYWxpc3RoZW5pY3MtaGFubmliYWwiLCJrZXkiOiJpbWFnZXNcL2V4ZXJjaXNlc1wvLTYxZjkxYTUyZWQwMmEucG5nIiwiZWRpdHMiOnsicmVzaXplIjp7IndpZHRoIjozNTAsImhlaWdodCI6MzUwLCJmaXQiOiJjb3ZlciJ9fX0="),
            ),
            exercise(
                "Flexiones cervicales profundas", 6,
                description="Tumbado boca arriba. Gesto suave de asentir con la barbilla hacia el pecho sin levantar la cabeza del suelo. Manten 10 segundos.",
                icon="figure.cooldown",
                sets=3, rest_seconds=15, rest_after_seconds=60,
                reps=12, seconds_per_rep=10,
                images=img("https://static1.squarespace.com/static/5f5e8592d2b0854b18af6975/5fb7c850d4788b5df8d8af32/5fb924738aa7f2271d70b581/1687452938720/Supine+Chin+Tuck.jpg?format=1500w"),
            ),
            exercise(
                "Extension toracica con fitball", 7,
                duration_seconds=38,
                description="Siéntate delante del fitball. Apoya espalda alta sobre la pelota. Lleva brazos por encima de la cabeza y dejate caer hacia atras. Respira profundo.",
                icon="figure.flexibility",
                sets=3, rest_seconds=15, rest_after_seconds=0,
                images=img("https://deporteyconsciencia.com/wp-content/uploads/2020/06/Estiramiento-con-fitball.jpg"),
            ),
        ],
    }

    # ===================== FASE 2 MOVILIDAD DIARIA =====================
    fase2_mob = {
        "name": "Fase 2 - Movilidad diaria",
        "isDefault": False,
        "intervalMinutes": 45,
        "isActive": False,
        "exercises": [
            exercise(
                "Foam roller toracico", 0,
                duration_seconds=120,
                description="Rodillo en zona toracica. Rueda lentamente. En puntos tensos, haz 3-4 extensiones.",
                icon="figure.cooldown",
                images=img("7753-m-crop.png"),
                rest_after_seconds=10,
            ),
            exercise(
                "Estiramiento flexores de cadera", 1,
                duration_seconds=45,
                description="Rodilla trasera en el suelo. Avanza cadera hacia delante apretando gluteo trasero. No arquees lumbar.",
                icon="figure.flexibility",
                rest_after_seconds=10,
                images=img("https://spotebi.com/wp-content/uploads/2015/03/hip-flexor-stretch-exercise-illustration.jpg"),
            ),
            exercise(
                "Estiramiento pectoral en puerta", 2,
                duration_seconds=30,
                description="Marco de puerta, antebrazos en laterales, codos a 90 grados. Avanza torso.",
                icon="figure.flexibility",
                rest_after_seconds=10,
                images=img("https://spotebi.com/wp-content/uploads/2015/06/chest-stretch-exercise-illustration.jpg"),
            ),
            exercise(
                "Chin tucks", 3,
                description="De pie o sentado. Lleva barbilla hacia atras. Manten 5 segundos.",
                icon="figure.cooldown",
                reps=10, seconds_per_rep=5,
                rest_after_seconds=10,
                images=img("https://www.shutterstock.com/image-vector/chin-tuck-head-text-neck-600nw-2158119513.jpg"),
            ),
            exercise(
                "Rotacion toracica", 4,
                description="En cuadrupedia. Mano en la nuca. Rota abriendo el codo al techo. Alterna lados.",
                icon="figure.flexibility",
                reps=10, seconds_per_rep=5,
                rest_after_seconds=0,
            ),
        ],
    }

    # ===================== FASE 3 DIA A =====================
    fase3_a = {
        "name": "Fase 3 - Dia A (Cadena posterior)",
        "isDefault": False,
        "intervalMinutes": 45,
        "isActive": False,
        "exercises": [
            exercise(
                "Peso muerto rumano con barra", 0,
                description="Progresion a barra. Mismo patron de bisagra. Agarre prono o mixto. Baja hasta media espinilla. Espalda neutra.",
                icon="figure.strengthtraining.functional",
                sets=4, rest_seconds=90, rest_after_seconds=60,
                reps=10, seconds_per_rep=5,
                images=img("https://spotebi.com/wp-content/uploads/2015/05/romanian-deadlift-exercise-illustration.jpg"),
            ),
            exercise(
                "Hip thrust con barra", 1,
                description="Mas carga que Fase 2. Pausa de 2 segundos arriba. Objetivo: llegar a peso corporal en barra.",
                icon="figure.strengthtraining.functional",
                sets=4, rest_seconds=90, rest_after_seconds=60,
                reps=10, seconds_per_rep=5,
                images=img("6548-m-crop.png"),
            ),
            exercise(
                "Pallof press rotacional", 2,
                description="Mismo Pallof press pero al extender brazos anade rotacion controlada del torso alejandote del punto de anclaje.",
                icon="figure.core.training",
                sets=3, rest_seconds=45, rest_after_seconds=60,
                reps=10, seconds_per_rep=5,
                images=img("9377-m-crop.png"),
            ),
            exercise(
                "Face pull + rotacion externa", 3,
                description="Tira cuerda hacia la cara y rota punos hacia arriba hasta antebrazos verticales. Manten 2 segundos.",
                icon="figure.strengthtraining.functional",
                sets=3, rest_seconds=45, rest_after_seconds=60,
                reps=15, seconds_per_rep=4,
                images=img("2652-m-crop.png"),
            ),
            exercise(
                "Plancha con transferencia de peso", 4,
                duration_seconds=38,
                description="Plancha frontal. Alterna levantando una mano (toca hombro contrario) sin que el cuerpo rote ni la cadera se hunda.",
                icon="figure.core.training",
                sets=3, rest_seconds=45, rest_after_seconds=60,
                images=img("https://spotebi.com/wp-content/uploads/2016/03/plank-shoulder-tap-exercise-illustration-spotebi.jpg"),
            ),
            exercise(
                "Pull-ups (progresion de volumen)", 5,
                description="Misma tecnica con enfasis en depresion escapular y excentrica lenta. Objetivo: 4x10 limpias.",
                icon="figure.strengthtraining.functional",
                sets=4, rest_seconds=90, rest_after_seconds=0,
                reps=10, seconds_per_rep=6,
                images=img("1157-m-crop.png"),
            ),
        ],
    }

    # ===================== FASE 3 DIA B =====================
    fase3_b = {
        "name": "Fase 3 - Dia B (Cadena anterior)",
        "isDefault": False,
        "intervalMinutes": 45,
        "isActive": False,
        "exercises": [
            exercise(
                "Sentadilla goblet (pesada)", 0,
                description="Misma tecnica con mas carga. Si la mancuerna se queda corta, pasa a front squat o anade pausa de 3 segundos abajo.",
                icon="figure.strengthtraining.functional",
                sets=4, rest_seconds=60, rest_after_seconds=60,
                reps=12, seconds_per_rep=5,
                images=img("1735-m-crop.png"),
            ),
            exercise(
                "Push-up con protraction (pies elevados)", 1,
                description="Push-up plus con pies en banco. Mantén protraccion escapular al final de cada rep.",
                icon="figure.strengthtraining.functional",
                sets=3, rest_seconds=60, rest_after_seconds=60,
                reps=15, seconds_per_rep=4,
                images=img("https://spotebi.com/wp-content/uploads/2014/10/push-up-exercise-illustration.jpg"),
            ),
            exercise(
                "Remo invertido (TRX o barra baja)", 2,
                description="Cuelga de barra baja o TRX. Tira pecho hacia barra apretando escapulas al final. Baja controlado.",
                icon="figure.strengthtraining.functional",
                sets=3, rest_seconds=60, rest_after_seconds=60,
                reps=12, seconds_per_rep=5,
                images=img("1441-m-crop.png"),
            ),
            exercise(
                "Movilidad toracica con rotacion", 3,
                description="En cuadrupedia. Mano en la nuca. Rota torso llevando codo al techo. Vuelve pasando codo por debajo del cuerpo.",
                icon="figure.flexibility",
                sets=2, rest_seconds=15, rest_after_seconds=30,
                reps=10, seconds_per_rep=5,
                images=img("https://spotebi.com/wp-content/uploads/2017/11/thread-the-needle-pose-parsva-balasana-spotebi.jpg"),
            ),
            exercise(
                "Estiramiento dinamico flexores de cadera", 4,
                description="Zancada larga hacia delante. En posicion baja, levanta brazo del lado de pierna trasera al techo. Alterna.",
                icon="figure.flexibility",
                sets=2, rest_seconds=15, rest_after_seconds=0,
                reps=10, seconds_per_rep=5,
                images=img("https://spotebi.com/wp-content/uploads/2015/03/hip-flexor-stretch-exercise-illustration.jpg"),
            ),
        ],
    }

    # ===================== FASE 3 MOVILIDAD DIARIA =====================
    fase3_mob = {
        "name": "Fase 3 - Movilidad diaria",
        "isDefault": False,
        "intervalMinutes": 45,
        "isActive": False,
        "exercises": [
            exercise(
                "Foam roller toracico", 0,
                duration_seconds=120,
                description="Rodillo en zona toracica. Rueda lentamente arriba y abajo.",
                icon="figure.cooldown",
                images=img("7753-m-crop.png"),
                rest_after_seconds=10,
            ),
            exercise(
                "Estiramiento flexores de cadera", 1,
                duration_seconds=30,
                description="Rodilla trasera en el suelo. Avanza cadera apretando gluteo.",
                icon="figure.flexibility",
                rest_after_seconds=10,
                images=img("https://spotebi.com/wp-content/uploads/2015/03/hip-flexor-stretch-exercise-illustration.jpg"),
            ),
            exercise(
                "Chin tucks", 2,
                description="Lleva barbilla hacia atras. Manten 5 segundos.",
                icon="figure.cooldown",
                reps=10, seconds_per_rep=5,
                rest_after_seconds=10,
                images=img("https://www.shutterstock.com/image-vector/chin-tuck-head-text-neck-600nw-2158119513.jpg"),
            ),
            exercise(
                "Rotacion toracica", 3,
                description="En cuadrupedia. Mano en la nuca. Rota codo al techo. Alterna.",
                icon="figure.flexibility",
                reps=10, seconds_per_rep=5,
                rest_after_seconds=10,
            ),
            exercise(
                "Respiracion diafragmatica", 4,
                duration_seconds=180,
                description="Tumbado boca arriba. Mano en abdomen. Solo se mueve el abdomen. Inspira 4 segundos, espira 6 segundos.",
                icon="figure.cooldown",
                rest_after_seconds=0,
            ),
        ],
    }

    return {
        "routines": [fase1, fase2_a, fase2_b, fase2_mob, fase3_a, fase3_b, fase3_mob]
    }


def clean_nulls(obj):
    """Remove None values from dicts for cleaner JSON."""
    if isinstance(obj, dict):
        return {k: clean_nulls(v) for k, v in obj.items() if v is not None}
    elif isinstance(obj, list):
        return [clean_nulls(item) for item in obj]
    return obj


def main():
    data = build_routines()
    data = clean_nulls(data)

    with open(OUTPUT_PATH, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    # Print summary
    total_exercises = sum(len(r["exercises"]) for r in data["routines"])
    total_images = sum(
        len(e.get("images", []))
        for r in data["routines"]
        for e in r["exercises"]
    )
    file_size = os.path.getsize(OUTPUT_PATH)

    print(f"\nGenerated: {OUTPUT_PATH}")
    print(f"  Routines: {len(data['routines'])}")
    print(f"  Exercises: {total_exercises}")
    print(f"  Images: {total_images}")
    print(f"  File size: {file_size / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
