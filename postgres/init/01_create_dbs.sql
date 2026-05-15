-- Crea una DB y un user por microservicio (PostgreSQL 16)
-- Ademas deja al usuario de cada microservicio como owner de su base y del schema public.

-- users
CREATE USER ms_users WITH ENCRYPTED PASSWORD 'ms_users';
CREATE DATABASE ms_users OWNER ms_users;
GRANT ALL PRIVILEGES ON DATABASE ms_users TO ms_users;
\connect ms_users
ALTER SCHEMA public OWNER TO ms_users;
GRANT ALL ON SCHEMA public TO ms_users;
\connect postgres

-- bank accounts
CREATE USER ms_bank_accounts WITH ENCRYPTED PASSWORD 'ms_bank_accounts';
CREATE DATABASE ms_bank_accounts OWNER ms_bank_accounts;
GRANT ALL PRIVILEGES ON DATABASE ms_bank_accounts TO ms_bank_accounts;
\connect ms_bank_accounts
ALTER SCHEMA public OWNER TO ms_bank_accounts;
GRANT ALL ON SCHEMA public TO ms_bank_accounts;
\connect postgres

-- files
CREATE USER ms_files WITH ENCRYPTED PASSWORD 'ms_files';
CREATE DATABASE ms_files OWNER ms_files;
GRANT ALL PRIVILEGES ON DATABASE ms_files TO ms_files;
\connect ms_files
ALTER SCHEMA public OWNER TO ms_files;
GRANT ALL ON SCHEMA public TO ms_files;
\connect postgres

-- transactions (core)
CREATE USER ms_transactions WITH ENCRYPTED PASSWORD 'ms_transactions';
CREATE DATABASE ms_transactions OWNER ms_transactions;
GRANT ALL PRIVILEGES ON DATABASE ms_transactions TO ms_transactions;
\connect ms_transactions
ALTER SCHEMA public OWNER TO ms_transactions;
GRANT ALL ON SCHEMA public TO ms_transactions;
\connect postgres

-- expenses
CREATE USER ms_expenses WITH ENCRYPTED PASSWORD 'ms_expenses';
CREATE DATABASE ms_expenses OWNER ms_expenses;
GRANT ALL PRIVILEGES ON DATABASE ms_expenses TO ms_expenses;
\connect ms_expenses
ALTER SCHEMA public OWNER TO ms_expenses;
GRANT ALL ON SCHEMA public TO ms_expenses;
\connect postgres

-- cash
CREATE USER ms_cash WITH ENCRYPTED PASSWORD 'ms_cash';
CREATE DATABASE ms_cash OWNER ms_cash;
GRANT ALL PRIVILEGES ON DATABASE ms_cash TO ms_cash;
\connect ms_cash
ALTER SCHEMA public OWNER TO ms_cash;
GRANT ALL ON SCHEMA public TO ms_cash;
\connect postgres

-- saves
CREATE USER ms_saves WITH ENCRYPTED PASSWORD 'ms_saves';
CREATE DATABASE ms_saves OWNER ms_saves;
GRANT ALL PRIVILEGES ON DATABASE ms_saves TO ms_saves;
\connect ms_saves
ALTER SCHEMA public OWNER TO ms_saves;
GRANT ALL ON SCHEMA public TO ms_saves;
\connect postgres

-- investments
CREATE USER ms_investments WITH ENCRYPTED PASSWORD 'ms_investments';
CREATE DATABASE ms_investments OWNER ms_investments;
GRANT ALL PRIVILEGES ON DATABASE ms_investments TO ms_investments;
\connect ms_investments
ALTER SCHEMA public OWNER TO ms_investments;
GRANT ALL ON SCHEMA public TO ms_investments;
\connect postgres

-- goals
CREATE USER ms_goals WITH ENCRYPTED PASSWORD 'ms_goals';
CREATE DATABASE ms_goals OWNER ms_goals;
GRANT ALL PRIVILEGES ON DATABASE ms_goals TO ms_goals;
\connect ms_goals
ALTER SCHEMA public OWNER TO ms_goals;
GRANT ALL ON SCHEMA public TO ms_goals;
\connect postgres

-- ai classifier
CREATE USER ms_ai_classifier WITH ENCRYPTED PASSWORD 'ms_ai_classifier';
CREATE DATABASE ms_ai_classifier OWNER ms_ai_classifier;
GRANT ALL PRIVILEGES ON DATABASE ms_ai_classifier TO ms_ai_classifier;
\connect ms_ai_classifier
ALTER SCHEMA public OWNER TO ms_ai_classifier;
GRANT ALL ON SCHEMA public TO ms_ai_classifier;
\connect postgres

-- notifications
CREATE USER ms_notifications_cartera WITH ENCRYPTED PASSWORD 'ms_notifications_cartera';
CREATE DATABASE ms_notifications_cartera OWNER ms_notifications_cartera;
GRANT ALL PRIVILEGES ON DATABASE ms_notifications_cartera TO ms_notifications_cartera;
\connect ms_notifications_cartera
ALTER SCHEMA public OWNER TO ms_notifications_cartera;
GRANT ALL ON SCHEMA public TO ms_notifications_cartera;
\connect postgres
