### PostgreSQL Tech Talk

This repo serves as a brief guide to using the PostgreSQL database as well as some tips and tricks learned from years of discovery. 

#### Prerequisites 

To make the most of this guide, you will need: 

- Docker Installed
- Git
- Homebrew (brew install ...)
- Text editor or IDE of your choice
- Terminal

 This also assumes you are on a Mac so you can use Homebrew but the instructions are the same if you get `psql` installed.

### Running PostgreSQL

There are many ways to install PostgreSQL but for this guide, we are going to use a Docker image which we can create and destroy as needed. We are also going to use the command line tool `psql`.

#### Installing psql client

The psql tool allows you to connect to a PostgreSQL database server and perform SQL commands. It is normally bundled with the database server as a client tool, but you can install it separately via Homebrew:

```sh
brew install libpq

# The install will not create symlinks or change paths to avoid
# conflicts with other PostgreSQL installs. You can update your
# path using the following:
echo 'export PATH="/usr/local/opt/libpq/bin:$PATH"' >> ~/.zshrc

```

#### Install PostgreSQL Server
To run the PostgreSQL server open a new terminal window and issue the following command:

```sh
npm run postgres

# This will run the following command:
# docker run -p 5432:5432 postgres:9.6-alpine

```

Docker will download the required image and PostgreSQL will start and run in the foreground. If you `CTRL-C`, the server will shutdown and exit.
When you see the following log lines, the server startup is complete:

```sh

PostgreSQL init process complete; ready for start up.

LOG:  database system was shut down at 2018-12-02 13:47:30 UTC
LOG:  MultiXact member wraparound protections are now enabled
LOG:  database system is ready to accept connections
LOG:  autovacuum launcher started

```

We will not be persisting any information or changes we do to the database, so if you shut it down, all data stored within **will be lost**.


### Connecting via PSQL

By default, the database server will be listening on port 5432 for incoming connections on localhost. For authentication PostgreSQL has numerous modes to choose from, with the main ones being:

**Trust Authentication**
  When trust authentication is specified, PostgreSQL assumes that anyone who can connect to the server is authorized to access the database with whatever database user name they specify (even superuser names).

**Password Authentication**
When connecting to the server, only valid username/password combinations are allowed to connect. Passwords can be hashed or in cleartext depending on the mode enforced.

**Ident Authentication**
The ident authentication method works by obtaining the client's operating system user name from an ident server and using it as the allowed database user name (with an optional user name mapping). This is only supported on TCP/IP connections.

There is also LDAP, Radius, Certificate, PAM and Kerberos Authentication methods but those are more specialised cases.

Out of the box, PostgreSQL will use `trust authentication` for connections coming from localhost to support easy development.

To connect to the database server, issue the following command:

```sh
psql -h 127.0.0.1 -p 5432 -U postgres

# You should then see the following prompt:
psql (10.1, server 9.6.8)
Type "help" for help.

postgres=#
```

### The Basics

**Using the prompt**
Each SQL query begins with a statement keyword such as `SELECT`, `UPDATE` or `INSERT` and ends with a semi colon (`;`).

Single and double quotes are treated differently by PostgreSQL. A single quote is used to quote a value such as `'my input'` or `'29abc'`. A double quote is used to represent a column name such as `"house address"`.

The use of dashes is not allowed when naming tables or columns. You should try and use an underscore, or the case system of your choice (camel etc).

To leave the prompt, you can exit using `CTRL-D` or `\q`.
To cancel a query, use `CTRL-C`.

**Running a Query**
For short one-line queries, it is easy to type them directly into the prompt:

```
postgres=# SELECT now();
              now
-------------------------------
 2018-12-02 16:13:30.225503+00
(1 row)

postgres=#
```

For longer queries, you can use the editor by typing a backslash followed by `e` and pressing enter. This will open VIM, nano or your configured `$EDITOR` command.

```
postgres=# \e [ENTER]
```

When you save and exit the editor, the query will be run and the output shown.

**Running multiple queries**

Sometimes you have a number of SQL queries to run and would like to execute them without having to copy and paste each of them into the command prompt. To support this, you can pass any file with SQL queries to the `psql` tool using the `-f` flag.

```
~ # psql -h 127.0.0.1 -p 5432 -U postgres -f my_awesome_queries.sql
```

Unless you are running the queries in a transaction block (covered later) One query does not depend on another. They are all considered to be independent and the failure of one, will not necessarily stop another from running. For example, if creating a table fails, all the `INSERT` commands for the table would still run, but fail as well.

### Transactions and Rollback

Sometimes we need queries to run in a given order and we need to undo any changes we have made if something fails. To support this, we have the concept of a transaction. It also comes in handy when you want to test changes without modifying data.

To start a transaction, issue the following on the psql prompt:

```
postgres=# START TRANSACTION;
START TRANSACTION
postgres=#

< --- Run Queries here --- >

postgres=# ROLLBACK;
ROLLBACK
postgres=#
```

Any commands typed after the `START TRANSACTION` query will not change any existing data in the database.

If you want to leave the transaction without saving, you can issue the `ROLLBACK` command which will discard everything up to the start of the transaction.

If you decide to save your changes, you can use the `COMMIT` command to commit. This cannot be undone.

It is worth knowing that a single error will terminate the entire transaction block.

### Indexing and Speed

To support the next few examples, you will need to import the examples.sql file in this repo: 

```sh
psql -h 127.0.0.1 -p 5432 -U postgres -f examples.sql

```

The example SQL file will create a new table with one million randomly generated rows.

To examine the different data types, we have the following:

