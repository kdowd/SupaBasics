# Supabase Auth Workshop

A hands-on introduction to Supabase for students with no prior Supabase experience. By the end of the five pages they will have gone from _"anyone can read and write this table"_ to _"you can only see your own rows"_.

## Files

| File                   | Purpose                                                                                                    |
| ---------------------- | ---------------------------------------------------------------------------------------------------------- |
| `index.html`           | **Page 1** — loads all 344 rows from `penguins` with RLS switched off                                      |
| `page-2-rls.html`      | **Page 2** — runs the same four operations against an RLS-off and an RLS-on table, side by side            |
| `page-3-login.html`    | **Page 3** — email/password login, decodes the live JWT, and proves the `authenticated` policy now matches |
| `page-4-function.html` | **Page 4** — calls a Postgres function with `db.rpc()` and renders the rows it returns                     |
| `basicConnect.html`    | **Page 5** — takes apart the CDN `<script>` tag and `createClient()`, with a live inspection panel         |
| `supabase-config.js`   | The one shared Supabase client used by every page. Change the project URL/key here only.                   |
| `setup-page2.sql`      | Run once in the SQL Editor to build the secured comparison table                                           |
| `setup-function.sql`   | Run once in the SQL Editor to create the `first_penguins()` function                                       |

## Running it

A local web server is best, but it is not strictly required (the pages use plain `<script>` tags, not ES modules).

```bash
# from this folder
python3 -m http.server 8000
# then open http://localhost:8000
```

Double-clicking `index.html` also works. The one thing that behaves differently over `file://` is the **Copy** button: the Clipboard API is blocked on non-secure origins, so the pages fall back to a manual copy. That is handled, but
`localhost` is cleaner.

## One-time setup for page 2

Page 2 compares two tables, so it needs a second one. Paste `setup-page2.sql` into the Supabase SQL Editor and run it. It drops and rebuilds `penguins_rls_on` as a copy of the 344 penguin rows with RLS on and a public read policy. **It
never touches `penguins`.**

Page 2 tells you what it found, so just load it and read the banner.

> **The empty-table trap.** If the secured table exists but holds 0 rows, a read returns an empty list with no error — which is _indistinguishable_ from a policy that blocks everything. Page 2 detects this and warns you. Always populate a
> table before using it to test a read policy.

### Which table is "the secured one"?

Page 2 looks for the first name in `SECURE_CANDIDATES` (`penguins_rls_on`, then `penguins_secure`) and uses whichever exists, so renaming the table does not break the page. It prints the name it adopted into the page text.

## What students should see on page 2

| Operation     | `penguins` (RLS off) | `penguins_rls_on` (RLS on)   |
| ------------- | -------------------- | ---------------------------- |
| Read all rows | 344 rows             | 344 rows                     |
| Insert a row  | **created**          | **blocked — `42501`**        |
| Update a row  | **1 row changed**    | **0 rows changed, no error** |
| Delete a row  | **1 row deleted**    | **0 rows deleted, no error** |

Verified against the live project on 2026-10-08.

The two lessons worth stopping on:

1. **RLS on did not break reading.** The policy `for select using (true)` says "everyone may read", so reading still works. RLS decides _which rows_, not whether the table is reachable.
2. **Insert shouts, update and delete whisper.** A blocked `INSERT` raises `42501`. A blocked `UPDATE` or `DELETE` silently matches zero rows and reports success. "My update runs but nothing changes" is the most common RLS bug in the wild.

## How page 2 handles writing to live data

You chose to let the write test hit the real `penguins` table, so the page is built around that risk:

- Every row it creates is tagged `species = '__PROBE__'`, and the test deletes it again immediately.
- **A hard guard (`assertProbeScoped`) refuses any UPDATE or DELETE on `penguins` that is not filtered by that tag.** There is no code path that can wipe the table, even if someone edits the page carelessly later.
- A **Clean up now** button removes any `__PROBE__` rows on demand.
- The page checks for leftover probe rows every time it loads and tells you if it finds any.
- A `pagehide` handler fires a last-ditch `keepalive` DELETE if you close the tab mid-test.

The `penguins_rls_on` copy is treated as disposable, so the page aims at a real existing row there (`id = 1`) to prove that RLS blocks changes to rows that genuinely exist.

_Known cosmetic side effect:_ Postgres advances the `id` sequence even for rows that are deleted again, so after a class the next real insert may start from id 350-odd rather than 345. Harmless — ids are not sequential in any meaningful
way.

## Page 3 — logging in and the JWT

