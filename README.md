# FlyRight: Airline Reservation & Flight Delay Analytics (Problem Statement 04)
**Course:** M.Sc. Data Science · DBMS for Analytics (`25MSDA1S04`)

## Project Structure
- `schema.sql` — 3NF MySQL schema (7 normalized tables, PK/FK/CHECK/UNIQUE constraints, 2 triggers, 1 analytical view)
- `generate_data.py` — Python script that generates `data.sql` (1,412 realistic rows)
- `data.sql` — Pre-generated SQL insert script (ready to import directly into MySQL)
- `queries.sql` — 5 analytical SQL queries + trigger verification test
- `FlyRight_Analytics.ipynb` — Jupyter Notebook connecting via `mysql-connector-python`, analyzing with `pandas`, and plotting charts with `matplotlib`
- `mongodb_events.js` — MongoDB script for time-series flight status events, compound indexes, CRUD, and 2 aggregation pipelines

## How to Run on Your Laptop

### 1. MySQL Setup
```bash
mysql -u root -p < schema.sql
mysql -u root -p < data.sql
mysql -u root -p < queries.sql
```

### 2. Python & Jupyter Notebook
```bash
pip install mysql-connector-python pandas matplotlib jupyter
jupyter notebook FlyRight_Analytics.ipynb
```
*(Update `password='your_mysql_password'` in Cell 1 before running.)*

### 3. MongoDB Setup
```bash
mongosh < mongodb_events.js
```
