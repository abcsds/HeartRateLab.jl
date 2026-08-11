# References

## The HRV knowledge base

The bibliography behind these docs (`docs/references.bib`, **543 entries**) is a
consolidated, citation-expanded knowledge base of the HRV literature, built in
three passes:

1. **Seminal map** — every entry in the [HRV Variable Zoo](index.md) is tied to
   the source that *first introduced* the measure (not a review that merely uses
   it), plus the curated applications literature behind each entry's
   *Applications by area* section. Metadata (authors, year, venue, DOI) was
   verified against PubMed / publisher pages / Semantic Scholar in 2026-07.
2. **Consolidation** — merged with the project's RR/IBI-forecasting and
   real-world (RACERS) bibliographies into one confirmed reference set.
3. **Citation expansion** — every confirmed DOI was resolved on
   [OpenAlex](https://openalex.org), each paper's reference list pulled, and the
   HRV-related papers *they* cite added — preferentially the shared foundations
   cited by two or more confirmed papers. (The expansion is capped at the ~400
   most cross-cited external works; it is a foundations sample, not an
   exhaustive sweep.)

The result spans **1948–2026** — from Shannon (information theory), Hurst
(long-range dependence), Welch / Lomb / Scargle (the spectral estimators
HeartRateLab uses) through the Task Force standard to current work — and it is
**one field, not many**: in the full citation graph behind the KB (554 papers,
3,841 citation edges), 89% of papers sit in a single connected component (an
earlier "fragmented" picture came from drawing co-authorship edges only). Each
paper carries one or more **field labels** (multi-label, over the 554-paper
graph):

| Field | papers |
|---|---:|
| methods & foundations | 285 |
| clinical | 253 |
| sports & peak-performance | 125 |
| contemplative practice | 44 |

These are the same four fields each zoo entry references: the three
*Applications by area* sections (clinical · sports & peak-performance ·
contemplative practice) and the seminal *Citation* section (methods &
foundations), summarized per feature in the `C S P M` facet column on the
[zoo index](index.md).

## Cited works

The list below renders the entries cited on the documentation pages; each
`[key](@cite)` link resolves here. The full 543-entry knowledge base lives in
`docs/references.bib`.

```@bibliography
```
