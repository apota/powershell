Powershell tools for everyday programming

1. sql_table_differ: 

		Diff two RDBMS tables using ANSI SQL to generate adds,deletes and column level changes in CSV format. Useful for sanity check prior to importing a large data set on to your production table. Currently supports only Oracle (connectivity), but the SQL used for diffing is ANSI and should work with PostgresSQL, MySQL, SQL Server. etc. 