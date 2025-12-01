import requests

BASE_URL = "http://127.0.0.1:8000"


def leer_float(mensaje: str) -> float:
    while True:
        valor = input(mensaje)
        try:
            return float(valor)
        except ValueError:
            print("❌ Valor inválido, escribe un número.")


def mostrar_menu():
    print("\n===== INTERFAZ USUARIO - ESTACIÓN METEOROLÓGICA =====")
    print("1. Agregar nueva medición")
    print("2. Listar mediciones")
    print("3. Actualizar una medición")
    print("4. Eliminar una medición por ID")
    print("5. Eliminar TODAS las mediciones")
    print("0. Salir")
    print("=====================================================")


def agregar_medicion():
    print("\n➕ Agregar nueva medición")
    precipitacion = leer_float("Precipitación (mm): ")
    velocidad_viento = leer_float("Velocidad del viento (m/s): ")
    presion = leer_float("Presión atmosférica (hPa): ")
    temperatura = leer_float("Temperatura (°C): ")
    humedad = leer_float("Humedad (%): ")

    data = {
        "precipitacion": precipitacion,
        "velocidad_viento": velocidad_viento,
        "presion_atmosferica": presion,
        "temperatura": temperatura,
        "humedad": humedad
    }

    r = requests.post(f"{BASE_URL}/mediciones", json=data)
    print("✅ Respuesta:", r.json())


def listar_mediciones():
    print("\n📄 Listando mediciones...")
    r = requests.get(f"{BASE_URL}/mediciones")
    datos = r.json()

    for d in datos:
        print("----------------------------------------")
        print("ID:", d["_id"])
        print("Temperatura:", d["temperatura"])
        print("Humedad:", d["humedad"])
        print("Presión:", d["presion_atmosferica"])
        print("Viento:", d["velocidad_viento"])
        print("Precipitación:", d["precipitacion"])
        print("Fecha:", d["timestamp"])
    print("----------------------------------------")


def actualizar_medicion():
    print("\n✏️ Actualizar una medición")
    id_med = input("ID de la medición: ")

    print("Introduce los nuevos valores:")
    precipitacion = leer_float("Precipitación (mm): ")
    velocidad_viento = leer_float("Velocidad del viento (m/s): ")
    presion = leer_float("Presión atmosférica (hPa): ")
    temperatura = leer_float("Temperatura (°C): ")
    humedad = leer_float("Humedad (%): ")

    data = {
        "precipitacion": precipitacion,
        "velocidad_viento": velocidad_viento,
        "presion_atmosferica": presion,
        "temperatura": temperatura,
        "humedad": humedad
    }

    r = requests.put(f"{BASE_URL}/mediciones/{id_med}", json=data)
    print("🔄 Respuesta:", r.json())


def eliminar_medicion():
    print("\n🗑️ Eliminar medición")
    id_med = input("ID de la medición: ")
    r = requests.delete(f"{BASE_URL}/mediciones/{id_med}")
    print("🗑️ Respuesta:", r.json())


def eliminar_todas():
    print("\n⚠️ Eliminando TODAS las mediciones...")
    r = requests.delete(f"{BASE_URL}/mediciones")
    print("🔥 Respuesta:", r.json())


def main():
    while True:
        mostrar_menu()
        op = input("Selecciona una opción: ")

        if op == "1":
            agregar_medicion()
        elif op == "2":
            listar_mediciones()
        elif op == "3":
            actualizar_medicion()
        elif op == "4":
            eliminar_medicion()
        elif op == "5":
            eliminar_todas()
        elif op == "0":
            print("👋 Saliendo...")
            break
        else:
            print("❌ Opción inválida")


if __name__ == "__main__":
    main()
