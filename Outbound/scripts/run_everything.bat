@echo off

echo ================================================
echo   FLOWCORE WAREHOUSE - FULL DEMO
echo ================================================

if "%ORA_USER%"=="" set ORA_USER=HR
if "%ORA_PASS%"=="" set ORA_PASS=hr
if "%ORA_CONN%"=="" set ORA_CONN=localhost/XEPDB1

echo.
echo [1/3] Running full warehouse pipeline...
echo ------------------------------------------------
call "D:\warehouse_project\Outbound\scripts\run_all.bat"

echo.
echo [2/3] Running WSL scripts...
echo ------------------------------------------------
wsl bash -c "export ORA_USER=%ORA_USER% && export ORA_PASS=%ORA_PASS% && export ORA_CONN=%ORA_CONN% && cd /mnt/d/warehouse_project/Outbound/scripts && bash validate_orders.sh && bash show_logs.sh && bash order_report.sh"

echo.
echo [3/3] Running C++ Stock Allocation Helper...
echo ------------------------------------------------
"C:\msys64\usr\bin\bash.exe" -lc "export PATH=$PATH:/mingw64/bin && cd /d/warehouse_project/Outbound/cpp && g++ -o stock_allocation stock_allocation.cpp && ./stock_allocation"

echo.
echo ================================================
echo   ALL DONE
echo ================================================
pause
