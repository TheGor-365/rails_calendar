# RC-035B Adaptive Quiz — Stage 2 (integration checkpoint, 2026-11-10)

## Scope and release boundary

- Stacked Draft PR #35, base RC-035 SHA \`8c4a29c2f002c64d9b771df5f9eb2bb80416a399\`.
- No migrations, API provider calls, new roles, public registration, public intake, or Railway deployment.
- The RC-034 two-question flow stays intact at \`/project_intakes/:id/quiz\`.
- New **owner-only** adaptive preview at \`/project_intakes/:id/quiz/adaptive\`; section A is the existing intake type, sections B–G are deterministic, section H is private review.
- Direct deep links require owner authentication; conditional questions are rejected with 404 when no longer visible.
- Changes to upstream selections retain all previously saved child answers and revision snapshots for audit, but exclude inactive branches from active progress and review, with a visible inactive-branch notice. Active choices reappear if their parent condition becomes true again.
- Parent changes that hide previously saved branches require an explicit confirmation checkbox (422 without it). All historical child records remain intact.
- Answer revisions are transactional and immutable; optimistic \`quiz[revision]\` guard prevents silent stale-tab overwrites.
- Server validates choices via catalog definitions; visibility is checked inside \`ProjectIntake#with_lock\`.
- Existing White Atlas classes reused; navigation saves explicitly; there is no auto-save guarantee.
- No client Submit; do not treat private review as approval.

## Tests / acceptance

- Guest + legacy admin denial; owner access; old Quiz unchanged.
- Deterministic resume after reload; snapshot version + immutable history.
- Conditional child appears only after parent selection; hidden direct POST/GET rejected.
- Parent edits retain hidden child revisions but exclude the data from active review.
- Invalid selections and outdated form revisions rejected without modifying saved answers.
- All visible questions complete with local/offline inputs, Review remains private.

## Deferred to Stage 3

- Expand primary project types beyond the four existing persisted categories;
  add \`must/should/later\` priorities and finer detail about regions/languages/budget/deadline;
  stronger browser UX for branch-change confirmation;
  catalog migration/version pinning across future releases;
  comprehensive mobile/keyboard/system-browser QA.
- RC-036 privacy/ACL, real client submissions and paid AI remain prohibited until separately reviewed.

## RC-035 operational dependency

On 2026-11-10 production owner sign-in was confirmed by user screenshot.
Railway staged only deletion of two bootstrap variables, and deployment to apply that cleanup completed SUCCESS with original RC-035 SHA; the normal \`bin/rails db:migrate\` predeploy remained unchanged.
