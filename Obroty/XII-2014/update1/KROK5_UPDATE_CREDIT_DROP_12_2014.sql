
BEGIN
--spadki miesieczne  miedzy miesiacem listopad a grudzien
--  "PastTurnover"."Credit" - NVL("Data"."Credit", 0) + NVL("Data"."CreditExcluded", 0)                             "CreditDrop",
--M11,2014 -M12,2014
UPDATE
"doTurnover" t1
SET "CreditDrop" = NVL((SELECT NVL(t2."Credit",0) FROM "doTurnover" t2 WHERE t2."Customer"=t1."Customer" and "Year"='2014' AND "Period"='M11'),0) - NVL(t1."Credit", 0) + NVL(t1."CreditExcluded", 0) 
WHERE "Year"='2014' AND "Period"='M12' ;

UPDATE
"doTransactionTurnover" t1
SET "CreditDrop" = Nvl( (SELECT NVL(t2."Credit",0) FROM "doTransactionTurnover" t2 WHERE t2."Customer"=t1."Customer" and "Year"='2014' AND "Period"='M11' AND t2."TransactionType"=t1."TransactionType"),0)
- NVL(t1."Credit", 0) + NVL(t1."CreditExcluded", 0) 
WHERE "Year"='2014' AND "Period"='M12' ;

UPDATE
"doSuffixTurnover" t1
SET "CreditDrop" = Nvl((SELECT NVL(t2."Credit",0) FROM "doSuffixTurnover" t2 WHERE t2."Customer"=t1."Customer" and "Year"='2014' AND "Period"='M11' AND t2."Suffix"=t1."Suffix"),0)
- NVL(t1."Credit", 0) + NVL(t1."CreditExcluded", 0) 
WHERE "Year"='2014' AND "Period"='M12' ;


UPDATE
"doExcludedTurnover" t1
SET "CreditDrop" = NVL((SELECT NVL(t2."Credit",0)- NVL(t2."CreditExcluded", 0) FROM "doExcludedTurnover" t2 WHERE t2."Customer"=t1."Customer" and "Year"='2014' AND "Period"='M11'),0)
- NVL(t1."Credit", 0) + NVL(t1."CreditExcluded", 0) 
WHERE "Year"='2014' AND "Period"='M12';

--spadki miesieczne  miedzy miesiacem grudzien a styczen wpisywane w styczen
--M12,2014 -M01,2015
UPDATE
"doTurnover" t1
SET "CreditDrop" = NVL((SELECT NVL(t2."Credit",0) FROM "doTurnover" t2 WHERE t2."Customer"=t1."Customer" and "Year"='2014' AND "Period"='M12'),0) - NVL(t1."Credit", 0) + NVL(t1."CreditExcluded", 0) 
WHERE "Year"='2015' AND "Period"='M01' ;

UPDATE
"doTransactionTurnover" t1
SET "CreditDrop" = Nvl( (SELECT NVL(t2."Credit",0) FROM "doTransactionTurnover" t2 WHERE t2."Customer"=t1."Customer" and "Year"='2014' AND "Period"='M12' AND t2."TransactionType"=t1."TransactionType"),0)
- NVL(t1."Credit", 0) + NVL(t1."CreditExcluded", 0) 
WHERE "Year"='2015' AND "Period"='M01' ;

UPDATE
"doSuffixTurnover" t1
SET "CreditDrop" = Nvl((SELECT NVL(t2."Credit",0) FROM "doSuffixTurnover" t2 WHERE t2."Customer"=t1."Customer" and "Year"='2014' AND "Period"='M12' AND t2."Suffix"=t1."Suffix"),0)
- NVL(t1."Credit", 0) + NVL(t1."CreditExcluded", 0) 
WHERE "Year"='2015' AND "Period"='M01' ;


UPDATE
"doExcludedTurnover" t1
SET "CreditDrop" = NVL((SELECT NVL(t2."Credit",0)- NVL(t2."CreditExcluded", 0) FROM "doExcludedTurnover" t2 WHERE t2."Customer"=t1."Customer" and "Year"='2014' AND "Period"='M12'),0)
- NVL(t1."Credit", 0) + NVL(t1."CreditExcluded", 0) 
WHERE "Year"='2015' AND "Period"='M01';

END;