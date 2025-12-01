from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional

class WeatherData(BaseModel):
    precipitacion: float
    velocidad_viento: float
    presion_atmosferica: float
    temperatura: float
    humedad: float
    timestamp: Optional[datetime] = Field(default_factory=datetime.utcnow)

class WeatherData(BaseModel):
    precipitacion: float = Field(..., description="Precipitación en mm")
    velocidad_viento: float = Field(..., description="Velocidad del viento en m/s")
    presion_atmosferica: float = Field(..., description="Presión atmosférica en hPa")
    temperatura: float = Field(..., description="Temperatura en °C")
    humedad: float = Field(..., ge=0, le=100, description="Humedad relativa en %")
    timestamp: Optional[datetime] = Field(
        default=None,
        description="Fecha y hora de la medición (opcional, si no se envía, se pone la hora del servidor)",
    )

from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class WeatherData(BaseModel):
    precipitacion: float
    velocidad_viento: float
    presion_atmosferica: float
    velocidad_viento: float
    temperatura: float
    humedad: float
    timestamp: Optional[datetime] = None


class WeatherDataUpdate(BaseModel):
    precipitacion: Optional[float] = None
    presion_atmosferica: Optional[float] = None
    velocidad_viento: Optional[float] = None
    temperatura: Optional[float] = None
    humedad: Optional[float] = None
