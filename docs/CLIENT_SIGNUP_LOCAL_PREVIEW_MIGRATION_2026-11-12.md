## Isolated local database upgrade gate

Existing isolated preview DB was loaded with the prior RC-035 schema before the client signup migration was introduced. Do **not** run the empty-only `bin/rc-preview-schema` again; it correctly refuses nonempty data.

After verifying the exact branch SHA, Ruby 3.4.12, local `RC_LOCAL_DEV_DATABASE_URL`, and explicit `RAILS_ENV=development` (never disclose the URL), run:

```sh
ruby -c bin/rc-preview-client-migrate
bin/rc-preview-client-migrate
```

It checks the physical PostgreSQL DB name, existence of the old base tables, absence of the new tables/columns, and migration version. It executes exactly the new additive migration in that single local preview DB. It never creates/drops an entire database, and refuses to run twice or against any shared/production database. If it errors mid-migration, stop and inspect before any retry.
