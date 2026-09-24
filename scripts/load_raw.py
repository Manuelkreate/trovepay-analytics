import duckdb
import os
import sys
from dotenv import load_dotenv

load_dotenv()
GENERATOR_DATA_PATH = os.getenv("GENERATOR_DATA_PATH")
DB_PATH = "trovepay.duckdb"

TABLE_CONFIG = {
    "merchants": "onboarding_date",
    "terminals": "assigned_at",
    "loan_applications": "application_date",
    "loans": "disbursement_date",
    "repayment_schedule": "due_date",
    "repayments": "repayment_date",
    "transactions": "timestamp",
}

def ensure_state_table(con):
    con.execute("""
        CREATE TABLE IF NOT EXISTS _load_state (
            table_name VARCHAR PRIMARY KEY,
            last_loaded_date TIMESTAMP
        )
    """)

def get_watermark(con, table_name):
    result = con.execute(
        "SELECT last_loaded_date FROM _load_state WHERE table_name = ?", [table_name]
    ).fetchone()
    return result[0] if result else None

def set_watermark(con, table_name, as_of_cutoff):
    con.execute("""
        INSERT INTO _load_state (table_name, last_loaded_date)
        VALUES (?, ?)
        ON CONFLICT (table_name) DO UPDATE SET last_loaded_date = excluded.last_loaded_date
    """, [table_name, as_of_cutoff])

def table_exists(con, table_name):
    return con.execute(
        "SELECT 1 FROM information_schema.tables WHERE table_name = ?", [table_name]
    ).fetchone() is not None

def load_table(con, table_name, date_column, as_of_cutoff):
    csv_path = os.path.join(GENERATOR_DATA_PATH, f"{table_name}.csv")
    raw_table = f"raw_{table_name}"
    watermark = get_watermark(con, table_name)
    col = f'"{date_column}"' 

    where_clauses = [f"{col} <= '{as_of_cutoff}'"]
    if watermark is not None:
        where_clauses.append(f"{col} > '{watermark}'")
    where_sql = " AND ".join(where_clauses)

    query = f"SELECT * FROM read_csv_auto('{csv_path}') WHERE {where_sql}"

    if not table_exists(con, raw_table):
        con.execute(f"CREATE TABLE {raw_table} AS {query}")
    else:
        con.execute(f"INSERT INTO {raw_table} {query}")

    row_count = con.execute(f"SELECT COUNT(*) FROM {raw_table}").fetchone()[0]
    print(f"{raw_table}: {row_count:,} total rows as of {as_of_cutoff}")
    set_watermark(con, table_name, as_of_cutoff)
    
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python scripts/load_raw.py <as_of_date, e.g. 2025-06-30>")
        sys.exit(1)
    as_of_cutoff = sys.argv[1]
    con = duckdb.connect(DB_PATH)
    ensure_state_table(con)
    for table_name, date_column in TABLE_CONFIG.items():
        load_table(con, table_name, date_column, as_of_cutoff)
    con.close()
    print("Done.")