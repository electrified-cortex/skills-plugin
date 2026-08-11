---
name: pareto-rank
description: Rank a CSV of items by Pareto dominance. Dimension-agnostic — caller supplies meaning. Triggers — pareto rank, rank by multiple dimensions, non-dominated sort, Pareto front, multi-criteria order.
---

# pareto-rank

Rank a CSV of items by Pareto dominance. Dimension-agnostic: caller supplies meaning.
Triggers: pareto rank, rank by multiple dimensions, non-dominated sort, Pareto front, multi-criteria order.

## CLI

```
pareto-rank.sh rank <csv>         # full Pareto-ordered output + rank column
pareto-rank.sh next <csv>         # pure alias for rank — identical output
pareto-rank.sh top <dim> <csv>    # single matching row, max value in <dim>, no rank column
```

`<dim>`: numeric = 1-based dimension index; non-numeric = column name (requires header).

## Convention

- Column 1 = item id (string, not scored).
- Columns 2..M = numeric dimensions. **Higher is better.**
- To rank "lower is better" on a dimension, negate that column before input.
- Input MUST be a file path; stdin is not accepted.
- Numeric format: integers and decimal floats only. Scientific notation not supported.

## Ranking

Items are assigned a Pareto rank by iterative front-peeling:

- **Rank 1** = items no other item dominates (A dominates B iff A >= B on all dims, A > B on at least one).
- Remove rank-1 items; repeat for rank 2, rank 3, …
- Identical dimension vectors → same rank (tie-break applies).
- Within a rank: tie-break by descending dimension-sum, then by id ascending.

`rank` output: input columns + a `rank` column, ordered rank ascending.
`top` output: header + the single best row only; no `rank` column.
`next` is a stateless alias for `rank` — no cursor, no persistent state.

## Errors

Non-numeric cell or fewer than 2 columns → error (row + column cited), non-zero exit.
Unknown dimension name in `top` → error listing valid names.
Empty input → empty output, exit 0.
