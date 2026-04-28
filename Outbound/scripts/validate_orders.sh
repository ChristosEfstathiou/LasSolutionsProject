#!/bin/bash

export PATH=$PATH:/mnt/c/app/aldob/product/21c/dbhomeXE/bin

echo "=== VALIDATE ORDERS ENVIRONMENT ==="

# φορτώνουμε τις ρυθμίσεις αν υπάρχει το config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/outbound.conf" ]; then
    source "$SCRIPT_DIR/outbound.conf"
    echo "OK - outbound.conf φορτώθηκε"
else
    echo "INFO - outbound.conf δεν βρέθηκε, χρησιμοποιούνται defaults"
fi

errors=0

# ελέγχουμε αν υπάρχει το sqlplus
if command -v sqlplus.exe &> /dev/null; then
    echo "OK - sqlplus βρέθηκε"
else
    echo "ERROR - sqlplus δεν βρέθηκε"
    errors=$((errors + 1))
fi

# ελέγχουμε τις μεταβλητές περιβάλλοντος
if [ -z "$ORA_USER" ]; then
    echo "ERROR - ORA_USER δεν έχει οριστεί"
    errors=$((errors + 1))
else
    echo "OK - ORA_USER = $ORA_USER"
fi

if [ -z "$ORA_PASS" ]; then
    echo "ERROR - ORA_PASS δεν έχει οριστεί"
    errors=$((errors + 1))
else
    echo "OK - ORA_PASS = ***"
fi

if [ -z "$ORA_CONN" ]; then
    echo "ERROR - ORA_CONN δεν έχει οριστεί"
    errors=$((errors + 1))
else
    echo "OK - ORA_CONN = $ORA_CONN"
fi

# δοκιμάζουμε σύνδεση στη βάση
echo "Δοκιμή σύνδεσης στη βάση..."
result=$(sqlplus.exe -s /nolog <<SQLEOF
CONNECT ${ORA_USER}/${ORA_PASS}@${ORA_CONN}
SELECT 'CONNECTION OK' AS status FROM dual;
EXIT;
SQLEOF
)

if echo "$result" | grep -q "CONNECTION OK"; then
    echo "OK - σύνδεση στη βάση επιτυχής"
else
    echo "ERROR - αδύνατη σύνδεση στη βάση"
    errors=$((errors + 1))
fi

# ελέγχουμε αν υπάρχουν οι πίνακες
echo "Έλεγχος πινάκων..."
tables=$(sqlplus.exe -s /nolog <<SQLEOF
CONNECT ${ORA_USER}/${ORA_PASS}@${ORA_CONN}
SELECT COUNT(*) FROM user_tables WHERE table_name IN ('CUSTOMER_ORDERS','ORDER_LINES','INVENTORY','PRODUCTS','EVENT_LOG');
EXIT;
SQLEOF
)

count=$(echo "$tables" | grep -o '[0-9]*' | tail -1)
if [ "$count" = "5" ]; then
    echo "OK - όλοι οι πίνακες υπάρχουν"
else
    echo "ERROR - λείπουν πίνακες (βρέθηκαν $count από 5)"
    errors=$((errors + 1))
fi

# ελέγχουμε αν υπάρχει η procedure
echo "Έλεγχος procedure..."
proc=$(sqlplus.exe -s /nolog <<SQLEOF
CONNECT ${ORA_USER}/${ORA_PASS}@${ORA_CONN}
SELECT COUNT(*) FROM user_objects WHERE object_name = 'PROCESS_ORDER' AND object_type = 'PROCEDURE';
EXIT;
SQLEOF
)

pcount=$(echo "$proc" | grep -o '[0-9]*' | tail -1)
if [ "$pcount" = "1" ]; then
    echo "OK - process_order procedure υπάρχει"
else
    echo "ERROR - process_order procedure δεν βρέθηκε"
    errors=$((errors + 1))
fi

# τελικό αποτέλεσμα
echo ""
if [ $errors -eq 0 ]; then
    echo "=== ΟΛΑ ΕΝΤΆΞΕΙ - μπορείς να τρέξεις run_orders.sh ==="
else
    echo "=== ΒΡΕΘΗΚΑΝ $errors ΣΦΑΛΜΑΤΑ - διόρθωσέ τα πρώτα ==="
fi
