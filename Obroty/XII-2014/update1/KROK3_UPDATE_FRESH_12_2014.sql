 -- Auto generated content. Do not modify!
DECLARE
    currentSchema               NVARCHAR2(100);

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
	
	CURSOR bulkCursor1          IS (
        SELECT
            A.ROWID,
            0 "FRESH",
            1 "CHANGED"
        FROM
            "T_EQU_SAPF" A
        WHERE
            A.FRESH IS NULL AND  "SAVFR" >= (SELECT To_Date('01-12-2014','dd-mm-yyyy') FROM dual) AND "SAVFR" <= (SELECT To_Date('31-12-2014','dd-mm-yyyy') FROM dual)
    );
    CURSOR bulkCursor2          IS (
        SELECT
            A.ROWID,
            BITOR(BITAND(A.FRESH, BITNOT(2)), CASE WHEN A.SAPBR='DEPOZ' OR B.SAPBR IS NOT NULL THEN 2 ELSE 0 END) "FRESH",
            1 "CHANGED"
        FROM
            "T_EQU_SAPF" A LEFT OUTER JOIN
            "T_EQU_SAPF" B ON (B."SAPBR" LIKE '@@CP%' AND A."SADRF" = B."SADRF" AND A."SACCY" = B."SACCY" AND A."SAAN" = B."SAAN" AND A."SAAMA" = - B."SAAMA")
        WHERE    A."SAVFR" >= (SELECT To_Date('01-12-2014','dd-mm-yyyy') FROM dual) AND A."SAVFR" <= (SELECT To_Date('31-12-2014','dd-mm-yyyy') FROM dual)
             AND
            BITAND(A.FRESH, 2) <> CASE WHEN A.SAPBR='DEPOZ' OR B.SAPBR IS NOT NULL THEN 2 ELSE 0 END
    );

   BEGIN
   SELECT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') INTO currentSchema FROM dual;

   SELECT CASE WHEN EXISTS(
                    SELECT  1
                    FROM    "T_EQU_SAPF" A
                    WHERE   A.FRESH IS NULL AND   "SAVFR" >= (SELECT To_Date('01-12-2014','dd-mm-yyyy') FROM dual) AND "SAVFR" <= (SELECT To_Date('31-12-2014','dd-mm-yyyy') FROM dual)

                ) THEN 1
                ELSE 0 END
                INTO bulkCheck
    FROM dual;

    IF bulkCheck = 1 THEN

        -- DBMS_STATS.GATHER_TABLE_STATS(ownname => currentSchema, tabname => 'T_EQU_SAPF', cascade => true);

        -- Aktualizacja flagi FRESH w tabeli SAPF
        bulkStartTime := SYSDATE;
        OPEN bulkCursor1;
        LOOP
            DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Updating NULL SAPF.FRESH. Proc ' || bulkCounter || '-' || (bulkCounter + bulkArraySize - 1) || '. Avg ' || ROUND(bulkCounter / (1 + (SYSDATE - bulkStartTime) * 24 * 3600)) || '/s');

            FETCH bulkCursor1 BULK COLLECT INTO bulkRecord.rowid, bulkRecord.fresh, bulkRecord.changed LIMIT bulkArraySize;
            bulkDone := bulkCursor1%notfound;

            FORALL i in 1 .. bulkRecord.fresh.count
                UPDATE "T_EQU_SAPF" SET "FRESH" = bulkRecord.fresh(i) WHERE ROWID = bulkRecord.rowid(i) AND bulkRecord.changed(i) = 1;
            COMMIT;

            EXIT WHEN(bulkDone);
            bulkCounter := bulkCounter + bulkArraySize;
        END LOOP;
        CLOSE bulkCursor1;

        -- DBMS_STATS.GATHER_TABLE_STATS(ownname => currentSchema, tabname => 'T_EQU_SAPF', cascade => true);

    END IF;

    bulkStartTime := SYSDATE;
    OPEN bulkCursor2;
    LOOP
        DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Updating SAPF.FRESH. Proc ' || bulkCounter || '-' || (bulkCounter + bulkArraySize - 1) || '. Avg ' || ROUND(bulkCounter / (1 + (SYSDATE - bulkStartTime) * 24 * 3600)) || '/s');

        FETCH bulkCursor2 BULK COLLECT INTO bulkRecord.rowid, bulkRecord.fresh, bulkRecord.changed LIMIT bulkArraySize;
        bulkDone := bulkCursor2%notfound;

        FORALL i in 1 .. bulkRecord.fresh.count
            UPDATE "T_EQU_SAPF" SET "FRESH" = bulkRecord.fresh(i) WHERE ROWID = bulkRecord.rowid(i) AND bulkRecord.changed(i) = 1;
        COMMIT;

        EXIT WHEN(bulkDone);
        bulkCounter := bulkCounter + bulkArraySize;
    END LOOP;
    CLOSE bulkCursor2;

END;
