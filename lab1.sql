create or replace PROCEDURE get_columns_info(sch in varchar2, t in varchar2)
    IS
    -- variables part
    tablename VARCHAR2(40) := t;
    schemaname Varchar2(40) := sch;
    anotherUser varchar2(40);
    colNo VARCHAR2(128) := 'No.';
    colName VARCHAR2(128) := 'Имя столбца';
    colAttr VARCHAR2(128) := 'Атрибуты';
    noCounter NUMBER := 0;
    noLen NUMBER := 3;
    colLen NUMBER := 15;
    attrLen NUMBER := 60;
    attrNameLen NUMBER := 7;
    dataType VARCHAR2(128);
    constr VARCHAR2(128);
    name varchar2(128) := '';
    surname varchar2(128) := '';
    constrName varchar2(128) := '';
    countReservedWords number := 0;
    countParamsExisting number := 0;
    checkAllowTable number := 0;

    -- exception part
    schemaNotFound Exception;
    tableNotFound Exception;
    schemaContainsReservedWords Exception;
    tableContainsReservedWords Exception;
    schemaNotValid Exception;
    tableNotValid Exception;
    tableNotAllowed Exception;
    nameTooLong Exception;

--     --exception init
--     pragma exception_init ( tableNotValid, - 06550);
--     pragma exception_init ( schemaNotValid, - 06550);



    cursor CONST is
    select DISTINCT acc.OWNER, acc.CONSTRAINT_NAME, acc.COLUMN_NAME, ac.CONSTRAINT_TYPE, atc.DATA_TYPE, atc.DATA_PRECISION from ALL_CONSTRAINTS ac
                    JOIN ALL_CONS_COLUMNS acc on ac.CONSTRAINT_NAME = acc.CONSTRAINT_NAME
                    JOIN ALL_TAB_COLUMNS atc on acc.COLUMN_NAME = atc.COLUMN_NAME and acc.TABLE_NAME = atc.TABLE_NAME
                    where atc.OWNER = schemaname and acc.TABLE_NAME = tablename;

    cursor FIO is
    select ФАМИЛИЯ, ИМЯ from Н_ЛЮДИ where ИД =
      (select ЧЛВК_ИД from Н_УЧЕНИКИ where ИД = (select user_id from ALL_USERS where USERNAME = schemaname));



    cursor FK_curs is
    select acc2.CONSTRAINT_NAME as fk_constrName, acc2.COLUMN_NAME as fk_name, acc.TABLE_NAME as ref_tab, acc.COLUMN_NAME as ref_name from ALL_CONSTRAINTS ac
        join ALL_CONS_COLUMNS acc on ac.R_CONSTRAINT_NAME = acc.CONSTRAINT_NAME
        join ALL_CONS_COLUMNS acc2 on ac.CONSTRAINT_NAME = acc2.CONSTRAINT_NAME
        where ac.OWNER = schemaname and ac.TABLE_NAME = tablename and ac.CONSTRAINT_TYPE = 'R';

    BEGIN
        -- validation part
        IF not instr(tablename, '.') = 0 then
            schemaname := substr(tablename, 1, instr(tablename, '.')-1);
            tablename := substr(tablename, instr(tablename, '.')+1);
        end if;

        IF schemaname = '' then
            raise schemaNotValid;
        end if;

        IF length(schemaname) > 30 or length(tablename) > 30 then
            raise nameTooLong;
        end if;

        select count(*) into countReservedWords from V$RESERVED_WORDS where KEYWORD=schemaname;
        if countReservedWords >0 then
            raise schemaContainsReservedWords;
        end if;

        select count(*) into countReservedWords from V$RESERVED_WORDS where KEYWORD=tablename;
        if countReservedWords >0 then
            raise tableContainsReservedWords;
        end if;

        select count(*) into countParamsExisting from DBA_USERS where USERNAME=schemaname;
        IF schemaname IS NULL or countParamsExisting = 0 then
            raise schemaNotFound;
        end if;

        if not regexp_like(tablename, '[a-zA-Z1-9#$_]+|(".+")') then
                raise tableNotValid;
        end if;

        IF tablename = '' then
            raise tableNotValid;
        end if;

        select count(*) into countParamsExisting from DBA_TABLES where TABLE_NAME=tablename;
        if tablename is NULL or countParamsExisting = 0 or tablename = ''  then
            raise tableNotFound;
        end if;
        
        select count(username) into checkAllowTable from all_users where username like schemaname;
        if checkAllowTable = 0 then
            raise tableNotAllowed;
        end if;
    

        -- set user's info
        FOR fi IN FIO loop
            name := fi.ИМЯ;
            surname := fi.ФАМИЛИЯ;
            end loop;

        IF instr(tablename, '.') != 0 then
            anotherUser := substr(tablename,1,instr(tablename, '.'));
        end if;

        -- set result table
        DBMS_OUTPUT.PUT_LINE('Пользователь: ' || surname || ' ' || name || ' ' || '(' || schemaname || ')');
        DBMS_OUTPUT.PUT_LINE('Таблица: ' || tableName);
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(RPAD(colNo, noLen) || ' ' || RPAD(colName, colLen) || ' ' || RPAD(colAttr, attrLen));
        DBMS_OUTPUT.PUT_LINE(RPAD('-', noLen, '-') || ' ' || RPAD('-', colLen, '-') || ' ' || RPAD('-', attrLen, '-'));
        FOR ROW IN CONST loop
            noCounter := noCounter + 1;
            colName := ROW.COLUMN_NAME;
            colAttr := ROW.DATA_TYPE;
            constr := ROW.CONSTRAINT_TYPE;
            constrName := ROW.CONSTRAINT_NAME;
            dataType := RPAD('Type: ', attrNameLen) || ROW.DATA_TYPE;
            IF ROW.DATA_PRECISION IS NOT NULL THEN
                dataType := dataType || '(' || ROW.DATA_PRECISION || ')';
            END IF;
            DBMS_OUTPUT.PUT_LINE(RPAD(noCounter, noLen, ' ') || ' ' || RPAD(colName, colLen, ' ') || ' ' || dataType);
            IF constr = 'R' THEN
                for line in FK_curs loop
                    if line.fk_constrName = constrName then
                        DBMS_OUTPUT.PUT_LINE(RPAD(' ', noLen + colLen + 2) || RPAD('Constr: ', 8) ||'"' || line.fk_name || '"' || ' References ' || line.ref_tab || '(' || line.ref_name || ')');
                    end if;
                end loop;
            end if;
            IF constr = 'U' then
                DBMS_OUTPUT.PUT_LINE(RPAD(' ', noLen + colLen + 2) || RPAD('Constr: ', 8) ||'"' || 'UNIQUE'|| '"');
            end if;
            IF constr = 'C' then
                DBMS_OUTPUT.PUT_LINE(RPAD(' ', noLen + colLen + 2) || RPAD('Constr: ', 8) ||'"' || 'NOT NULL'|| '"');
            end if;
            IF constr = 'P' then
                DBMS_OUTPUT.PUT_LINE(RPAD(' ', noLen + colLen + 2) || RPAD('Constr: ', 8) ||'"' || 'PRIMARY KEY'|| '"');
            end if;
            end loop;

            EXCEPTION
                WHEN schemaNotFound THEN raise_application_error(- 20000, 'No schema with that name');
                WHEN tableNotFound THEN raise_application_error(- 20001, 'No table with that name');
                WHEN schemaContainsReservedWords THEN raise_application_error(- 20002, 'Schema name contains reserved words');
                WHEN tableContainsReservedWords THEN raise_application_error(- 20003, 'Table name contains reserved words');
                WHEN schemaNotValid then raise_application_error(- 20004, 'Not valid input schema name');
                WHEN tableNotValid then raise_application_error(- 20005, 'Not valid input table name');
                WHEN nameTooLong then raise_application_error(- 20006, 'Input value to loong!(length must be lower than 30)');
                WHEN tableNotAllowed then raise_application_error(- 20007, 'You dont have permissions for this table');
    end get_columns_info;
/
SET SERVEROUT ON SIZE UNLIMITED;
accept sch PROMPT 'Enter schema name:  ';
ACCEPT t PROMPT 'Enter table name:  ';
BEGIN
    IF 'sch' is null then 
        raise_application_error(-1000, 'sss');
    end if; 
    get_columns_info('&sch', '&t');
end;
/
