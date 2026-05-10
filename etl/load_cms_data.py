# HEDIS Analytics ETL
# Loads CMS synthetic Medicare CSV files into SQL Server
# Data movement only — no business logic

import pyodbc
import pandas as pd
import os
import getpass

# ============================================================
# Configuration
# ============================================================
DATA_DIR = '/home/yzaya/Projects/hedis-analytics/data/raw'
CHUNK_SIZE = 5000

FILES = [
    ('beneficiary_2021.csv', 'beneficiary'),
    ('inpatient.csv',        'inpatient'),
    ('outpatient.csv',       'outpatient'),
    ('carrier.csv',          'carrier'),
    ('dme.csv',              'dme'),
    ('hha.csv',              'hha'),
    ('hospice.csv',          'hospice'),
    ('snf.csv',              'snf'),
    ('pde.csv',              'pde'),
]

# ============================================================
# Connection
# ============================================================
def get_connection(password):
    conn_str = (
        'DRIVER={ODBC Driver 18 for SQL Server};'
        'SERVER=localhost;'
        'DATABASE=hedis;'
        'UID=SA;'
        f'PWD={password};'
        'TrustServerCertificate=yes;'
    )
    return pyodbc.connect(conn_str)


# ============================================================
# Load a single file into a table
# ============================================================
def load_file(conn, csv_path, table_name):
    print(f'\n--- Loading {os.path.basename(csv_path)} -> {table_name} ---')

    try:
        # Get row count from existing table before load
        cursor = conn.cursor()
        cursor.execute(f'SELECT COUNT(*) FROM {table_name}')
        rows_before = cursor.fetchone()[0]
        print(f'  Rows before: {rows_before}')

        # Read CSV in chunks and insert
        total_inserted = 0
        for chunk_num, chunk in enumerate(pd.read_csv(
            csv_path,
            sep='|',
            dtype=str,
            chunksize=CHUNK_SIZE,
            keep_default_na=False
        )):
            # Replace empty strings with None (SQL NULL)
            chunk = chunk.where(chunk != '', other=None)

            cols = list(chunk.columns)
            placeholders = ', '.join(['?' for _ in cols])
            col_names = ', '.join(cols)
            sql = f'INSERT INTO {table_name} ({col_names}) VALUES ({placeholders})'

            rows = [tuple(row) for row in chunk.itertuples(index=False, name=None)]

            cursor = conn.cursor()
            cursor.fast_executemany = True
            cursor.executemany(sql, rows)
            conn.commit()

            total_inserted += len(rows)
            if (chunk_num + 1) % 10 == 0:
                print(f'  ...{total_inserted} rows inserted')

        # Verify row count after load
        cursor.execute(f'SELECT COUNT(*) FROM {table_name}')
        rows_after = cursor.fetchone()[0]
        print(f'  Rows after:  {rows_after}')
        print(f'  Inserted:    {rows_after - rows_before}')

    except Exception as e:
        print(f'  ERROR loading {table_name}: {e}')
        conn.rollback()
        raise


# ============================================================
# Main
# ============================================================
def main():
    password = getpass.getpass('SA password: ')

    try:
        conn = get_connection(password)
        print('Connected to SQL Server.')
    except Exception as e:
        print(f'Connection failed: {e}')
        return

    for csv_file, table_name in FILES:
        csv_path = os.path.join(DATA_DIR, csv_file)
        if not os.path.exists(csv_path):
            print(f'SKIP: {csv_file} not found')
            continue
        try:
            load_file(conn, csv_path, table_name)
        except Exception:
            print(f'Skipping {table_name} due to error. Continuing with next file.')

    conn.close()
    print('\nAll done. Connection closed.')


if __name__ == '__main__':
    main()
