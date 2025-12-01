import os
from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient

# Cargar variables del archivo .env
load_dotenv()

MONGO_URI = os.getenv("MONGO_URI")
DB_NAME = os.getenv("DB_NAME", "weather_station")

if not MONGO_URI:
    raise ValueError("No se encontró MONGO_URI en el archivo .env")

# Crear el cliente de MongoDB
client = AsyncIOMotorClient(MONGO_URI)

# Seleccionar la base de datos
db = client[DB_NAME]

# Colección de mediciones
mediciones_collection = db["mediciones"]
