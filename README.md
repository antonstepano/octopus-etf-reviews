# Octopus ETF — public review evidence

This repository contains *selected* stage-level evidence from AI4Science/Octopus 16.4 development.
It is NOT a clone of the agent workspace, and it does not contain Yandex credentials, HPC access, full calculation outputs or a vendored Octopus tree.

- `stages/S02/STAGE_MANIFEST.json` — exact **source commit** and SHA256 checksums.
- `stages/S02/REVIEW_REQUEST.json` — questions and requested scope.
- `stages/S02/evidence/` — small reports and regression tests.
- `stages/S02/source_changes.patch` — optional diff relative to upstream Octopus baseline.
- `reviews/S02/CHATGPT_REVIEW.md` and `reviews/S02/DECISION.json` — external report, added only after review.

Reviewing the contents does not automatically approve the agent to continue. A human must authorize the exact commit separately using the local AI4Science `review_ctl.py` command.
