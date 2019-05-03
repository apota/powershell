Powershell tools for everyday programming

1. sql_table_differ: 

		Diff data in two RDBMS tables using ANSI SQL to generate CSV reports of rows added, deleted and columns 
		changed (with their old and new value listed). Comes in handy when you are about to import a large data 
		set on to your production table, you might want to compare the staging table with the live table.  

2. reverse_phone_lookup (for reals, not a bait):

        Pass in a US phone number in the format XXX-XXX-XXXX and this will spit out the owner of that phone. 
        DISCLAIMER: The website scraped by this script for this phone may not keep an accurate database of 
        the phone record. Yes, whitepages do reverse lookup, but they won't give you the name for free.
        
        Usage: ./reverse_phone_lookup 800-555-1212
