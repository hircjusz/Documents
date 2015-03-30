DECLARE
  BEGIN
     DELETE FROM "doTurnover"             WHERE "Year" = 2014 AND "Period" = 'M12' AND "Customer"  IS NULL OR "Customer"=0;
    
    DELETE FROM "doSuffixTurnover"       WHERE "Year" = 2014 AND "Period" = 'M12' AND "Customer"  IS NULL OR "Customer"=0;
    
    DELETE FROM "doTransactionTurnover"  WHERE "Year" = 2014 AND "Period" = 'M12' AND "Customer"  IS NULL OR "Customer"=0;
    
    DELETE FROM "doExcludedTurnover"     WHERE "Year" = 2014 AND "Period" = 'M12' AND "Customer"  IS NULL OR "Customer"=0;
 END;


