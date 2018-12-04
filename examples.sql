---
--- Example SQL 
---

DROP SCHEMA techtalk CASCADE;
CREATE SCHEMA techtalk;

CREATE TABLE techtalk.data as (
  SELECT 
    'foobar-' || cast(trunc(random() * 1000) as text) as name,
    (CASE random()::INTEGER WHEN 0 THEN 'heads' WHEN 1 THEN 'tails' END) as coin_flip,
    cast(trunc(random() * 1000) as int) as lucky_number,
    (CASE random()::INTEGER WHEN 0 THEN False WHEN 1 THEN True END) as my_bool
  FROM 
    generate_series(1, 1000000) AS num
);