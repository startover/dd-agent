CREATE USER oneapm_ci_agent WITH PASSWORD 'oneapm_ci_agent';
GRANT SELECT ON pg_stat_database TO oneapm_ci_agent;
CREATE DATABASE oneapm_ci_agent_test;
GRANT ALL PRIVILEGES ON DATABASE oneapm_ci_agent_test TO oneapm_ci_agent;
CREATE DATABASE dogs;
