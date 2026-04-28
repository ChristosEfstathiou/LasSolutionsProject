Warehouse Project — Εντολές
----------CMD (Windows)----------
D:
cd D:\warehouse_project\scripts
set ORA_USER=HR
set ORA_PASS=hr
set ORA_CONN=localhost/XEPDB1
run_all.bat
----------WSL (Linux)----------
cd /mnt/d/warehouse_project/scripts
export ORA_USER=HR
export ORA_PASS=hr
export ORA_CONN=localhost/XEPDB1
bash validate_orders.sh
bash show_logs.sh
bash order_report.sh
----------C++ (MSYS2)----------
cd /d/warehouse_project/cpp
g++ -o stock_allocation stock_allocation.cpp
./stock_allocation