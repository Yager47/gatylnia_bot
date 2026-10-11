# Project: Telegram bot for a small friend group

Rails 8 app that receives Telegram webhook updates and replies in one private group chat. Small, but treated like production code: the purpose of this project is for me (an experienced Rails dev returning after a 6-month break (pre-AI dev period)) to practice reviewing AI-written code critically and AI development using agentsm skills, etc.

Treat it like a real production codebase, not a toy — the point of this project is to practice reviewing AI output critically, so don't go easy on quality just because it's a sample.

## Stack
- Rails 8.x, Ruby 3.3+
- PostgreSQL
- RSpec for tests (request specs + model specs, no controller specs)
- FactoryBot for test data (not fixtures)

## Conventions
- Webhook controller must respond fast (200) and push real work to a job.
- Business logic that touches more than one model belongs in a service object under `app/services/`, not in a model callback or a fat controller action.
- Prefer `includes` over implicit N+1s. If you add a view that renders an association, check whether the controller eager-loads it.
- Every Telegram update has an `update_id`. Store it in a table with a unique index and ignore duplicates. Jobs must be safe to run twice.
- No bot logic in controllers or model callbacks.
- Any migration that adds a column with a default value, adds a NOT NULL constraint, or adds an index to a table that could be large in production must use a safe, multi-step approach — flag this explicitly rather than writing a single blocking migration, and explain the risk in your response before writing the code.
- Use strong parameters in every controller action that accepts user input. Never use `params.permit!`.
- Write a request spec for every new controller action.

## Migrations
- Flag any migration that could lock a big table (default values, NOT NULL, indexes) and explain the risk BEFORE writing it.
- Use the safe multi-step pattern when relevant (add nullable column, backfill, add constraint; `algorithm: :concurrently` for indexes with `disable_ddl_transaction!`).

## Working rules
- Don't add gems without asking first.
- Don't touch `db/schema.rb` by hand — only via migrations.
- Don't silently fix something I didn't ask about. Flag them and ask.
- Keep changes small. One feature per task, commit-sized diffs.
- Point out anything that would hurt at scale (N+1, missing index, locking migrations, unbounded loops) even if I didn't ask.
- When I write a slice myself, review it honestly rather than just agreeing with it.
