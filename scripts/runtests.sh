#!/bin/bash
set -e

echo "[Building]"
pushd tests >/dev/null
rm -rf output >/dev/null
make --no-print-directory -s
TESTS=$(find . -name "*.lua*")
popd >/dev/null

mkdir tests/output
touch tests/output/{SUCCESS,FAILURES}
for T in $TESTS; do
	TEST_PATH=$(pwd)/tests/$T
	OUTPUT_DIR=tests/output/$(basename $T .lua)
	echo -n "$T... "
	mkdir -p $OUTPUT_DIR
	pushd $OUTPUT_DIR >/dev/null
	oldland-sim $TEST_PATH >stdout.log 2>stderr.log && (echo SUCCESS; echo $T >> ../SUCCESS) || (echo FAIL; echo $T >> ../FAILURES)
	popd >/dev/null
done

echo ""
echo "Summary:"
echo "$(grep -c . tests/output/SUCCESS) passes, $(grep -c . tests/output/FAILURES) failures"
echo "Failed tests:"
cat tests/output/FAILURES