Log in with the Auto-Confirmed account you created (e.g. `admin@admin.com`). The page then decodes the real access token in the browser and shows the three JWT parts.

**Verified end to end on 2026-10-08** — this is the actual log the page produced:

```
[ok]      SIGN IN · admin@admin.com        -> got a JWT with role = authenticated
[ok]      INSERT · as role: authenticated  -> SUCCESS — created row id 354
[info]    SIGN OUT · token discarded
[blocked] INSERT · as role: anon           -> 42501 (same as page 2)
```

### The one idea

Two identity headers, two different jobs:

```
apikey         -> which project   (always the publishable key, never changes)
Authorization  -> who is asking   (publishable key -> anon; user's JWT -> authenticated)
```

Signing in changes only the second line. Nothing about the policy, the table or the key changes. The JWT's `role` claim is what PostgREST turns into the Postgres role, and `to authenticated` finally matches.

### Verified JWT facts for this project

- Algorithm is **`ES256`** (ECDSA P-256), _not_ HMAC — the header carries a `kid` naming the signing key. Supabase holds the private half; nobody else can forge one.
- Access token lifetime is exactly **3600 seconds**; `supabase-js` auto-refreshes it.
- The payload carries `role: "authenticated"`, `sub` (user UUID), `aal: "aal1"`, `amr: [{method: "password"}]`, `session_id` and `is_anonymous: false`.
- The session is stored in `localStorage` under `sb-decwucuwqnzrxzbxxifu-auth-token`, so it survives reloads.

### ⚠️ Email confirmation is ON

`/auth/v1/settings` reports `mailer_autoconfirm: false`. Your `admin@admin.com` works because it was created Auto-Confirmed. **A signup form would not work** — new users cannot log in until they click an email link. Page 3 is deliberately
login-only. To allow student signups, turn off _Confirm email_ under Authentication → Sign In / Providers → Email.

### The missing DELETE policy

The table has SELECT and INSERT policies only, so DELETE is default-denied for everyone, including logged-in users. This was verified: the delete returned **`HTTP 200` with an empty list** — reporting success while deleting nothing.

Consequence: **every test row page 3 inserts is stranded** and can only be removed in the SQL Editor.

```sql
delete from public.penguins_rls_on where species = '__TEST_LOGIN__';
```

**Recommended fix** — scope delete to the test rows rather than handing out `using (true)`, which would let any logged-in student delete all 344 penguins:

```sql
create policy "Students can delete their own test rows"
  on public.penguins_rls_on
  for delete to authenticated
  using ( species = '__TEST_LOGIN__' );
```

Dashboard equivalent: Database → Policies → New Policy → Create a policy from scratch → command `DELETE` → role `authenticated` → paste `species = '__TEST_LOGIN__'` into the USING box (Supabase greys out WITH CHECK, because delete has no
new row to check).

This is a great preview of page 4: `true` replaced by a real condition.

### Two console traps worth demonstrating

```js
await db.auth.getSession(); // reads localStorage — instant, but the user controls it
await db.auth.getUser(); // asks the auth server — cannot be faked
```

Neither is an authorization boundary. A student can open the console and call `db.from('penguins_rls_on').insert(...)` directly, or copy the token out of localStorage and use it elsewhere. **RLS is the only thing that actually enforces
anything**; every browser-side check is a courtesy to the user.

## Page 4 — calling a database function

Run `setup-function.sql` in the SQL Editor first. It creates one function:

```sql
create or replace function public.first_penguins(row_limit integer default 10)
returns setof public.penguins_rls_on
language sql
stable
security invoker
as $$
  select * from public.penguins_rls_on order by id limit row_limit;
$$;
```

The page then calls `db.rpc('first_penguins', { row_limit: 10 })` and renders the rows. There is an input for `row_limit` so students can watch the argument reach the SQL `limit` clause.

Page 4 tells you which state it is in, so just load it. Before the function exists it shows a red **Not set up** banner with the exact error (`PGRST202`) and a pointer to the script.

### The five keywords, and why each matters

| Keyword                                | Why it is there                                                                                                                                                  |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `returns setof public.penguins_rls_on` | Rows shaped like the table; columns can never drift out of sync.                                                                                                 |
| `language sql`                         | Postgres can inline simple SQL functions, so this is the fastest option. Use `plpgsql` only for variables/loops/IF.                                              |
| `stable`                               | “Reads but never writes.” Lets the planner call it once. `immutable` = same answer always; `volatile` = may write. Lying here causes bizarre bugs.               |
| `security invoker`                     | **Runs as the caller, so RLS still applies.** The alternative, `security definer`, runs as the owner and **bypasses RLS entirely** — a door around every policy. |
| `grant execute`                        | The third gate: grants → policies → execute. Postgres grants EXECUTE to PUBLIC by default, which is why forgetting it is so confusing when it bites.             |

