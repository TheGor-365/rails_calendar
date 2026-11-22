# C2.3b7l — offline invitation index discriminator

Date: 2026-11-23; Draft PR #81; G5 BLOCKED.

C2.3b7k one-shot owner approval was consumed. Its owner-reported outcome INDEX_NAME_OR_DEFINITION_DRIFT establishes only a name-or-definition mismatch, not the exact cause. Previous C2.3b7j valid/ready named-index check also failed. No new DB permission is inferred.

The new pure discriminator checks which named index property differs, or whether an alternate index has the expected shape and is valid/ready. It uses the *same* previously reviewed fixed pg_catalog-only SELECT and shape/identity validation. The new manual-only operator has a separate C2.3b7l consent token, clean pinned worktree gate, Unix-socket-only PG16, read-only mode and bounded outputs. No business rows, credentials or raw JSON. Tests are synthetic and denial-only.

CURRENT GATE: C2.3b7l query NOT AUTHORIZED / NOT EXECUTED. Before any local command: successful exact-SHA CI and Security Audit, new clean detached operator worktree verified on owner terminal, then separate explicit owner approval for exactly ONE C2.3b7l scratch pg_catalog read. No automatic retry. Exit code 2 and G5 BLOCKED remain deliberate even if the discriminator succeeds.

Never migrate, reindex, repair, restore, access source/media/backup, run writer/replay, deploy to Railway or merge without a further separately authorized and backup-verified plan.