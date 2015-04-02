
BEGIN
--spadki miesieczne  miedzy miesiacem styczen a luty
--M01,2015, M02,2015
UPDATE
"doTurnover" t1
SET "CreditDrop" = NVL((SELECT NVL(t2."Credit",0) FROM "doTurnover" t2 WHERE t2."Customer"=t1."Customer" and "Year"='2015' AND "Period"='M01'),0) - NVL(t1."Credit", 0)
WHERE "Year"='2015' AND "Period"='M02' ;

UPDATE
"doTransactionTurnover" t1
SET "CreditDrop" = Nvl((SELECT NVL(t2."Credit",0) FROM "doTransactionTurnover" t2 WHERE t2."Customer"=t1."Customer" and "Year"='2015' AND "Period"='M01' AND t2."TransactionType"=t1."TransactionType"),0)
- NVL(t1."Credit", 0) 
WHERE "Year"='2015' AND "Period"='M02' ;

UPDATE
"doSuffixTurnover" t1
SET "CreditDrop" = Nvl((SELECT NVL(t2."Credit",0) FROM "doSuffixTurnover" t2 WHERE t2."Customer"=t1."Customer" and "Year"='2015' AND "Period"='M01' AND t2."Suffix"=t1."Suffix"),0)
- NVL(t1."Credit", 0) 
WHERE "Year"='2015' AND "Period"='M02' ;


UPDATE
"doExcludedTurnover" t1
SET "CreditDrop" = NVL((SELECT NVL(t2."Credit",0) FROM "doExcludedTurnover" t2 WHERE t2."Customer"=t1."Customer" and t2."ExcludedAccount"=t1."ExcludedAccount" and "Year"='2015' AND "Period"='M01'),0)
- NVL(t1."Credit", 0) 
WHERE "Year"='2015' AND "Period"='M02';

--Nie musimy liczyc spadku 02 do 03 bo nie ma jeszcze marca w miesiącach wyliczonych (dopiero w cyklu kwietniowym takowe przeliczenie sie odbedzie)
END;