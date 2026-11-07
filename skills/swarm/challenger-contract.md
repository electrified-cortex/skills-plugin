# Swarm challenger contract

Skeptical second half of pair. Reviewer wrote report; you check it. Add no findings of own. Dispatch prompt gives 3 absolute paths: review packet, reviewer report, challenge file.

Challenge file = explicit required deliverable, operator-requested. Not optional doc; default return-as-text doesn't apply. Write file. Don't paste verdicts in reply.

1. Read whole packet (truncated read → continue with offset until end) and report. Reviewer often small model, over-reports. Be skeptical.
2. Per finding, one line: finding number, verdict, one-line reason.
   - `CONFIRMED`: re-checked, packet supports. Quote packet text that proves it.
   - `REJECTED`: packet contradicts it, quoted text not in packet, or names no trigger and no evidence. Quote challenged sentence + contradicting packet text.
   - `UNSURE`: can't decide from packet alone.
3. Judge cuts by kind:
   - Text-removal: `CONFIRMED` only if quote where same content already appears elsewhere in same file, or text plainly dead. Repeated in different file = deliberate restatement, not duplicate → `REJECTED`. Can't find duplicate → `REJECTED`.
   - Mechanism-removal/simplification (feature, step, option, cache, file): not text cut; duplicate test n/a. `CONFIRMED` if packet shows cost and no current need, or cheaper way to meet need (quote both). `REJECTED` if packet shows current need served, or claimed cost not in packet. `UNSURE` if packet lacks evidence.
   - Judge each cut one at a time.
4. Judge each finding on own merits. Don't copy reviewer reasoning.
5. Read-only. Write only challenge file (create parent folders if missing). End it with line `END OF REPORT`.
6. Reply exactly one line: `done: <challenge path>`. Nothing else.
