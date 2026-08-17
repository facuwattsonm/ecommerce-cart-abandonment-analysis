"""
ingest.py
Carga idempotente de datos desde Google Sheets hacia BigQuery.

Flujo: Google Sheets -> pandas -> tabla staging en BigQuery -> MERGE hacia la tabla final.
El MERGE es lo que garantiza idempotencia: correr el script varias veces con el mismo
Sheet no genera filas duplicadas en la tabla final.

Nota: este script es una reconstrucción de referencia del pipeline descrito en el caso
de estudio (Google Cloud BigQuery + gspread). Ajustar credenciales, IDs y el nombre de
las columnas al esquema real antes de usarlo.
"""

import gspread
from google.oauth2.service_account import Credentials
from google.cloud import bigquery
import pandas as pd

# --- Configuración ---
SERVICE_ACCOUNT_FILE = "credentials/service_account.json"  # nunca subir este archivo a GitHub
SPREADSHEET_ID = "TU_SPREADSHEET_ID"
WORKSHEET_NAME = "Cart_Events"

PROJECT_ID = "tu-proyecto-bigquery"
DATASET = "Ecommerce_Cart"
TABLE_FINAL = f"{PROJECT_ID}.{DATASET}.Cart_Events"
TABLE_STAGING = f"{PROJECT_ID}.{DATASET}.Cart_Events_staging"

PRIMARY_KEY = "cart_id"  # columna usada para detectar duplicados en el MERGE

SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets.readonly",
    "https://www.googleapis.com/auth/drive.readonly",
]


def leer_sheet() -> pd.DataFrame:
    """Lee la hoja de Google Sheets y la devuelve como DataFrame."""
    creds = Credentials.from_service_account_file(SERVICE_ACCOUNT_FILE, scopes=SCOPES)
    client = gspread.authorize(creds)
    sheet = client.open_by_key(SPREADSHEET_ID).worksheet(WORKSHEET_NAME)
    registros = sheet.get_all_records()
    df = pd.DataFrame(registros)
    print(f"Se leyeron {len(df)} filas desde Google Sheets.")
    return df


def cargar_a_staging(df: pd.DataFrame, bq_client: bigquery.Client) -> None:
    """Sube el DataFrame completo a una tabla staging (se reemplaza en cada corrida)."""
    job_config = bigquery.LoadJobConfig(
        write_disposition="WRITE_TRUNCATE",
        autodetect=True,
    )
    job = bq_client.load_table_from_dataframe(df, TABLE_STAGING, job_config=job_config)
    job.result()
    print(f"Staging actualizado: {job.output_rows} filas.")


def merge_a_tabla_final(bq_client: bigquery.Client) -> None:
    """
    Inserta en la tabla final solo las filas de staging que no existen todavía,
    usando PRIMARY_KEY como criterio de unicidad. Esto es lo que hace que correr
    el script varias veces con el mismo archivo no duplique datos (idempotencia).
    """
    merge_query = f"""
    MERGE `{TABLE_FINAL}` AS final
    USING `{TABLE_STAGING}` AS staging
    ON final.{PRIMARY_KEY} = staging.{PRIMARY_KEY}
    WHEN NOT MATCHED THEN
      INSERT ROW
    """
    job = bq_client.query(merge_query)
    job.result()
    print(f"MERGE completo: {job.num_dml_affected_rows} filas nuevas insertadas.")


def main():
    bq_client = bigquery.Client(project=PROJECT_ID)
    df = leer_sheet()
    if df.empty:
        print("No hay datos nuevos para cargar. Fin del proceso.")
        return
    cargar_a_staging(df, bq_client)
    merge_a_tabla_final(bq_client)


if __name__ == "__main__":
    main()
