import pandas as pd
import sqlite3

conn = sqlite3.connect("churn.db")

pd.read_csv("churn.csv").to_sql("customers_raw", conn, if_exists="replace", index=False)
pd.read_csv("zipcodes.csv", dtype={"Zip Code": str}).to_sql("zipcodes", conn, if_exists="replace", index=False)

conn.close()