```
postgres=# \d techtalk.data
                  Table "techtalk.data"
    Column    |  Type   | Collation | Nullable | Default
--------------+---------+-----------+----------+---------
 name         | text    |           |          |
 coin_flip    | text    |           |          |
 lucky_number | integer |           |          |
 my_bool      | boolean |           |          |

postgres=# select * from techtalk.data limit 1;
    name    | coin_flip | lucky_number | my_bool
------------+-----------+--------------+---------
 foobar-409 | heads     |          244 | f
(1 row)
```

Lets turn on timing and run some queries:

Some data types are faster to retrieve than others in a query. For example, in the following queries we select just `heads` or `tails` and compare the timing with filtering on a boolean.

```
postgres=# \timing
Timing is on.
postgres=#

postgres=# select count(*) from techtalk.data where coin_flip = 'tails';
 count
--------
 500550
(1 row)

Time: 185.956 ms

postgres=# select count(*) from techtalk.data where coin_flip = 'heads';
 count
--------
 499450
(1 row)

Time: 179.647 ms

postgres=# select count(*) from techtalk.data where my_bool = true;
 count
--------
 499886
(1 row)

Time: 113.947 ms

postgres=# select count(*) from techtalk.data where my_bool = false;
 count
--------
 500114
(1 row)

Time: 116.608 ms

```

Lets investigate the planning and execution of the queries:

```
postgres=# explain analyze select count(*) from techtalk.data where my_bool = true;
                                                     QUERY PLAN
---------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=18516.58..18516.59 rows=1 width=8) (actual time=7707.488..7707.495 rows=1 loops=1)
   ->  Seq Scan on data  (cost=0.00..17272.00 rows=497833 width=0) (actual time=0.041..3912.131 rows=499886 loops=1)
         Filter: my_bool
         Rows Removed by Filter: 500114
 Planning time: 0.090 ms
 Execution time: 7707.577 ms
(6 rows)

Time: 7736.357 ms (00:07.736)
```

```
postgres=# explain analyze select count(*) from techtalk.data where coin_flip = 'heads';
                                                     QUERY PLAN
---------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=21004.58..21004.59 rows=1 width=8) (actual time=8095.654..8095.661 rows=1 loops=1)
   ->  Seq Scan on data  (cost=0.00..19772.00 rows=493033 width=0) (actual time=0.042..4227.956 rows=499450 loops=1)
         Filter: (coin_flip = 'heads'::text)
         Rows Removed by Filter: 500550
 Planning time: 0.100 ms
 Execution time: 8095.743 ms
(6 rows)

Time: 8091.557 ms (00:08.092)
```

It can be hard to see exactly where most of the execution time is being spent, but tools like https://explain.depesz.com/ can help break it down.

In both cases, the Seq Scan (Sequential scan) of all rows in the table is slowing things down significantly. To make things faster, we are going to add some indexes and see how the timing changes.

There are a number of index types to choose from in PostgreSQL depending on the data you have: 

- B-Tree
- Generalized Inverted Index (GIN)
- Generalized Inverted Seach Tree (GiST)
- Space partitioned GiST (SP-GiST)
- Block Range Indexes (BRIN)
- Hash

**B-Tree**
The default and most common index type. It works well for most common data types such as text, numbers, and timestamps.

**GIN**
GIN indexes are most useful when you have data types that contain multiple values in a single column such as Arrays, Ranges and JSONB. Since they are designed with these types in mind, GIN indexes do not work with all column types.

**GiST**
GiST indexes are most useful when you have data that can in some way overlap with the value of that same column but from another row. They are used extensively in geometry and spatial queries as well as full text search. GiST indexes are lossy as they have a fixed size which discards some of the data used which can result in false matches.

**SP-GiST**
Space partitioned GiST indexes leverage space partitioning trees and are most useful when your data has a natural clustering element to it, and is also not an equally balanced tree. A great example of this is phone numbers.

**BRIN**
If you’re querying against a large set of data that is naturally grouped together over millions of rows (such as post codes or sort codes) a BRIN index can offer significant space savings over other index types with similar performance.

**Hash**
Hash indexes at times can provide faster lookups than B-Tree indexes, and can boast faster creation times as well. The big issue with them is they’re limited to only equality operators so you need to be looking for exact matches. This makes hash indexes far less flexible than the more commonly used B-Tree indexes and something you won’t want to consider as a drop-in replacement but rather a special case.

**Index Summary**

- B-Tree - For most datatypes and queries
- GIN - For JSONB/hstore/arrays
- GiST - For full text search and geospatial datatypes
- SP-GiST - For larger datasets with natural but uneven clustering
- BRIN - For really large datasets that line up sequentially
- Hash - For equality operations, and generally B-Tree still what you want here.

### Index all the things

```
postgres=# create index on techtalk.data using btree (coin_flip);
CREATE INDEX

postgres=# create index on techtalk.data using btree (my_bool);
CREATE INDEX

postgres=# select count(*) from techtalk.data where coin_flip = 'heads';
 count
--------
 499450
(1 row)

Time: 158.387 ms

postgres=# select count(*) from techtalk.data where my_bool = true;
 count
--------
 499474
(1 row)

Time: 102.099 ms
```

Sometimes the query planner will decide not to use an index if it won't benefit execution time greatly. You can `"force"` PostgreSQL to use an index for testing:

```
set enable_seqscan=false;
```

```
postgres=# select count(*) from techtalk.data where coin_flip = 'heads';
 count
--------
 499735
(1 row)

Time: 102.598 ms

postgres=# select count(*) from techtalk.data where my_bool = true;
 count
--------
 499474
(1 row)

Time: 110.735 ms

```
