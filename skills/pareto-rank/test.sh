#!/usr/bin/env bash
# test.sh — exercises pareto-rank.sh against sample.csv
# Expected Pareto analysis:
#   alpha  (9,7,5): dominated by delta (8,8,4)? NO: alpha > delta on value(9>8), delta > alpha on speed(8>7). Neither dominates.
#   beta   (5,9,6): dominated? alpha(9,7,5): 9>5 on val but 7<9 on speed. delta(8,8,4): 8>5 val, 8<9 speed. No dominator.
#   gamma  (3,3,3): dominated by alpha,beta,delta,epsilon,zeta — rank high (worst)
#   delta  (8,8,4): dominated by alpha? alpha(9>8, 7<8) no. by beta? beta(5<8) no. Not dominated.
#   epsilon(6,5,8): dominated by alpha(9>6,7>5,5<8)? NO — ease 5<8. by beta(5<6)? NO. Not dominated.
#   zeta   (2,4,9): dominated by epsilon(6>2,5>4,8<9)? NO — ease 8<9. beta(5>2,9>4,6<9)? NO. Not dominated.
#
# Front 1 = {alpha, beta, delta, epsilon, zeta} — none dominates any other
# Front 2 = {gamma} — dominated by everyone on front 1
#
# Within front 1, dim-sum order:
#   delta:   8+8+4=20
#   alpha:   9+7+5=21
#   beta:    5+9+6=20
#   epsilon: 6+5+8=19
#   zeta:    2+4+9=15
# Descending sum: alpha(21) > delta(20) = beta(20) > epsilon(19) > zeta(15)
# Tie between delta and beta (sum=20): break by id asc => beta < delta
# So front-1 order: alpha, beta, delta, epsilon, zeta
# Then gamma at rank 2.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL="$SCRIPT_DIR/pareto-rank.sh"
CSV="$SCRIPT_DIR/sample.csv"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT   # portable temp dir for fixture CSVs (no hardcoded /tmp)

chmod +x "$TOOL"

echo "========================================="
echo "TEST 1: rank"
echo "========================================="
bash "$TOOL" rank "$CSV"

echo ""
echo "========================================="
echo "TEST 2: next (alias for rank)"
echo "========================================="
bash "$TOOL" next "$CSV"

echo ""
echo "========================================="
echo "TEST 3: top value"
echo "========================================="
bash "$TOOL" top value "$CSV"

echo ""
echo "========================================="
echo "TEST 4: top speed"
echo "========================================="
bash "$TOOL" top speed "$CSV"

echo ""
echo "========================================="
echo "TEST 5: top ease"
echo "========================================="
bash "$TOOL" top ease "$CSV"

echo ""
echo "========================================="
echo "TEST 6: top by numeric index (dim 2 = speed)"
echo "========================================="
bash "$TOOL" top 2 "$CSV"

echo ""
echo "========================================="
echo "TEST 7: headerless CSV"
echo "========================================="
cat > "$WORK"/pareto_headerless.csv <<'EOF'
A,9,7,5
B,5,9,6
C,3,3,3
D,8,8,4
E,6,5,8
F,2,4,9
EOF
bash "$TOOL" rank "$WORK"/pareto_headerless.csv

echo ""
echo "========================================="
echo "TEST 8: empty CSV"
echo "========================================="
printf '' > "$WORK"/pareto_empty.csv
bash "$TOOL" rank "$WORK"/pareto_empty.csv
echo "(empty output expected — exit 0)"

echo ""
echo "========================================="
echo "TEST 9: single item (no domination possible)"
echo "========================================="
cat > "$WORK"/pareto_single.csv <<'EOF'
id,x,y
solo,5,5
EOF
bash "$TOOL" rank "$WORK"/pareto_single.csv

echo ""
echo "========================================="
echo "TEST 10: error — non-numeric dimension"
echo "========================================="
cat > "$WORK"/pareto_bad.csv <<'EOF'
id,x,y
good,5,3
bad,4,oops
EOF
bash "$TOOL" rank "$WORK"/pareto_bad.csv && echo "UNEXPECTED SUCCESS" || echo "(error expected — exit non-zero)"

echo ""
echo "========================================="
echo "TEST 11: error — unknown dimension name in top"
echo "========================================="
bash "$TOOL" top nonexistent "$CSV" && echo "UNEXPECTED SUCCESS" || echo "(error expected — exit non-zero)"

echo ""
echo "========================================="
echo "TEST 12: error — fewer than 2 columns"
echo "========================================="
cat > "$WORK"/pareto_onecol.csv <<'EOF'
id
alpha
beta
EOF
bash "$TOOL" rank "$WORK"/pareto_onecol.csv && echo "UNEXPECTED SUCCESS" || echo "(error expected — exit non-zero)"

echo ""
echo "========================================="
echo "TEST 13: duplicate rows (same dim vector = same rank, tie-break by id)"
echo "========================================="
cat > "$WORK"/pareto_dupes.csv <<'EOF'
id,x,y
charlie,5,5
alpha,5,5
beta,3,3
EOF
bash "$TOOL" rank "$WORK"/pareto_dupes.csv
# Expected: alpha and charlie rank 1 (same vector, tie-break id asc => alpha first), beta rank 2

echo ""
echo "========================================="
echo "TEST 14: error — scientific notation not supported"
echo "========================================="
cat > "$WORK"/pareto_sci.csv <<'EOF'
id,x,y
a,1e3,5
b,4,3
EOF
bash "$TOOL" rank "$WORK"/pareto_sci.csv && echo "UNEXPECTED SUCCESS" || echo "(error expected — exit non-zero)"

echo ""
echo "========================================="
echo "TEST 15: top outputs no rank column"
echo "========================================="
out=$(bash "$TOOL" top value "$CSV")
if echo "$out" | grep -q 'rank'; then
  echo "FAIL: rank column found in top output"
else
  echo "PASS: no rank column in top output"
fi
echo "$out"

echo ""
echo "========================================="
echo "TEST 16: next is identical to rank"
echo "========================================="
rank_out=$(bash "$TOOL" rank "$CSV")
next_out=$(bash "$TOOL" next "$CSV")
if [[ "$rank_out" == "$next_out" ]]; then
  echo "PASS: next output identical to rank"
else
  echo "FAIL: next output differs from rank"
  diff <(echo "$rank_out") <(echo "$next_out")
fi

echo ""
echo "All tests complete."
