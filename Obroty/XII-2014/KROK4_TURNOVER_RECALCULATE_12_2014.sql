 -- Auto generated content. Do not modify!
DECLARE
    currentSchema               NVARCHAR2(100);
    turnoverDateOverride        DATE DEFAULT NULL;

    configExists                NUMBER(1);
    turnoverTypeID              NUMBER(10);
    turnoverSuffixTypeID        NUMBER(10);
    turnoverTransactionTypeID   NUMBER(10);
    turnoverExcludedTypeID      NUMBER(10);
    turnoverDate                DATE;
    dataDate                    DATE DEFAULT SYSDATE;
    dateFrom                    DATE;
    dateTo                      DATE;
    dateYear                    NUMBER(10);
    datePeriod                  VARCHAR2(3);
    dropDateYear                NUMBER(10);
    dropDatePeriod              VARCHAR2(3);

    dateYearFrom                NUMBER(10);
    dateYearMid                 NUMBER(10);
    dateYearTo                  NUMBER(10);
    datePeriodFrom              VARCHAR2(3);
    datePeriodMid               VARCHAR2(3);
    datePeriodTo                VARCHAR2(3);

    -- Potrzebne do aktualizacji flagi FRESH w SAPF
    TYPE tRowidArray            IS TABLE OF ROWID INDEX BY BINARY_INTEGER;
    TYPE tRec                   IS RECORD (
        rowid     tRowidArray,
        fresh     dbms_sql.number_table,
        changed   dbms_sql.number_table
    );

    bulkCheck                   NUMBER;
    bulkRecord                  tRec;
    bulkArraySize               NUMBER DEFAULT 10;
    bulkCounter                 NUMBER DEFAULT 1;
    bulkDone                    BOOLEAN;
    bulkStartTime               DATE;
