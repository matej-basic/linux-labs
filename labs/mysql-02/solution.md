# mysql-02: MySQL database and user management

## Hints

1. Everything is done as the MySQL root account inside the server, with
   SQL statements. The order matters: database and user first, then
   the grant, then the table and rows.
2. The reference sections are CREATE DATABASE, CREATE USER and GRANT in
   the MySQL manual. Use the mysql client with the -e option to run a
   statement without an interactive session.
3. An account is a pair of user name and host name. The task wants the
   host part to be localhost. Name the privileges one by one and limit
   them to all tables of one database with the ON clause of GRANT.
4. Create the table with CREATE TABLE and fill it with INSERT INTO. Give
   the mysql client the database name so the statements run in labdb.
   Test as labuser to see whether the grant works.

## Solution

1. [user] Create the database, the user and its privileges. The root
   password is labpassword:

   ```bash
   mysql -u root -plabpassword -e "CREATE DATABASE labdb"
   mysql -u root -plabpassword -e \
     "CREATE USER 'labuser'@'localhost' IDENTIFIED BY 'userpass123'"
   mysql -u root -plabpassword -e \
     "GRANT SELECT, INSERT, UPDATE, DELETE ON labdb.*
      TO 'labuser'@'localhost'"
   ```

2. [user] Create the table users in labdb:

   ```bash
   mysql -u root -plabpassword labdb -e "CREATE TABLE users (
     id INT AUTO_INCREMENT PRIMARY KEY,
     name VARCHAR(100) NOT NULL,
     email VARCHAR(100) NOT NULL)"
   ```

3. [user] Insert two sample records:

   ```bash
   mysql -u root -plabpassword labdb -e "INSERT INTO users (name, email)
     VALUES ('John Doe', 'john@example.com'),
            ('Jane Smith', 'jane@example.com')"
   ```

## Verification

```bash
mysql -u root -plabpassword -e "SHOW GRANTS FOR 'labuser'@'localhost'"
mysql -u labuser -puserpass123 labdb -e "SELECT * FROM users"
labctl grade mysql-02
```

## Explanation

CREATE USER defines the account and its password, GRANT gives it
rights. Naming labdb.* limits the four privileges to the tables of
that one database, so labuser has no other privileges, no
administrative ones and no GRANT OPTION. GRANT takes effect at once,
so FLUSH PRIVILEGES is not needed.

The account is 'labuser'@'localhost'. A user created for another host
name, for example '%', is a different account and fails the grader.
The grader reads the table through the root account, so it also
counts rows that labuser could not read, and then logs in as labuser
to prove that the grant works.
