FROM mysql:8.4
ENV APP_DB_NAME=webapp APP_DB_USER=webapp APP_DB_PASSWORD=webapp123 MYSQL_INITDB_SKIP_TZINFO=1
COPY conf/mysql.cnf /etc/mysql/conf.d/mysql.cnf
COPY schema/schema.sql /opt/webapp/schema.sql
COPY initdb/01-setup.sh /docker-entrypoint-initdb.d/01-setup.sh
RUN sed -i 's/\r$//' /docker-entrypoint-initdb.d/01-setup.sh && chmod 644 /docker-entrypoint-initdb.d/01-setup.sh
