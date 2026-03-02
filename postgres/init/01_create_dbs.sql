-- Crea una DB y un user por microservicio (PostgreSQL 16)

-- users
CREATE DATABASE ms_users;
CREATE USER ms_users WITH ENCRYPTED PASSWORD 'ms_users';
GRANT ALL PRIVILEGES ON DATABASE ms_users TO ms_users;

-- bank accounts
CREATE DATABASE ms_bank_accounts;
CREATE USER ms_bank_accounts WITH ENCRYPTED PASSWORD 'ms_bank_accounts';
GRANT ALL PRIVILEGES ON DATABASE ms_bank_accounts TO ms_bank_accounts;

-- files
CREATE DATABASE ms_files;
CREATE USER ms_files WITH ENCRYPTED PASSWORD 'ms_files';
GRANT ALL PRIVILEGES ON DATABASE ms_files TO ms_files;

-- transactions (core)
CREATE DATABASE ms_transactions;
CREATE USER ms_transactions WITH ENCRYPTED PASSWORD 'ms_transactions';
GRANT ALL PRIVILEGES ON DATABASE ms_transactions TO ms_transactions;

-- expenses
CREATE DATABASE ms_expenses;
CREATE USER ms_expenses WITH ENCRYPTED PASSWORD 'ms_expenses';
GRANT ALL PRIVILEGES ON DATABASE ms_expenses TO ms_expenses;

-- cash
CREATE DATABASE ms_cash;
CREATE USER ms_cash WITH ENCRYPTED PASSWORD 'ms_cash';
GRANT ALL PRIVILEGES ON DATABASE ms_cash TO ms_cash;

-- saves
CREATE DATABASE ms_saves;
CREATE USER ms_saves WITH ENCRYPTED PASSWORD 'ms_saves';
GRANT ALL PRIVILEGES ON DATABASE ms_saves TO ms_saves;

-- investments
CREATE DATABASE ms_investments;
CREATE USER ms_investments WITH ENCRYPTED PASSWORD 'ms_investments';
GRANT ALL PRIVILEGES ON DATABASE ms_investments TO ms_investments;

-- goals
CREATE DATABASE ms_goals;
CREATE USER ms_goals WITH ENCRYPTED PASSWORD 'ms_goals';
GRANT ALL PRIVILEGES ON DATABASE ms_goals TO ms_goals;

-- ai classifier (opcional persistencia)
CREATE DATABASE ms_ai_classifier;
CREATE USER ms_ai_classifier WITH ENCRYPTED PASSWORD 'ms_ai_classifier';
GRANT ALL PRIVILEGES ON DATABASE ms_ai_classifier TO ms_ai_classifier;