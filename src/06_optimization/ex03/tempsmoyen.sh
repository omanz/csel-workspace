#!/bin/sh

if [ $# -lt 1 ]; then
    echo "Usage: $0 <executable> [args...]"
    exit 1
fi

n=10
i=1
total=0

while [ $i -le $n ]; do
    t=$(/usr/bin/time -f "%e" "$@" 2>&1 >/dev/null)
    
    # addition en utilisant awk (pas besoin de bc)
    total=$(echo "$total $t" | awk '{print $1 + $2}')

    i=$((i + 1))
done

echo "$total $n" | awk '{print "Moyenne = " $1 / $2 " s"}'