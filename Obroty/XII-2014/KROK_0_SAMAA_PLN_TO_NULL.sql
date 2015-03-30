BEGIN 
UPDATE T_EQU_SAPF set "SAAMA_PLN"=NULL
  WHERE  "SAVFR" >= (SELECT To_Date('01-12-2014','dd-mm-yyyy') FROM dual) AND "SAVFR" <= (SELECT To_Date('31-12-2014','dd-mm-yyyy') FROM dual);
END;