BEGIN	
	
    -- Get TypeIDs
    SELECT "ID" INTO turnoverTypeID FROM "doSysTypes" WHERE "Value" = 'SoftwareMind.Turnover';
    SELECT "ID" INTO turnoverSuffixTypeID FROM "doSysTypes" WHERE "Value" = 'SoftwareMind.SuffixTurnover';
    SELECT "ID" INTO turnoverTransactionTypeID FROM "doSysTypes" WHERE "Value" = 'SoftwareMind.TransactionTurnover';
    SELECT "ID" INTO turnoverExcludedTypeID FROM "doSysTypes" WHERE "Value" = 'SoftwareMind.ExcludedTurnover';


    -- Przedzial dat
    dateFrom    := to_date('01-12-2014','dd-mm-yyyy');
    dateTo      :=  to_date('01-01-2015','dd-mm-yyyy');

    --------------------------------------------------------------------------------
    ------------------------------ Obroty  miesięczne ------------------------------
    --------------------------------------------------------------------------------
    dateYear        := TO_CHAR(dateFrom, 'YYYY');
    datePeriod      := 'M' || TO_CHAR(dateFrom, 'MM');
    dropDateYear    := TO_CHAR(add_months(dateFrom, -1), 'YYYY');
    dropDatePeriod  := 'M' || TO_CHAR(add_months(dateFrom, -1), 'MM');

    -- Czyszczenie tabeli w razie ponownego uruchomienia zadania
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Deleting old turnovers for ' || datePeriod || ', ' || dateYear);
    DELETE FROM "doTurnover"             WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTurnover"             WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doSuffixTurnover"       WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doSuffixTurnover"       WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTransactionTurnover"  WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTransactionTurnover"  WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doExcludedTurnover"     WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doExcludedTurnover"     WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    COMMIT;

    -- Obroty ogólne
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting general turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditExcluded", "CreditDrop")
    WITH
        "Customer" AS (
            SELECT
                "ID", "Number" "Number"
            FROM
                "doCustomer" "Customer"
            WHERE
                "Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL AND
                "Number" IS NOT NULL AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
        ),
        "ExcludedAccount" AS (
            SELECT "ID", "Customer", "IBAN" FROM "doExcludedAccount"
        ),
        "SCPF" AS (
            SELECT
                "Customer"."ID" "Customer",
                "SCPF"."SCAB",
                "SCPF"."SCAN",
                "SCPF"."SCAS",
                "CONFIG"."DebitType",
                "CONFIG"."CreditType"
            FROM
                T_EQU_SCPF "SCPF" LEFT OUTER JOIN
                T_TURNOVER_CONFIG "CONFIG" ON ("CONFIG"."Suffix" = "SCPF"."SCAS" AND "CONFIG"."Account" = "SCPF"."SCACT") LEFT OUTER JOIN
                "Customer" ON ("Customer"."Number" = "SCPF".SCAN)
            WHERE
                "CONFIG"."Suffix" IS NOT NULL AND "CONFIG"."Account" IS NOT NULL AND ("CONFIG"."DebitType" IS NOT NULL OR "CONFIG"."CreditType" IS NOT NULL) AND
                "Customer"."ID" IS NOT NULL
        ),
        "SAPF" AS (
            SELECT
                "SAAB", "SAAN", "SAAS", "SADRF", "SATCD", "SAAMA_PLN"
            FROM
                T_EQU_SAPF
            WHERE
                BITAND("FRESH", 2) = 0 AND  "SAVFR" >= dateFrom AND "SAVFR" < dateTo
        ),
        "P3PF" AS (
            SELECT "P3REF", "IBAN" FROM T_EQU_P3PF
        ),
        "Data" AS (
            SELECT
                "SCPF"."Customer"                                                                                               "Customer",
                SUM(CASE WHEN "SAPF".SAAMA_PLN < 0                                        THEN -"SAPF".SAAMA_PLN ELSE 0 END)    "Debit",
                SUM(CASE WHEN "SAPF".SAAMA_PLN > 0                                        THEN  "SAPF".SAAMA_PLN ELSE 0 END)    "Credit",
                SUM(CASE WHEN "SAPF".SAAMA_PLN > 0 AND "ExcludedAccount"."ID" IS NOT NULL THEN  "SAPF".SAAMA_PLN ELSE 0 END)    "CreditExcluded"
            FROM
                "SAPF"            LEFT OUTER JOIN
                "SCPF"            ON ("SCPF"."SCAB" = "SAPF"."SAAB" AND "SCPF"."SCAN" = "SAPF".SAAN AND "SCPF"."SCAS" = "SAPF"."SAAS") LEFT OUTER JOIN
                "P3PF"            ON ("P3PF"."P3REF" = "SAPF"."SADRF") LEFT OUTER JOIN
                "ExcludedAccount" ON ("ExcludedAccount"."IBAN" = "P3PF".IBAN AND "ExcludedAccount"."Customer" = "SCPF"."Customer")
            WHERE
                "SCPF"."SCAB" IS NOT NULL AND "SCPF"."SCAN" IS NOT NULL AND "SCPF"."SCAS" IS NOT NULL AND
                (
                    ("SAPF".SAAMA_PLN <= 0 AND "SCPF"."DebitType"  IS NOT NULL AND ("SCPF"."DebitType"  = '*' OR INSTR("SCPF"."DebitType",  "SAPF".SATCD) > 0)) OR
                    ("SAPF".SAAMA_PLN >= 0 AND "SCPF"."CreditType" IS NOT NULL AND ("SCPF"."CreditType" = '*' OR INSTR("SCPF"."CreditType", "SAPF".SATCD) > 0))
                )
            GROUP BY "SCPF"."Customer"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) - NVL("Data"."CreditExcluded", 0)                                                       "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) + NVL("Data"."CreditExcluded", 0)                             "CreditDrop"
            FROM
                "Data" FULL OUTER JOIN
                "doTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverTypeID * 2) + 1, turnoverTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditExcluded", "Data"."CreditDrop"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Wytworzenie obrotów zerowych dla nowych klientów
    INSERT INTO "doTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditExcluded", "CreditDrop")
    WITH
        "Data" AS (
            SELECT
                "Customer"."ID"                                                                                                 "Customer"
            FROM
                "doCustomer" "Customer" LEFT JOIN
                "doTurnover" "Turnover" ON ("Turnover"."Customer" = "Customer"."ID")
            WHERE
                ("Customer"."Status" IS NULL OR "Customer"."Status" <> 'N') AND
                "Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL AND
                "Turnover"."ID" IS NULL AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverTypeID * 2) + 1, turnoverTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", 0, 0, 0, NULL
    FROM
        "Data";
    COMMIT;

    -- Obroty per suffix
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting suffix turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doSuffixTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditExcluded", "CreditDrop", "Suffix")
    WITH
        "Customer" AS (
            SELECT
                "ID", "Number" "Number"
            FROM
                "doCustomer" "Customer"
            WHERE
                "Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL AND
                "Number" IS NOT NULL AND ("EcconKind" IS NULL OR "EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
        ),
        "ExcludedAccount" AS (
            SELECT "ID", "Customer", "IBAN" FROM "doExcludedAccount"
        ),
        "SCPF" AS (
            SELECT
                "Customer"."ID" "Customer",
                "SCPF"."SCAB",
                "SCPF"."SCAN",
                "SCPF"."SCAS",
                "CONFIG"."DebitType",
                "CONFIG"."CreditType"
            FROM
                T_EQU_SCPF "SCPF" LEFT OUTER JOIN
                T_TURNOVER_CONFIG "CONFIG" ON ("CONFIG"."Suffix" = "SCPF"."SCAS" AND "CONFIG"."Account" = "SCPF"."SCACT") LEFT OUTER JOIN
                "Customer" ON ("Customer"."Number" = "SCPF".SCAN)
            WHERE
                "CONFIG"."Suffix" IS NOT NULL AND "CONFIG"."Account" IS NOT NULL AND ("CONFIG"."DebitType" IS NOT NULL OR "CONFIG"."CreditType" IS NOT NULL) AND
                "Customer"."ID" IS NOT NULL
        ),
        "SAPF" AS (
            SELECT
                "SAAB", "SAAN", "SAAS", "SADRF", "SATCD", "SAAMA_PLN"
            FROM
                T_EQU_SAPF
            WHERE
              BITAND("FRESH", 2) = 0 AND "SAVFR" >= dateFrom AND "SAVFR" < dateTo
        ),
        "P3PF" AS (
            SELECT "P3REF", "IBAN" FROM T_EQU_P3PF
        ),
        "Data" AS (
            SELECT
                "SCPF"."Customer"                                                                                               "Customer",
                SUM(CASE WHEN "SAPF".SAAMA_PLN < 0                                        THEN -"SAPF".SAAMA_PLN ELSE 0 END)    "Debit",
                SUM(CASE WHEN "SAPF".SAAMA_PLN > 0                                        THEN  "SAPF".SAAMA_PLN ELSE 0 END)    "Credit",
                SUM(CASE WHEN "SAPF".SAAMA_PLN > 0 AND "ExcludedAccount"."ID" IS NOT NULL THEN  "SAPF".SAAMA_PLN ELSE 0 END)    "CreditExcluded",
                "SAPF".SAAS                                                                                                     "Suffix"
            FROM
                "SAPF"            LEFT OUTER JOIN
                "SCPF"            ON ("SCPF"."SCAB" = "SAPF"."SAAB" AND "SCPF"."SCAN" = "SAPF".SAAN AND "SCPF"."SCAS" = "SAPF"."SAAS") LEFT OUTER JOIN
                "P3PF"            ON ("P3PF"."P3REF" = "SAPF"."SADRF") LEFT OUTER JOIN
                "ExcludedAccount" ON ("ExcludedAccount"."IBAN" = "P3PF".IBAN AND "ExcludedAccount"."Customer" = "SCPF"."Customer")
            WHERE
                "SCPF"."SCAB" IS NOT NULL AND "SCPF"."SCAN" IS NOT NULL AND "SCPF"."SCAS" IS NOT NULL AND
                (
                    ("SAPF".SAAMA_PLN <= 0 AND "SCPF"."DebitType"  IS NOT NULL AND ("SCPF"."DebitType"  = '*' OR INSTR("SCPF"."DebitType",  "SAPF".SATCD) > 0)) OR
                    ("SAPF".SAAMA_PLN >= 0 AND "SCPF"."CreditType" IS NOT NULL AND ("SCPF"."CreditType" = '*' OR INSTR("SCPF"."CreditType", "SAPF".SATCD) > 0))
                )
            GROUP BY "SCPF"."Customer", "SAPF".SAAS
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) - NVL("Data"."CreditExcluded", 0)                                                       "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) + NVL("Data"."CreditExcluded", 0)                             "CreditDrop",
                NVL("Data"."Suffix", "PastTurnover"."Suffix")                                                                   "Suffix"
            FROM
                "Data" LEFT JOIN
                "doSuffixTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."Suffix" = "Data"."Suffix" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverSuffixTypeID * 2) + 1, turnoverSuffixTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditExcluded", "Data"."CreditDrop", "Data"."Suffix"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty per rodzaj transakcji
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting transaction type turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doTransactionTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditExcluded", "CreditDrop", "TransactionType")
    WITH
        "Customer" AS (
            SELECT
                "ID", "Number" "Number"
            FROM
                "doCustomer" "Customer"
            WHERE
                "Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL AND
                "Number" IS NOT NULL AND ("EcconKind" IS NULL OR "EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
        ),
        "ExcludedAccount" AS (
            SELECT "ID", "Customer", "IBAN" FROM "doExcludedAccount"
        ),
        "SCPF" AS (
            SELECT
                "Customer"."ID" "Customer",
                "SCPF"."SCAB",
                "SCPF"."SCAN",
                "SCPF"."SCAS",
                "CONFIG"."DebitType",
                "CONFIG"."CreditType"
            FROM
                T_EQU_SCPF "SCPF" LEFT OUTER JOIN
                T_TURNOVER_CONFIG "CONFIG" ON ("CONFIG"."Suffix" = "SCPF"."SCAS" AND "CONFIG"."Account" = "SCPF"."SCACT") LEFT OUTER JOIN
                "Customer" ON ("Customer"."Number" = "SCPF".SCAN)
            WHERE
                "CONFIG"."Suffix" IS NOT NULL AND "CONFIG"."Account" IS NOT NULL AND ("CONFIG"."DebitType" IS NOT NULL OR "CONFIG"."CreditType" IS NOT NULL) AND
                "Customer"."ID" IS NOT NULL
        ),
        "SAPF" AS (
            SELECT
                "SAAB", "SAAN", "SAAS", "SADRF", "SATCD", "SAAMA_PLN"
            FROM
                T_EQU_SAPF
            WHERE
               BITAND("FRESH", 2) = 0 AND  "SAVFR" >= dateFrom AND "SAVFR" < dateTo
        ),
        "P3PF" AS (
            SELECT "P3REF", "IBAN" FROM T_EQU_P3PF
        ),
        "Data" AS (
            SELECT
                "SCPF"."Customer"                                                                                               "Customer",
                SUM(CASE WHEN "SAPF".SAAMA_PLN < 0                                        THEN -"SAPF".SAAMA_PLN ELSE 0 END)    "Debit",
                SUM(CASE WHEN "SAPF".SAAMA_PLN > 0                                        THEN  "SAPF".SAAMA_PLN ELSE 0 END)    "Credit",
                SUM(CASE WHEN "SAPF".SAAMA_PLN > 0 AND "ExcludedAccount"."ID" IS NOT NULL THEN  "SAPF".SAAMA_PLN ELSE 0 END)    "CreditExcluded",
                "SAPF".SATCD                                                                                                    "TransactionType"
            FROM
                "SAPF"            LEFT OUTER JOIN
                "SCPF"            ON ("SCPF"."SCAB" = "SAPF"."SAAB" AND "SCPF"."SCAN" = "SAPF".SAAN AND "SCPF"."SCAS" = "SAPF"."SAAS") LEFT OUTER JOIN
                "P3PF"            ON ("P3PF"."P3REF" = "SAPF"."SADRF") LEFT OUTER JOIN
                "ExcludedAccount" ON ("ExcludedAccount"."IBAN" = "P3PF".IBAN AND "ExcludedAccount"."Customer" = "SCPF"."Customer")
            WHERE
                "SCPF"."SCAB" IS NOT NULL AND "SCPF"."SCAN" IS NOT NULL AND "SCPF"."SCAS" IS NOT NULL AND
                (
                    ("SAPF".SAAMA_PLN <= 0 AND "SCPF"."DebitType"  IS NOT NULL AND ("SCPF"."DebitType"  = '*' OR INSTR("SCPF"."DebitType",  "SAPF".SATCD) > 0)) OR
                    ("SAPF".SAAMA_PLN >= 0 AND "SCPF"."CreditType" IS NOT NULL AND ("SCPF"."CreditType" = '*' OR INSTR("SCPF"."CreditType", "SAPF".SATCD) > 0))
                )
            GROUP BY "SCPF"."Customer", "SAPF".SATCD
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) - NVL("Data"."CreditExcluded", 0)                                                       "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) + NVL("Data"."CreditExcluded", 0)                             "CreditDrop",
                NVL("Data"."TransactionType", "PastTurnover"."TransactionType")                                                 "TransactionType"
            FROM
                "Data" LEFT JOIN
                "doTransactionTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."TransactionType" = "Data"."TransactionType" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverTransactionTypeID * 2) + 1, turnoverTransactionTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditExcluded", "Data"."CreditDrop", "Data"."TransactionType"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty wykluczone
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting excluded turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doExcludedTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "ExcludedAccount")
    WITH
        "Customer" AS (
            SELECT
                "ID", "Number" "Number"
            FROM
                "doCustomer" "Customer"
            WHERE
                "Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL AND
                "Number" IS NOT NULL AND ("EcconKind" IS NULL OR "EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
        ),
        "ExcludedAccount" AS (
            SELECT "ID", "Customer", "IBAN" FROM "doExcludedAccount"
        ),
        "SCPF" AS (
            SELECT
                "Customer"."ID" "Customer",
                "SCPF"."SCAB",
                "SCPF"."SCAN",
                "SCPF"."SCAS",
                "CONFIG"."DebitType",
                "CONFIG"."CreditType"
            FROM
                T_EQU_SCPF "SCPF" LEFT OUTER JOIN
                T_TURNOVER_CONFIG "CONFIG" ON ("CONFIG"."Suffix" = "SCPF"."SCAS" AND "CONFIG"."Account" = "SCPF"."SCACT") LEFT OUTER JOIN
                "Customer" ON ("Customer"."Number" = "SCPF".SCAN)
            WHERE
                "CONFIG"."Suffix" IS NOT NULL AND "CONFIG"."Account" IS NOT NULL AND ("CONFIG"."DebitType" IS NOT NULL OR "CONFIG"."CreditType" IS NOT NULL) AND
                "Customer"."ID" IS NOT NULL
        ),
        "SAPF" AS (
            SELECT
                "SAAB", "SAAN", "SAAS", "SADRF", "SATCD", "SAAMA_PLN"
            FROM
                T_EQU_SAPF
            WHERE
              BITAND("FRESH", 2) = 0 AND  "SAVFR" >= dateFrom AND "SAVFR" < dateTo
        ),
        "P3PF" AS (
            SELECT "P3REF", "IBAN" FROM T_EQU_P3PF
        ),
        "Data" AS (
            SELECT
                "SCPF"."Customer"                                                                                               "Customer",
                SUM(CASE WHEN "SAPF".SAAMA_PLN < 0                                        THEN -"SAPF".SAAMA_PLN ELSE 0 END)    "Debit",
                SUM(CASE WHEN "SAPF".SAAMA_PLN > 0                                        THEN  "SAPF".SAAMA_PLN ELSE 0 END)    "Credit",
                "ExcludedAccount"."ID"                                                                                          "ExcludedAccount"
            FROM
                "SAPF"            LEFT OUTER JOIN
                "SCPF"            ON ("SCPF"."SCAB" = "SAPF"."SAAB" AND "SCPF"."SCAN" = "SAPF".SAAN AND "SCPF"."SCAS" = "SAPF"."SAAS") LEFT OUTER JOIN
                "P3PF"            ON ("P3PF"."P3REF" = "SAPF"."SADRF") LEFT OUTER JOIN
                "ExcludedAccount" ON ("ExcludedAccount"."IBAN" = "P3PF".IBAN AND "ExcludedAccount"."Customer" = "SCPF"."Customer")
            WHERE
                "ExcludedAccount"."ID" IS NOT NULL AND
                "SCPF"."SCAB" IS NOT NULL AND "SCPF"."SCAN" IS NOT NULL AND "SCPF"."SCAS" IS NOT NULL AND
                (
                    ("SAPF".SAAMA_PLN <= 0 AND "SCPF"."DebitType"  IS NOT NULL AND ("SCPF"."DebitType"  = '*' OR INSTR("SCPF"."DebitType",  "SAPF".SATCD) > 0)) OR
                    ("SAPF".SAAMA_PLN >= 0 AND "SCPF"."CreditType" IS NOT NULL AND ("SCPF"."CreditType" = '*' OR INSTR("SCPF"."CreditType", "SAPF".SATCD) > 0))
                )
            GROUP BY "SCPF"."Customer", "ExcludedAccount"."ID"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0)                                                                                         "Credit",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0)                                                               "CreditDrop",
                NVL("Data"."ExcludedAccount", "PastTurnover"."ExcludedAccount")                                                 "ExcludedAccount"
            FROM
                "Data" LEFT JOIN
                "doExcludedTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."ExcludedAccount" = "Data"."ExcludedAccount" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverExcludedTypeID * 2) + 1, turnoverExcludedTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."ExcludedAccount"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Usunięcie starych obrotów dla klientów nie firmowych
    DELETE FROM "doTurnover" WHERE "ID" IN (
        SELECT
            "Turnover"."ID"
        FROM
            "doTurnover" "Turnover" INNER JOIN
            "doCustomer" "Customer" ON ("Customer"."ID" = "Turnover"."Customer")
        WHERE
            "Customer"."EcconKind" = 'OSF' AND ("Turnover"."Year" < dateYear OR ("Turnover"."Year" = dateYear AND "Turnover"."Period" < datePeriod)) AND
            (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
    );
    COMMIT;


    --------------------------------------------------------------------------------
    --------------------------- Obroty średniomiesięczne ---------------------------
    --------------------------------------------------------------------------------
    dateYear        := TO_CHAR(dateFrom, 'YYYY'); -- rok wyliczenia obrotów
    datePeriod      := 'A' || TO_CHAR(dateFrom, 'MM'); -- okres wyliczenia obrotów (A01-A12)
    dropDateYear    := TO_CHAR(add_months(dateFrom, -1), 'YYYY');
    dropDatePeriod  := 'A' || TO_CHAR(add_months(dateFrom, -1), 'MM');

    dateYearTo      := TO_CHAR(dateFrom, 'YYYY'); -- rok pierwszego miesiąca
    datePeriodTo    := 'M' || TO_CHAR(dateFrom, 'MM'); -- okres pierwszego miesiąca

    dateYearMid     := TO_CHAR(ADD_MONTHS(dateFrom, -1), 'YYYY'); -- rok drugiego miesiąca
    datePeriodMid   := 'M' || TO_CHAR(ADD_MONTHS(dateFrom, -1), 'MM'); -- okres drugiego miesiąca

    dateYearFrom    := TO_CHAR(ADD_MONTHS(dateFrom, -2), 'YYYY'); -- rok trzeciego miesiąca
    datePeriodFrom  := 'M' || TO_CHAR(ADD_MONTHS(dateFrom, -2), 'MM'); -- okres trzeciego miesiąca

    -- Czyszczenie tabeli w razie ponownego uruchomienia zadania
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Deleting old turnovers for ' || datePeriod || ', ' || dateYear);
    DELETE FROM "doTurnover"             WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTurnover"             WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doSuffixTurnover"       WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doSuffixTurnover"       WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTransactionTurnover"  WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTransactionTurnover"  WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doExcludedTurnover"     WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doExcludedTurnover"     WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    COMMIT;

    -- Obroty ogólne
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting general turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "CreditExcluded")
    WITH
        "Data" AS (
            SELECT
                "Turnover"."Customer"                                                                                           "Customer",
                ROUND(SUM("Turnover"."Debit") / 3, 6)                                                                           "Debit",
                ROUND(SUM("Turnover"."Credit") / 3, 6)                                                                          "Credit",
                ROUND(SUM("Turnover"."CreditExcluded") / 3, 6)                                                                  "CreditExcluded"
            FROM
                "doTurnover" "Turnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "Turnover"."Customer")
            WHERE
                (
                    ("Turnover"."Year" = dateYearTo   AND "Turnover"."Period" = datePeriodTo)   OR
                    ("Turnover"."Year" = dateYearMid  AND "Turnover"."Period" = datePeriodMid)  OR
                    ("Turnover"."Year" = dateYearFrom AND "Turnover"."Period" = datePeriodFrom)
                ) AND
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "Turnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0
            GROUP BY "Turnover"."Customer"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) /*- NVL("Data"."CreditExcluded", 0)*/                                                   "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) /*+ NVL("Data"."CreditExcluded", 0)*/                         "CreditDrop"
            FROM
                "Data" FULL OUTER JOIN
                "doTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverTypeID * 2) + 1, turnoverTypeID, 0, dateYear,  datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."CreditExcluded"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty per suffix
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting suffix turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doSuffixTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "Suffix")
    WITH
        "Data" AS (
            SELECT
                "SuffixTurnover"."Customer"                                                                                     "Customer",
                "SuffixTurnover"."Suffix"                                                                                       "Suffix",
                ROUND(SUM("SuffixTurnover"."Debit") / 3, 6)                                                                     "Debit",
                ROUND(SUM("SuffixTurnover"."Credit") / 3, 6)                                                                    "Credit",
                ROUND(SUM("SuffixTurnover"."CreditExcluded") / 3, 6)                                                            "CreditExcluded"
            FROM
                "doSuffixTurnover" "SuffixTurnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "SuffixTurnover"."Customer")
            WHERE
                (
                    ("SuffixTurnover"."Year" = dateYearTo   AND "SuffixTurnover"."Period" = datePeriodTo)   OR
                    ("SuffixTurnover"."Year" = dateYearMid  AND "SuffixTurnover"."Period" = datePeriodMid)  OR
                    ("SuffixTurnover"."Year" = dateYearFrom AND "SuffixTurnover"."Period" = datePeriodFrom)
                ) AND
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "SuffixTurnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0
            GROUP BY "SuffixTurnover"."Customer", "SuffixTurnover"."Suffix"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) /*- NVL("Data"."CreditExcluded", 0)*/                                                   "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) /*+ NVL("Data"."CreditExcluded", 0)*/                         "CreditDrop",
                NVL("Data"."Suffix", "PastTurnover"."Suffix")                                                                   "Suffix"
            FROM
                "Data" LEFT JOIN
                "doSuffixTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."Suffix" = "Data"."Suffix" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverSuffixTypeID * 2) + 1, turnoverSuffixTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."Suffix"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty per rodzaj transakcji
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting transaction type turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doTransactionTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "TransactionType")
    WITH
        "Data" AS (
            SELECT
                "TransactionTurnover"."Customer"                                                                                "Customer",
                "TransactionTurnover"."TransactionType"                                                                         "TransactionType",
                ROUND(SUM("TransactionTurnover"."Debit") / 3, 6)                                                                "Debit",
                ROUND(SUM("TransactionTurnover"."Credit") / 3, 6)                                                               "Credit",
                ROUND(SUM("TransactionTurnover"."CreditExcluded") / 3, 6)                                                       "CreditExcluded"
            FROM
                "doTransactionTurnover" "TransactionTurnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "TransactionTurnover"."Customer")
            WHERE
                (
                    ("TransactionTurnover"."Year" = dateYearTo   AND "TransactionTurnover"."Period" = datePeriodTo)   OR
                    ("TransactionTurnover"."Year" = dateYearMid  AND "TransactionTurnover"."Period" = datePeriodMid)  OR
                    ("TransactionTurnover"."Year" = dateYearFrom AND "TransactionTurnover"."Period" = datePeriodFrom)
                ) AND
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "TransactionTurnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0
            GROUP BY "TransactionTurnover"."Customer", "TransactionTurnover"."TransactionType"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) /*- NVL("Data"."CreditExcluded", 0)*/                                                   "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) /*+ NVL("Data"."CreditExcluded", 0)*/                         "CreditDrop",
                NVL("Data"."TransactionType", "PastTurnover"."TransactionType")                                                 "TransactionType"
            FROM
                "Data" LEFT JOIN
                "doTransactionTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."TransactionType" = "Data"."TransactionType" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverTransactionTypeID * 2) + 1, turnoverTransactionTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."TransactionType"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty wykluczone
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting excluded turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doExcludedTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "ExcludedAccount")
    WITH
        "Data" AS (
            SELECT
                "ExcludedTurnover"."Customer"                                                                                   "Customer",
                "ExcludedTurnover"."ExcludedAccount"                                                                            "ExcludedAccount",
                ROUND(SUM("ExcludedTurnover"."Debit") / 3, 6)                                                                   "Debit",
                ROUND(SUM("ExcludedTurnover"."Credit") / 3, 6)                                                                  "Credit",
                ROUND(SUM("ExcludedTurnover"."CreditExcluded") / 3, 6)                                                          "CreditExcluded"
            FROM
                "doExcludedTurnover" "ExcludedTurnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "ExcludedTurnover"."Customer")
            WHERE
                (
                    ("ExcludedTurnover"."Year" = dateYearTo   AND "ExcludedTurnover"."Period" = datePeriodTo)   OR
                    ("ExcludedTurnover"."Year" = dateYearMid  AND "ExcludedTurnover"."Period" = datePeriodMid)  OR
                    ("ExcludedTurnover"."Year" = dateYearFrom AND "ExcludedTurnover"."Period" = datePeriodFrom)
                ) AND
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "ExcludedTurnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0
            GROUP BY "ExcludedTurnover"."Customer", "ExcludedTurnover"."ExcludedAccount"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0)                                                                                         "Credit",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0)                                                               "CreditDrop",
                NVL("Data"."ExcludedAccount", "PastTurnover"."ExcludedAccount")                                                 "ExcludedAccount"
            FROM
                "Data" LEFT JOIN
                "doExcludedTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."ExcludedAccount" = "Data"."ExcludedAccount" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverExcludedTypeID * 2) + 1, turnoverExcludedTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."ExcludedAccount"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    --------------------------------------------------------------------------------
    ------------------------------- Obroty kwartalne -------------------------------
    --------------------------------------------------------------------------------
    dateYear        := TO_CHAR(dateFrom, 'YYYY');
    datePeriod      := 'Q0' || FLOOR(TO_CHAR(dateFrom, 'MM') / 3);
    dropDateYear    := TO_CHAR(add_months(dateFrom, -3), 'YYYY');
    dropDatePeriod  := 'Q0' || FLOOR(TO_CHAR(add_months(dateFrom, -3), 'MM') / 3);

    IF MOD(TO_CHAR(dateFrom, 'MM'), 3) = 0 THEN

    dateYearTo      := TO_CHAR(dateFrom, 'YYYY'); -- rok
    datePeriodTo    := 'M' || TO_CHAR(dateFrom, 'MM'); -- ostatni miesiąc kwartalu
    datePeriodFrom  := 'M' || TO_CHAR(ADD_MONTHS(dateFrom, -2), 'MM'); -- pierwszy miesiąc kwartalu

    -- Czyszczenie tabeli w razie ponownego uruchomienia zadania
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Deleting old turnovers for ' || datePeriod || ', ' || dateYear);
    DELETE FROM "doTurnover"             WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTurnover"             WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doSuffixTurnover"       WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doSuffixTurnover"       WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTransactionTurnover"  WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTransactionTurnover"  WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doExcludedTurnover"     WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doExcludedTurnover"     WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    COMMIT;

    -- Obroty ogólne
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting general turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "CreditExcluded")
    WITH
        "Data" AS (
            SELECT
                "Turnover"."Customer"                                                                                           "Customer",
                SUM("Turnover"."Debit")                                                                                         "Debit",
                SUM("Turnover"."Credit")                                                                                        "Credit",
                SUM("Turnover"."CreditExcluded")                                                                                "CreditExcluded"
            FROM
                "doTurnover" "Turnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "Turnover"."Customer")
            WHERE
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("Turnover"."Year" = dateYearTo AND "Turnover"."Period" <= datePeriodTo AND "Turnover"."Period" >= datePeriodFrom) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "Turnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0 -- muszą być policzone obroty za pierwszy miesiąc kwartału / półrocza / roku
            GROUP BY "Turnover"."Customer"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) /*- NVL("Data"."CreditExcluded", 0)*/                                                   "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) /*+ NVL("Data"."CreditExcluded", 0)*/                         "CreditDrop"
            FROM
                "Data" FULL OUTER JOIN
                "doTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverTypeID * 2) + 1, turnoverTypeID, 0, dateYear,  datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."CreditExcluded"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty per suffix
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting suffix turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doSuffixTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "Suffix")
    WITH
        "Data" AS (
            SELECT
                "SuffixTurnover"."Customer"                                                                                     "Customer",
                "SuffixTurnover"."Suffix"                                                                                       "Suffix",
                SUM("SuffixTurnover"."Debit")                                                                                   "Debit",
                SUM("SuffixTurnover"."Credit")                                                                                  "Credit",
                SUM("SuffixTurnover"."CreditExcluded")                                                                          "CreditExcluded"
            FROM
                "doSuffixTurnover" "SuffixTurnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "SuffixTurnover"."Customer")
            WHERE
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("SuffixTurnover"."Year" = dateYearTo AND "SuffixTurnover"."Period" <= datePeriodTo AND "SuffixTurnover"."Period" >= datePeriodFrom) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "SuffixTurnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0 -- muszą być policzone obroty za pierwszy miesiąc kwartału / półrocza / roku
            GROUP BY "SuffixTurnover"."Customer", "SuffixTurnover"."Suffix"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) /*- NVL("Data"."CreditExcluded", 0)*/                                                   "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) /*+ NVL("Data"."CreditExcluded", 0)*/                         "CreditDrop",
                NVL("Data"."Suffix", "PastTurnover"."Suffix")                                                                   "Suffix"
            FROM
                "Data" LEFT JOIN
                "doSuffixTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."Suffix" = "Data"."Suffix" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverSuffixTypeID * 2) + 1, turnoverSuffixTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."Suffix"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty per rodzaj transakcji
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting transaction type turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doTransactionTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "TransactionType")
    WITH
        "Data" AS (
            SELECT
                "TransactionTurnover"."Customer"                                                                                "Customer",
                "TransactionTurnover"."TransactionType"                                                                         "TransactionType",
                SUM("TransactionTurnover"."Debit")                                                                              "Debit",
                SUM("TransactionTurnover"."Credit")                                                                             "Credit",
                SUM("TransactionTurnover"."CreditExcluded")                                                                     "CreditExcluded"
            FROM
                "doTransactionTurnover" "TransactionTurnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "TransactionTurnover"."Customer")
            WHERE
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("TransactionTurnover"."Year" = dateYearTo AND "TransactionTurnover"."Period" <= datePeriodTo AND "TransactionTurnover"."Period" >= datePeriodFrom) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "TransactionTurnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0 -- muszą być policzone obroty za pierwszy miesiąc kwartału / półrocza / roku
            GROUP BY "TransactionTurnover"."Customer", "TransactionTurnover"."TransactionType"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) /*- NVL("Data"."CreditExcluded", 0)*/                                                   "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) /*+ NVL("Data"."CreditExcluded", 0)*/                         "CreditDrop",
                NVL("Data"."TransactionType", "PastTurnover"."TransactionType")                                                 "TransactionType"
            FROM
                "Data" LEFT JOIN
                "doTransactionTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."TransactionType" = "Data"."TransactionType" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverTransactionTypeID * 2) + 1, turnoverTransactionTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."TransactionType"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty wykluczone
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting excluded turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doExcludedTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "ExcludedAccount")
    WITH
        "Data" AS (
            SELECT
                "ExcludedTurnover"."Customer"                                                                                   "Customer",
                "ExcludedTurnover"."ExcludedAccount"                                                                            "ExcludedAccount",
                SUM("ExcludedTurnover"."Debit")                                                                                 "Debit",
                SUM("ExcludedTurnover"."Credit")                                                                                "Credit",
                SUM("ExcludedTurnover"."CreditExcluded")                                                                        "CreditExcluded"
            FROM
                "doExcludedTurnover" "ExcludedTurnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "ExcludedTurnover"."Customer")
            WHERE
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("ExcludedTurnover"."Year" = dateYearTo AND "ExcludedTurnover"."Period" <= datePeriodTo AND "ExcludedTurnover"."Period" >= datePeriodFrom) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "ExcludedTurnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0 -- muszą być policzone obroty za pierwszy miesiąc kwartału / półrocza / roku
            GROUP BY "ExcludedTurnover"."Customer", "ExcludedTurnover"."ExcludedAccount"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0)                                                                                         "Credit",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0)                                                               "CreditDrop",
                NVL("Data"."ExcludedAccount", "PastTurnover"."ExcludedAccount")                                                 "ExcludedAccount"
            FROM
                "Data" LEFT JOIN
                "doExcludedTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."ExcludedAccount" = "Data"."ExcludedAccount" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverExcludedTypeID * 2) + 1, turnoverExcludedTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."ExcludedAccount"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    ELSE DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Turnovers for ' || datePeriod || ', ' || dateYear || ' will not be counted'); END IF;


    --------------------------------------------------------------------------------
    ------------------------------- Obroty półroczne -------------------------------
    --------------------------------------------------------------------------------
    dateYear        := TO_CHAR(dateFrom, 'YYYY');
    datePeriod      := 'S0' || FLOOR(TO_CHAR(dateFrom, 'MM') / 6);
    dropDateYear    := TO_CHAR(add_months(dateFrom, -6), 'YYYY');
    dropDatePeriod  := 'S0' || FLOOR(TO_CHAR(add_months(dateFrom, -6), 'MM') / 6);

    IF MOD(TO_CHAR(dateFrom, 'MM'), 6) = 0 THEN

    dateYearTo      := TO_CHAR(dateFrom, 'YYYY'); -- rok
    datePeriodTo    := 'M' || TO_CHAR(dateFrom, 'MM') ; -- ostatni miesiąc pólrocza
    datePeriodFrom  := 'M' || TO_CHAR(ADD_MONTHS(dateFrom, -5), 'MM'); -- pierwszy miesiąc pólrocza

    -- Czyszczenie tabeli w razie ponownego uruchomienia zadania
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Deleting old turnovers for ' || datePeriod || ', ' || dateYear);
    DELETE FROM "doTurnover"             WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTurnover"             WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doSuffixTurnover"       WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doSuffixTurnover"       WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTransactionTurnover"  WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTransactionTurnover"  WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doExcludedTurnover"     WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doExcludedTurnover"     WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    COMMIT;

    -- Obroty ogólne
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting general turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "CreditExcluded")
    WITH
        "Data" AS (
            SELECT
                "Turnover"."Customer"                                                                                           "Customer",
                SUM("Turnover"."Debit")                                                                                         "Debit",
                SUM("Turnover"."Credit")                                                                                        "Credit",
                SUM("Turnover"."CreditExcluded")                                                                                "CreditExcluded"
            FROM
                "doTurnover" "Turnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "Turnover"."Customer")
            WHERE
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("Turnover"."Year" = dateYearTo AND "Turnover"."Period" <= datePeriodTo AND "Turnover"."Period" >= datePeriodFrom) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "Turnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0 -- muszą być policzone obroty za pierwszy miesiąc kwartału / półrocza / roku
            GROUP BY "Turnover"."Customer"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) /*- NVL("Data"."CreditExcluded", 0)*/                                                   "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) /*+ NVL("Data"."CreditExcluded", 0)*/                         "CreditDrop"
            FROM
                "Data" FULL OUTER JOIN
                "doTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverTypeID * 2) + 1, turnoverTypeID, 0, dateYear,  datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."CreditExcluded"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty per suffix
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting suffix turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doSuffixTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "Suffix")
    WITH
        "Data" AS (
            SELECT
                "SuffixTurnover"."Customer"                                                                                     "Customer",
                "SuffixTurnover"."Suffix"                                                                                       "Suffix",
                SUM("SuffixTurnover"."Debit")                                                                                   "Debit",
                SUM("SuffixTurnover"."Credit")                                                                                  "Credit",
                SUM("SuffixTurnover"."CreditExcluded")                                                                          "CreditExcluded"
            FROM
                "doSuffixTurnover" "SuffixTurnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "SuffixTurnover"."Customer")
            WHERE
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("SuffixTurnover"."Year" = dateYearTo AND "SuffixTurnover"."Period" <= datePeriodTo AND "SuffixTurnover"."Period" >= datePeriodFrom) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "SuffixTurnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0 -- muszą być policzone obroty za pierwszy miesiąc kwartału / półrocza / roku
            GROUP BY "SuffixTurnover"."Customer", "SuffixTurnover"."Suffix"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) /*- NVL("Data"."CreditExcluded", 0)*/                                                   "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) /*+ NVL("Data"."CreditExcluded", 0)*/                         "CreditDrop",
                NVL("Data"."Suffix", "PastTurnover"."Suffix")                                                                   "Suffix"
            FROM
                "Data" LEFT JOIN
                "doSuffixTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."Suffix" = "Data"."Suffix" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverSuffixTypeID * 2) + 1, turnoverSuffixTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."Suffix"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty per rodzaj transakcji
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting transaction type turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doTransactionTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "TransactionType")
    WITH
        "Data" AS (
            SELECT
                "TransactionTurnover"."Customer"                                                                                "Customer",
                "TransactionTurnover"."TransactionType"                                                                         "TransactionType",
                SUM("TransactionTurnover"."Debit")                                                                              "Debit",
                SUM("TransactionTurnover"."Credit")                                                                             "Credit",
                SUM("TransactionTurnover"."CreditExcluded")                                                                     "CreditExcluded"
            FROM
                "doTransactionTurnover" "TransactionTurnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "TransactionTurnover"."Customer")
            WHERE
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("TransactionTurnover"."Year" = dateYearTo AND "TransactionTurnover"."Period" <= datePeriodTo AND "TransactionTurnover"."Period" >= datePeriodFrom) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "TransactionTurnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0 -- muszą być policzone obroty za pierwszy miesiąc kwartału / półrocza / roku
            GROUP BY "TransactionTurnover"."Customer", "TransactionTurnover"."TransactionType"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) /*- NVL("Data"."CreditExcluded", 0)*/                                                   "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) /*+ NVL("Data"."CreditExcluded", 0)*/                         "CreditDrop",
                NVL("Data"."TransactionType", "PastTurnover"."TransactionType")                                                 "TransactionType"
            FROM
                "Data" LEFT JOIN
                "doTransactionTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."TransactionType" = "Data"."TransactionType" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverTransactionTypeID * 2) + 1, turnoverTransactionTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."TransactionType"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty wykluczone
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting excluded turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doExcludedTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "ExcludedAccount")
    WITH
        "Data" AS (
            SELECT
                "ExcludedTurnover"."Customer"                                                                                   "Customer",
                "ExcludedTurnover"."ExcludedAccount"                                                                            "ExcludedAccount",
                SUM("ExcludedTurnover"."Debit")                                                                                 "Debit",
                SUM("ExcludedTurnover"."Credit")                                                                                "Credit",
                SUM("ExcludedTurnover"."CreditExcluded")                                                                        "CreditExcluded"
            FROM
                "doExcludedTurnover" "ExcludedTurnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "ExcludedTurnover"."Customer")
            WHERE
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("ExcludedTurnover"."Year" = dateYearTo AND "ExcludedTurnover"."Period" <= datePeriodTo AND "ExcludedTurnover"."Period" >= datePeriodFrom) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "ExcludedTurnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0 -- muszą być policzone obroty za pierwszy miesiąc kwartału / półrocza / roku
            GROUP BY "ExcludedTurnover"."Customer", "ExcludedTurnover"."ExcludedAccount"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0)                                                                                         "Credit",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0)                                                               "CreditDrop",
                NVL("Data"."ExcludedAccount", "PastTurnover"."ExcludedAccount")                                                 "ExcludedAccount"
            FROM
                "Data" LEFT JOIN
                "doExcludedTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."ExcludedAccount" = "Data"."ExcludedAccount" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverExcludedTypeID * 2) + 1, turnoverExcludedTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."ExcludedAccount"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    ELSE DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Turnovers for ' || datePeriod || ', ' || dateYear || ' will not be counted'); END IF;


    --------------------------------------------------------------------------------
    -------------------------------- Obroty  roczne --------------------------------
    --------------------------------------------------------------------------------
    dateYear        := TO_CHAR(dateFrom, 'YYYY');
    datePeriod      := 'Y';
    dropDateYear    := TO_CHAR(add_months(dateFrom, -12), 'YYYY');
    dropDatePeriod  := 'Y';

    IF MOD(TO_CHAR(dateFrom, 'MM'), 12) = 0 THEN

    dateYearTo      := TO_CHAR(dateFrom, 'YYYY'); -- rok
    datePeriodTo    := 'M12';
    datePeriodFrom  := 'M01';

    -- Czyszczenie tabeli w razie ponownego uruchomienia zadania
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Deleting old turnovers for ' || datePeriod || ', ' || dateYear);
    DELETE FROM "doTurnover"             WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTurnover"             WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doSuffixTurnover"       WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doSuffixTurnover"       WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTransactionTurnover"  WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doTransactionTurnover"  WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doExcludedTurnover"     WHERE "Year" = dateYear - 5 AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    DELETE FROM "doExcludedTurnover"     WHERE "Year" = dateYear     AND "Period" = datePeriod AND "Customer" IN (SELECT "ID" FROM "doCustomer" "Customer" WHERE (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/));
    COMMIT;

    -- Obroty ogólne
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting general turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "CreditExcluded")
    WITH
        "Data" AS (
            SELECT
                "Turnover"."Customer"                                                                                           "Customer",
                SUM("Turnover"."Debit")                                                                                         "Debit",
                SUM("Turnover"."Credit")                                                                                        "Credit",
                SUM("Turnover"."CreditExcluded")                                                                                "CreditExcluded"
            FROM
                "doTurnover" "Turnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "Turnover"."Customer")
            WHERE
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("Turnover"."Year" = dateYearTo AND "Turnover"."Period" <= datePeriodTo AND "Turnover"."Period" >= datePeriodFrom) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "Turnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0 -- muszą być policzone obroty za pierwszy miesiąc kwartału / półrocza / roku
            GROUP BY "Turnover"."Customer"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) /*- NVL("Data"."CreditExcluded", 0)*/                                                   "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) /*+ NVL("Data"."CreditExcluded", 0)*/                         "CreditDrop"
            FROM
                "Data" FULL OUTER JOIN
                "doTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverTypeID * 2) + 1, turnoverTypeID, 0, dateYear,  datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."CreditExcluded"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty per suffix
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting suffix turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doSuffixTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "Suffix")
    WITH
        "Data" AS (
            SELECT
                "SuffixTurnover"."Customer"                                                                                     "Customer",
                "SuffixTurnover"."Suffix"                                                                                       "Suffix",
                SUM("SuffixTurnover"."Debit")                                                                                   "Debit",
                SUM("SuffixTurnover"."Credit")                                                                                  "Credit",
                SUM("SuffixTurnover"."CreditExcluded")                                                                          "CreditExcluded"
            FROM
                "doSuffixTurnover" "SuffixTurnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "SuffixTurnover"."Customer")
            WHERE
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("SuffixTurnover"."Year" = dateYearTo AND "SuffixTurnover"."Period" <= datePeriodTo AND "SuffixTurnover"."Period" >= datePeriodFrom) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "SuffixTurnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0 -- muszą być policzone obroty za pierwszy miesiąc kwartału / półrocza / roku
            GROUP BY "SuffixTurnover"."Customer", "SuffixTurnover"."Suffix"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) /*- NVL("Data"."CreditExcluded", 0)*/                                                   "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) /*+ NVL("Data"."CreditExcluded", 0)*/                         "CreditDrop",
                NVL("Data"."Suffix", "PastTurnover"."Suffix")                                                                   "Suffix"
            FROM
                "Data" LEFT JOIN
                "doSuffixTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."Suffix" = "Data"."Suffix" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverSuffixTypeID * 2) + 1, turnoverSuffixTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."Suffix"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty per rodzaj transakcji
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting transaction type turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doTransactionTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "TransactionType")
    WITH
        "Data" AS (
            SELECT
                "TransactionTurnover"."Customer"                                                                                "Customer",
                "TransactionTurnover"."TransactionType"                                                                         "TransactionType",
                SUM("TransactionTurnover"."Debit")                                                                              "Debit",
                SUM("TransactionTurnover"."Credit")                                                                             "Credit",
                SUM("TransactionTurnover"."CreditExcluded")                                                                     "CreditExcluded"
            FROM
                "doTransactionTurnover" "TransactionTurnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "TransactionTurnover"."Customer")
            WHERE
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("TransactionTurnover"."Year" = dateYearTo AND "TransactionTurnover"."Period" <= datePeriodTo AND "TransactionTurnover"."Period" >= datePeriodFrom) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "TransactionTurnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0 -- muszą być policzone obroty za pierwszy miesiąc kwartału / półrocza / roku
            GROUP BY "TransactionTurnover"."Customer", "TransactionTurnover"."TransactionType"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0) /*- NVL("Data"."CreditExcluded", 0)*/                                                   "Credit",
                NVL("Data"."CreditExcluded", 0)                                                                                 "CreditExcluded",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0) /*+ NVL("Data"."CreditExcluded", 0)*/                         "CreditDrop",
                NVL("Data"."TransactionType", "PastTurnover"."TransactionType")                                                 "TransactionType"
            FROM
                "Data" LEFT JOIN
                "doTransactionTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."TransactionType" = "Data"."TransactionType" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverTransactionTypeID * 2) + 1, turnoverTransactionTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."TransactionType"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    -- Obroty wykluczone
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Counting excluded turnovers for ' || datePeriod || ', ' || dateYear || ' (drop ' || dropDatePeriod || ', ' || dropDateYear || ')');
    INSERT INTO "doExcludedTurnover" ("ID", "TypeID", "VersionID", "Year", "Period", "Customer", "Debit", "Credit", "CreditDrop", "ExcludedAccount")
    WITH
        "Data" AS (
            SELECT
                "ExcludedTurnover"."Customer"                                                                                   "Customer",
                "ExcludedTurnover"."ExcludedAccount"                                                                            "ExcludedAccount",
                SUM("ExcludedTurnover"."Debit")                                                                                 "Debit",
                SUM("ExcludedTurnover"."Credit")                                                                                "Credit",
                SUM("ExcludedTurnover"."CreditExcluded")                                                                        "CreditExcluded"
            FROM
                "doExcludedTurnover" "ExcludedTurnover" INNER JOIN
                "doCustomer" "Customer" ON ("Customer"."ID" = "ExcludedTurnover"."Customer")
            WHERE
                ("Customer"."IsX" = 0 AND "Customer"."CloseDate" IS NULL) AND
                ("ExcludedTurnover"."Year" = dateYearTo AND "ExcludedTurnover"."Period" <= datePeriodTo AND "ExcludedTurnover"."Period" >= datePeriodFrom) AND
                ("Customer"."EcconKind" IS NULL OR "Customer"."EcconKind" <> 'OSF') AND
                (/*<CustomerCustomCondition>*/1=1/*</CustomerCustomCondition>*/)
            HAVING COUNT(CASE WHEN "ExcludedTurnover"."Period" = datePeriodFrom THEN 1 ELSE NULL END) > 0 -- muszą być policzone obroty za pierwszy miesiąc kwartału / półrocza / roku
            GROUP BY "ExcludedTurnover"."Customer", "ExcludedTurnover"."ExcludedAccount"
        ),
        "DataWithDrop" AS (
            SELECT
                NVL("Data"."Customer", "PastTurnover"."Customer")                                                               "Customer",
                NVL("Data"."Debit", 0)                                                                                          "Debit",
                NVL("Data"."Credit", 0)                                                                                         "Credit",
                "PastTurnover"."Credit" - NVL("Data"."Credit", 0)                                                               "CreditDrop",
                NVL("Data"."ExcludedAccount", "PastTurnover"."ExcludedAccount")                                                 "ExcludedAccount"
            FROM
                "Data" LEFT JOIN
                "doExcludedTurnover" "PastTurnover" ON ("PastTurnover"."Customer" = "Data"."Customer" AND "PastTurnover"."ExcludedAccount" = "Data"."ExcludedAccount" AND "PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
            WHERE
                "PastTurnover"."ID" IS NULL OR ("PastTurnover"."Year" = dropDateYear AND "PastTurnover"."Period" = dropDatePeriod)
        )
    SELECT
        ("SEQ-doDataObject".NEXTVAL * 2048) + (turnoverExcludedTypeID * 2) + 1, turnoverExcludedTypeID, 0, dateYear, datePeriod,
        "Data"."Customer", "Data"."Debit", "Data"."Credit", "Data"."CreditDrop", "Data"."ExcludedAccount"
    FROM
        "DataWithDrop" "Data";
    COMMIT;

    ELSE DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Turnovers for ' || datePeriod || ', ' || dateYear || ' will not be counted'); END IF;

 END;
