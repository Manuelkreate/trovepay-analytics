import duckdb
import time
from dotenv import load_dotenv
import os

load_dotenv()
GENERATOR_DATA_PATH = os.getenv("GENERATOR_DATA_PATH")
DB_PATH = "trovepay.duckdb"

SMALL_TABLES = [
    "merchants",
    "terminals",
    "loan_applications",
    "loans",
    "repayment_schedule",
    "repayments",
]

def load_small_tables(con):
    for name in SMALL_TABLES:
        csv_path = f"{GENERATOR_DATA_PATH}\\{name}.csv"
        print(f"Loading {name}...")
        con.execute(f"""
            CREATE OR REPLACE TABLE raw_{name} AS
            SELECT * FROM read_csv_auto('{csv_path}')
        """)
        row_count = con.execute(f"SELECT COUNT(*) FROM raw_{name}").fetchone()[0]
        print(f"  -> {row_count:,} rows")

def load_transactions(con):
    csv_path = f"{GENERATOR_DATA_PATH}\\transactions.csv"
    print("Loading transactions (this is the big one, may take a while)...")
    start = time.time()
    con.execute(f"""
        CREATE OR REPLACE TABLE raw_transactions AS
        SELECT * FROM read_csv_auto('{csv_path}')
    """)
    elapsed = time.time() - start
    row_count = con.execute("SELECT COUNT(*) FROM raw_transactions").fetchone()[0]
    print(f"  -> {row_count:,} rows in {elapsed:.1f}s")

if __name__ == "__main__":
    con = duckdb.connect(DB_PATH)
    load_small_tables(con)
    load_transactions(con)
    con.close()
    print("Done.")