### Verified against the live API

**The function itself is live and working** (verified 2026-10-08 after the script was run in the SQL Editor):

```
POST /rest/v1/rpc/first_penguins  {"row_limit": 10}  -> HTTP 200, 10 rows, ids 1-10
POST /rest/v1/rpc/first_penguins  {"row_limit": 3}   -> HTTP 200, 3 rows,  ids 1-3
POST /rest/v1/rpc/first_penguins  {}                 -> HTTP 200, 10 rows (the default works)
POST /rest/v1/rpc/first_penguins  {"limit": 3}       -> PGRST202, with the helpful hint:
     "Perhaps you meant to call the function public.first_penguins(row_limit)"
```

- A missing function returns **`PGRST202` / HTTP 404** with `"Could not find the function public.first_penguins(row_limit) in the schema cache"`.
- PostgREST distinguishes signatures precisely: calling with no arguments produces _"without parameters"_, while passing `row_limit` produces _"with parameter row_limit"_. That is why `PGRST202` means "no function with that **signature**",
  not "no function".
- Because the definition has `default 10`, `await db.rpc('first_penguins')` with no arguments also works — useful as a console demo.

### Is the function permanent?

Yes. Running the script in the SQL Editor **executed** it; the SQL Editor is only a text box. Postgres stored the function in its catalog, and it lives there like a table does — it survives closing the browser, logging out, and rebooting.
You never paste it again unless you _want_ to change it.

`create or replace` also means re-running the script is safe: it swaps the definition rather than creating a second copy. (Caveat: that holds as long as the **arguments** stay the same. Change an argument and Postgres treats it as a new
overload — see the troubleshooting section in `setup-function.sql`.)

**But "in the database" is not the same as "in your project".** The function is not in any of your HTML files. If you ever rebuild the project — a fresh Supabase project, a restored backup, or a move to a real deployment — it will not be
there. That is exactly what `setup-function.sql` is for: keep it in the folder and it becomes the source of truth you can re-run anywhere.

For real projects (not a workshop), you would not paste into a web editor at all. You would keep that SQL in version control and apply it with migrations, so every environment and every teammate gets the same schema.

Worth knowing for a project that sits idle between terms: Supabase pauses free-plan projects after about a week of inactivity. Pausing is not deleting — you resume from the dashboard and everything is intact. Supabase emails warnings before
doing anything more drastic, so keep an eye on the account email if this workshop will sit unused for months.

### The one idea

A function is **not** automatically a security boundary. This one is `security invoker`, so if `penguins_rls_on` had no select policy the function would faithfully return zero rows and report success. Wrapping logic in a function organises
it; it does not protect it.

## Page 5 — the library and `createClient()`

No setup needed; it works immediately. The page explains why a library is required at all, where the CDN file comes from, and what `createClient()` does — then proves it with a live inspection panel.

### Verified facts the page displays (all read from the real library at runtime)

```
typeof supabase                 object
typeof supabase.createClient    function
things it exports               51 names
supabase.version                not exposed by the UMD build
built in                        0 ms — no network request was made
is a SupabaseClient             true
createClient takes              3 parameters (url, key, options)
session storage key             sb-decwucuwqnzrxzbxxifu-auth-token
identifies itself as            supabase-js/2.117.3; runtime=web
```

One URL becomes five endpoints — the library derives them all:

```
database (rest)  https://…supabase.co/rest/v1
login (auth)     https://…supabase.co/auth/v1
realtime         wss://…supabase.co/realtime/v1
storage          https://…supabase.co/storage/v1
functions        https://…supabase.co/functions/v1
```

### The two ideas worth the most class time

**1. `createClient()` does not connect to anything.** It makes no network request — it is pure configuration. Proof, which students can reproduce:

```js
supabase.createClient('https://nonsense.invalid', 'fake-key');
// -> no error. It happily builds a client for a domain that has never existed.
```

So when a page does nothing, **debug the first query, not the client**. The client line cannot fail on a mistyped URL, because it never contacts the server.

**2. It only validates two things, and they throw:**

```
createClient('', '')                    -> supabaseUrl is required.
createClient('https://x.supabase.co','') -> supabaseKey is required.
```

Everything after that **returns** an error instead of throwing:

