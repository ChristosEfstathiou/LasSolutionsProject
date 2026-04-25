@echo off

echo ==============================
echo   WAREHOUSE FULL RUN (CMD)
echo ==============================

if "%ORA_USER%"=="" (
    echo ERROR: ORA_USER is not set.
    echo Run: set ORA_USER=HR
    exit /b 1
)
if "%ORA_PASS%"=="" (
    echo ERROR: ORA_PASS is not set.
    echo Run: set ORA_PASS=your_password
    exit /b 1
)
if "%ORA_CONN%"=="" set ORA_CONN=localhost/XEPDB1

set BASE_DIR=D:\warehouse_project\sql
set LOGS_DIR=D:\warehouse_project\logs

if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"

set LOG_FILE=%LOGS_DIR%\run_%DATE:~10,4%%DATE:~4,2%%DATE:~7,2%.log

echo BASE_DIR=%BASE_DIR%
echo LOG=%LOG_FILE%

echo ============================== > "%LOG_FILE%"
echo WAREHOUSE RUN - %DATE% %TIME% >> "%LOG_FILE%"
echo ============================== >> "%LOG_FILE%"

echo Creating schema...
echo [SCHEMA] >> "%LOG_FILE%"
sqlplus %ORA_USER%/%ORA_PASS%@%ORA_CONN% @"%BASE_DIR%\01_create_schema.sql" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% neq 0 ( echo ERROR: schema failed & exit /b 1 )

echo Loading sample data...
echo [SAMPLE DATA] >> "%LOG_FILE%"
sqlplus %ORA_USER%/%ORA_PASS%@%ORA_CONN% @"%BASE_DIR%\02_sample_orders.sql" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% neq 0 ( echo ERROR: sample data failed & exit /b 1 )

echo Creating procedure...
echo [PROCEDURE] >> "%LOG_FILE%"
sqlplus %ORA_USER%/%ORA_PASS%@%ORA_CONN% @"%BASE_DIR%\03_plsql_orders.sql" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% neq 0 ( echo ERROR: procedure failed & exit /b 1 )

echo Running function and tests...
echo [TESTS] >> "%LOG_FILE%"
sqlplus %ORA_USER%/%ORA_PASS%@%ORA_CONN% @"%BASE_DIR%\06_plsql_function_and_tests.sql" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% neq 0 ( echo ERROR: tests failed & exit /b 1 )

echo Generating report...
echo [REPORT] >> "%LOG_FILE%"
sqlplus %ORA_USER%/%ORA_PASS%@%ORA_CONN% @"%BASE_DIR%\04_reports.sql" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% neq 0 ( echo ERROR: report failed & exit /b 1 )

echo ============================== >> "%LOG_FILE%"
echo DONE - %DATE% %TIME% >> "%LOG_FILE%"
echo ============================== >> "%LOG_FILE%"

echo ==============================
echo DONE SUCCESSFULLY
echo ==============================
echo Log saved: %LOG_FILE%

pause
