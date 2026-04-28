#excel para limpiar los datos
import pandas as pd

# Cargar datos
df_consumibles_no_deseados = pd.read_excel('info_pendiente_tec.xlsx')
data_refacciones = pd.read_excel('info_Tec.xlsx', sheet_name="Refacciones")
data_equipos = pd.read_excel('info_Tec.xlsx', sheet_name="Equipos")
data_ordenes = pd.read_excel('info_Tec.xlsx', sheet_name="Ordenes de trabajo")

# Limpieza de espacios en blanco
data_refacciones['Description'] = data_refacciones['Description'].astype(str).str.strip()
df_consumibles_no_deseados['Description'] = df_consumibles_no_deseados['Description'].astype(str).str.strip()

# Filtrar filas no deseadas
df_refacciones_limpio = data_refacciones[
    ~data_refacciones['Description'].isin(df_consumibles_no_deseados['Description'])
]

# Verificación
print(f"Registros originales: {len(data_refacciones)}")
print(f"Registros después de la limpieza: {len(df_refacciones_limpio)}")
print(f"Refacciones eliminadas: {len(data_refacciones) - len(df_refacciones_limpio)}")

# ✅ GUARDAR el archivo limpio conservando todas las hojas
with pd.ExcelWriter('info Tec_limpio.xlsx', engine='openpyxl') as writer:
    df_refacciones_limpio.to_excel(writer, sheet_name="Refacciones", index=False)
    data_equipos.to_excel(writer, sheet_name="Equipos", index=False)
    data_ordenes.to_excel(writer, sheet_name="Ordenes de trabajo", index=False)

print("✅ Archivo guardado como 'info Tec_limpio.xlsx'")