```js
const bad = supabase.createClient('https://nonsense.invalid', 'x');
(await bad.from('t').select()).error.message; // 'TypeError: Failed to fetch' — no exception
```

That is page 1's lesson (`{ data, error }`, always check `error`) arriving from the other direction, and it is the single habit worth sending students away with.

### Why the CDN tag looks like it does

| Part                    | Why                                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------------------- |
| `cdn.jsdelivr.net/npm`  | A CDN mirror of npm — no `npm install`, no build step, works from a double-clicked file           |
| `@supabase/supabase-js` | The package name                                                                                  |
| `@2.117.3`              | Pinned deliberately, so a new release cannot break a lesson plan overnight                        |
| `/dist/umd/supabase.js` | The UMD build defines one global `supabase`; the ESM build would need `import` plus an import map |

## The table

```
id · species · island · bill_length_mm · bill_depth_mm
   · flipper_length_mm · body_mass_g · sex · year
```

344 rows: Adelie (152), Gentoo (124), Chinstrap (68) sampled across 3 islands in 2007-2009.

**Data-quality talking points** (worth 2 minutes of class time):

- `sex` contains the string `"NA"` in 11 rows — 168 male, 165 female, 11 `"NA"`
- 2 rows use `0` for _every_ measurement instead of a proper null
- There are **no real `null` values anywhere**, so page 1's dash-for-null rule never triggers. Messy sentinel values are usually more dangerous than nulls, because `0` sails straight into an average.

## The teaching arc

Page 1 is deliberately insecure. The three ideas it sets up:

1. **The publishable key is not a secret.** It is _designed_ to sit in browser code. Students should be told this explicitly, because every instinct says otherwise.
2. **The key is not what protects the data — RLS is.** With RLS off, Supabase never asks _"who is asking?"_, so an anonymous visitor gets everything.
3. **Supabase does not throw on error.** It returns `{ data, error }`. Checking `error` before touching `data` is the single habit that prevents most blank screens.

Things students should try in the console while page 1 is open:

```js
db; // the client object, shared by all pages
await db.from('penguins').select('*'); // the same query, done live
await db.from('penguins').select('species'); // only one column
db.auth.getSession(); // null — nobody is logged in
```

Handy for showing the 1000-row default cap: `await db.from('penguins').select('*').range(0, 9)` returns just the first ten rows. Try it against `penguins_rls_on` too — same result, same open read policy.

For page 2, the console equivalent of the whole lesson:

```js
await db.from('penguins').insert({species: 'test'}); // succeeds — RLS is off
await db.from('penguins_rls_on').insert({species: 'test'}); // 42501 — policy refuses
await db.from('penguins_rls_on').update({island: 'x'}).eq('id', 1); // 0 rows, no error
```

## Permissive vs restrictive policies

Worth getting right before teaching it, because the words are misleading: **permissive/restrictive describe how policies COMBINE, not how strict they are.**

- Permissive policies are OR-ed together; they can only ever _widen_ access.
- Restrictive policies are AND-ed on top; they can only ever _narrow_ access.
- **If only restrictive policies exist, no rows are accessible at all.** Restrictive can never grant — it can only subtract.

So the normal choice is a few clear **permissive** policies, one per operation. Use **restrictive** sparingly, as a guard rail for an invariant that must survive every future policy anyone writes — tenant isolation is the classic case. Page
2's single policy is permissive, and the verification query in `setup-page2.sql` shows the `permissive` column in `pg_policies`.

## Notes on the build

- SDK is pinned to `@supabase/supabase-js@2.117.3` via the jsDelivr UMD bundle, so the classroom gets a deterministic version rather than whatever `@2` resolves to that day.
- Script order matters: SDK first, then `supabase-config.js`, then the page script. Reversing them produces `supabase is not defined`.
- Table cells are built with `textContent`, never string-concatenated `innerHTML` — database values are untrusted input. Worth pointing out when you reach it.
- **RLS cannot be toggled from the browser.** Turning RLS on is DDL, and PostgREST is a data API — it exposes tables and RPCs, nothing else. A page holding the publishable key can never run `ALTER TABLE`. Only the SQL Editor, a migration,
  or a direct connection can. Any tutorial that shows a live browser toggle is using a secret key or an `exec_sql` RPC, and you should not teach either.
- The REST API does not expose `pg_policies`, so page 2 proves the RLS difference _behaviourally_ rather than reading the catalog. Use the SQL Editor to see the policies.
- Styling follows the workspace style brief: 1px borders instead of shadows, three-step elevation, a single accent colour, zero box-shadow.
