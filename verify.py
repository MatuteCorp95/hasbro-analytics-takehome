import sqlite3, sys
con = sqlite3.connect(r'data\sr_analytics_engineer_test.sqlite')
cur = con.cursor()
queries = sys.argv[1:] or ['select name from sqlite_master where type=\'table\' order by name']
for q in queries:
    print(f"\n--- {q[:80]} ---")
    try:
        for r in cur.execute(q): print(r)
    except Exception as e:
        print(f"ERROR: {e}")