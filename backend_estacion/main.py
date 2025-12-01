from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path

import os
import secrets
from datetime import datetime
from bson import ObjectId

from .database import mediciones_collection
from .models import WeatherData, WeatherDataUpdate

# ---------------------------
# Rutas de archivos
# ---------------------------

# Ruta base del archivo main.py (backend_estacion/)
BASE_DIR = Path(__file__).resolve().parent

# Carpeta "static" dentro de backend_estacion
STATIC_DIR = BASE_DIR / "static"

# ---------------------------
# Crear app FastAPI
# ---------------------------

app = FastAPI(
    title="Panel Admin Estación Meteorológica",
    docs_url=None,              # Desactivamos /docs público
    redoc_url=None,             # Desactivamos /redoc
    openapi_url="/openapi.json" # dejamos el esquema igual
)

# ---------------------------
# CORS (para Flutter Web / React / etc.)
# ---------------------------

origins = [
    "http://localhost:3000",    # React
    "http://localhost:5173",    # Vite
    "http://localhost:5500",    # Archivos locales
    "http://127.0.0.1:5500",
    "*",                        # <-- Solo para desarrollo. Quitar en producción.
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------
# Static files (CSS de admin)
# ---------------------------

app.mount(
    "/static",
    StaticFiles(directory=str(STATIC_DIR)),
    name="static"
)

# ---------------------------
# Seguridad panel admin
# ---------------------------

security = HTTPBasic()

ADMIN_USER = os.getenv("ADMIN_USER", "admin")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin123")


def verificar_admin(credentials: HTTPBasicCredentials = Depends(security)):
    """
    Verifica el usuario y contraseña enviados por el navegador (HTTP Basic Auth).
    Si no coincide con los datos de .env, devuelve 401.
    """
    usuario_ok = secrets.compare_digest(credentials.username, ADMIN_USER)
    pass_ok = secrets.compare_digest(credentials.password, ADMIN_PASSWORD)

    if not (usuario_ok and pass_ok):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autorizado",
            headers={"WWW-Authenticate": "Basic"},
        )

    return credentials.username


@app.get("/admin/docs", include_in_schema=False)
async def custom_swagger_ui(username: str = Depends(verificar_admin)):
    """
    Interfaz de documentación protegida para el administrador,
    con estilos personalizados (tema oscuro).
    """
    response = get_swagger_ui_html(
        openapi_url=app.openapi_url,
        title="Panel Admin Estación Meteorológica",
    )

    # Inyectamos nuestro CSS antes de cerrar </head>
    extra_css = '<link rel="stylesheet" type="text/css" href="/static/admin.css">'
    new_body = response.body.replace(
        b"</head>",
        extra_css.encode() + b"</head>",
    )

    response.body = new_body
    response.headers["Content-Length"] = str(len(new_body))

    return response

# ---------------------------
# Endpoints de prueba
# ---------------------------

@app.get("/")
async def root():
    return {"message": "API funcionando"}


@app.post("/test-insert")
async def test_insert():
    doc = {
        "temperatura": 25,
        "humedad": 70,
        "timestamp": datetime.utcnow()
    }
    result = await mediciones_collection.insert_one(doc)
    return {"inserted_id": str(result.inserted_id)}


@app.get("/test-list")
async def test_list():
    docs = []
    cursor = mediciones_collection.find().limit(10)
    async for d in cursor:
        d["_id"] = str(d["_id"])
        docs.append(d)
    return docs

# ---------------------------
# Endpoints REALES de la estación
# ---------------------------

@app.post("/mediciones")
async def crear_medicion(data: WeatherData):
    """
    Recibe una medición real de la estación y la guarda en MongoDB.
    """
    doc = data.model_dump()

    # Si no mandan timestamp, usamos la hora actual del servidor
    if doc.get("timestamp") is None:
        doc["timestamp"] = datetime.utcnow()

    result = await mediciones_collection.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return doc


@app.get("/mediciones")
async def listar_mediciones(limit: int = 100):
    """
    Lista hasta 'limit' mediciones, ordenadas de la más reciente a la más antigua.
    """
    docs = []
    cursor = (
        mediciones_collection.find()
        .sort("timestamp", -1)
        .limit(limit)
    )
    async for d in cursor:
        d["_id"] = str(d["_id"])
        docs.append(d)
    return docs


@app.get("/mediciones/ultima")
async def ultima_medicion():
    """
    Devuelve la última medición registrada (ideal para el dashboard principal).
    """
    doc = await mediciones_collection.find_one(sort=[("timestamp", -1)])
    if doc is None:
        raise HTTPException(status_code=404, detail="No hay mediciones todavía")

    doc["_id"] = str(doc["_id"])
    return doc


@app.delete("/mediciones/{medicion_id}")
async def eliminar_medicion(medicion_id: str):
    """
    Elimina una medición específica por su ID de MongoDB.
    """
    try:
        oid = ObjectId(medicion_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID no es válido")

    result = await mediciones_collection.delete_one({"_id": oid})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Medición no encontrada")

    return {"deleted": True, "id": medicion_id}


@app.put("/mediciones/{medicion_id}")
async def actualizar_medicion_api(medicion_id: str, data: WeatherDataUpdate):
    """
    Actualiza parcialmente una medición en MongoDB.
    Solo se cambian los campos que se envíen.
    """
    try:
        oid = ObjectId(medicion_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID no es válido")

    cambios = {k: v for k, v in data.model_dump().items() if v is not None}
    if not cambios:
        raise HTTPException(status_code=400, detail="No se enviaron campos para actualizar")

    result = await mediciones_collection.update_one({"_id": oid}, {"$set": cambios})
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Medición no encontrada")

    doc = await mediciones_collection.find_one({"_id": oid})
    doc["_id"] = str(doc["_id"])
    return doc


@app.delete("/mediciones")
async def eliminar_todas_mediciones():
    """
    Elimina TODAS las mediciones (útil para limpiar datos en pruebas).
    """
    result = await mediciones_collection.delete_many({})
    return {"deleted": result.deleted_count}
