#!/bin/bash
FILE=$1
MODE=${2:-all}
BASE="${FILE%.c}"

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
BLU='\033[0;34m'
CYN='\033[0;36m'
NC='\033[0m'

header() { echo -e "\n${YLW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYN}  $1${NC}"; echo -e "${YLW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

asm() {
    header "[1] ASSEMBLY — O0 vs O3"
    gcc -O0 -S -masm=intel "$FILE" -o "${BASE}_O0.s"
    gcc -O3 -S -masm=intel "$FILE" -o "${BASE}_O3.s"
    diff "${BASE}_O0.s" "${BASE}_O3.s"
}

obj() {
    header "[2] OBJDUMP — machine instructions"
    gcc -O2 -g "$FILE" -o "${BASE}.out"
    objdump -d -M intel "${BASE}.out"
}

run_perf() {
    header "[3] PERF — cycles, cache, instructions"
    gcc -O2 -g "$FILE" -o "${BASE}.out"
    perf stat -e cycles,instructions,cache-misses,cache-references,branch-misses "./${BASE}.out" 2>&1
}

bench() {
    BENCH_FILE="${3:-${BASE}_bench.cpp}"
    if [ ! -f "$BENCH_FILE" ]; then
        echo "bench file not found: $BENCH_FILE"
        echo "create: ${BASE}_bench.cpp"
        return
    fi
    header "[4] BENCHMARK — nanoseconds"
    g++ -O2 -I/usr/include/benchmark "$BENCH_FILE" "$FILE" \
        -L/usr/lib64 -lbenchmark -lbenchmark_main -lpthread \
        -o "${BASE}_bench.out" 2>&1
    "./${BASE}_bench.out"
}

mem() {
    header "[5] VALGRIND — memory"
    gcc -O0 -g "$FILE" -o "${BASE}.out"
    valgrind --leak-check=full --track-origins=yes "./${BASE}.out" 2>&1
}

gdb_run() {
    header "[6] GDB — instruction level"
    gcc -O0 -g "$FILE" -o "${BASE}_gdb.out"
    gdb -batch \
        -ex "set disassembly-flavor intel" \
        -ex "run" \
        -ex "disassemble" \
        -ex "info registers" \
        -ex "quit" \
        "./${BASE}_gdb.out" 2>&1
}

case $MODE in
    asm)   asm ;;
    obj)   obj ;;
    perf)  run_perf ;;
    bench) bench ;;
    mem)   mem ;;
    gdb)   gdb_run ;;
   igdb)   gcc -O0 -g "$FILE" -o "${BASE}_gdb.out" && gdb "./${BASE}_gdb.out" ;;
   run0)   gcc -O0 "$FILE" -o "${BASE}.out" && "./${BASE}.out" ;;
   run2)   gcc -O2 "$FILE" -o "${BASE}.out" && "./${BASE}.out" ;;
   run3)   gcc -O3 "$FILE" -o "${BASE}.out" && "./${BASE}.out" ;;
    all)   asm; obj; run_perf; bench; mem; gdb_run ;;
    *)     echo "Usage: crun <file.c> [asm|obj|perf|bench|mem|gdb|all]" ;;
esac
