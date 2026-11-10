#!/usr/bin/env bash
# Every check in one go: the Lua tests, a syntax check of every Lua file and the Python tests.
# Quiet on success; on failure it prints only the output of what failed and exits 1.
set -u
cd "$(dirname "$0")/.."

failed=0
count=0
for test in tests/*.lua; do
  count=$((count + 1))
  if ! out=$(lua "$test" 2>&1); then
    echo "FAIL $test"
    echo "$out" | tail -15
    failed=1
  fi
done

while IFS= read -r file; do
  if ! out=$(luac -p "$file" 2>&1); then
    echo "SYNTAX $file"
    echo "$out"
    failed=1
  fi
done < <(find . -name '*.lua' -not -path './.git/*')

if ! out=$(python3 -m unittest discover -s tests -p 'test_*.py' 2>&1); then
  echo "FAIL python tests"
  echo "$out" | tail -25
  failed=1
fi

if [ "$failed" -eq 0 ]; then
  echo "all checks passed ($count Lua tests, syntax, python tests)"
fi
exit "$failed"
