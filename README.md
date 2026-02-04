# DTOne-test

# Debugging Assessment (Perl)

## How to Run

From the project folder:

```
perl debug_assessment.pl
```

## Expected Outcome

- The script processes exactly 3 embedded tickets.
- Two tickets print successful output lines.
- One ticket triggers a runtime error due to a bug.

## Candidate Tasks

1) Reproduce the error in the terminal.
2) Identify the root cause in the Perl script.
3) Fix the bug so all 3 tickets process successfully.
4) Provide the fixed script as part of your submission.
5) Provide screenshots of terminal output before and after the fix.
6) Document steps taken and final explanation (brief).
7) Add a final line that prints the single ticket with the highest latency_ms (successful tickets only),
   including: id, region, status, latency_ms. If there are ties, pick the first encountered.
   If there are no successful tickets, print a sensible fallback (e.g., "Slowest: n/a").

## Evaluation Criteria

- Correctness of the fix and outputs
- Debugging approach and reasoning
- Clarity of explanation and documentation
- Code quality and readability
- Minimal change that addresses the root cause
- Edge-case handling and validation
