-- ============================================================================
--  PAGE 4 SETUP — the database function
-- ============================================================================
--  Paste this whole file into the Supabase SQL Editor and run it once.
--
--  It creates ONE function that returns the first 10 rows of penguins_rls_on.
--  Once it exists, the browser can call it with:
--
--      db.rpc('first_penguins', { row_limit: 10 })
--
--  Why you have to run this by hand: creating a function is DDL, and PostgREST
--  — the API the browser talks to — is a DATA api. It can call functions, but it
--  cannot create them. Only the SQL Editor, a migration, or a direct connection
--  can. Same reason as the policies on page 2.
--
--  Safe to run more than once: CREATE OR REPLACE swaps the definition in place.
--  It reads penguins_rls_on and never modifies anything.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. The function itself.
-- ----------------------------------------------------------------------------
create or replace function public.first_penguins(row_limit integer default 10)
returns setof public.penguins_rls_on
language sql
stable
security invoker
as $$
  select *
  from public.penguins_rls_on
  order by id
  limit row_limit;
$$;


-- ----------------------------------------------------------------------------
-- 2. Reading the four keywords, because they matter
-- ----------------------------------------------------------------------------
--
--  returns setof public.penguins_rls_on
--      The result is a set of rows shaped exactly like that table. Using the
--      table name as the type means the columns can never drift out of sync
--      with the table — add a column later and the function returns it too.
--
--  language sql
--      Plain SQL rather than PL/pgSQL. Postgres can often inline a simple SQL
--      function straight into the calling query, which is the fastest option.
--      Use plpgsql only when you need variables, loops or IF statements.
--
--  stable
--      "This function only reads; it will not change the database." It lets the
--      planner call it once and reuse the answer inside a bigger query.
--      The other options are:
--          immutable  -> same inputs ALWAYS give the same answer (e.g. a sum)
--          stable     -> reads data, but will not write (this one)
--          volatile   -> may write, or the answer can change between calls
--      Marking a writing function stable is a lie that causes strange bugs, so
--      this line is not decoration.
--
--  security invoker
--      THE IMPORTANT ONE FOR THIS WORKSHOP.
--      The function runs with the permissions of whoever CALLED it, so Row
--      Level Security still applies inside it. A student calling this function
--      sees only the rows their own policies allow — no more.
--
--      The alternative is `security definer`, which runs the function as its
--      OWNER (usually the postgres superuser) and therefore BYPASSES RLS
--      completely. A definer function is a door around every policy you wrote.
--      It is occasionally necessary and always deserves a second look.
--
--      Note the contrast with a VIEW, which behaves like definer by default
--      (the view owner's rights and policies apply) unless you declare it
--      `with (security_invoker = true)`.


-- ----------------------------------------------------------------------------
-- 3. GRANT — one more gate, and the one everybody forgets
-- ----------------------------------------------------------------------------
-- You have now met three separate gates in this workshop:
--
--     grant    -> may this role touch the object at all?
--     policy   -> WHICH ROWS does the operation apply to?
--     and now  -> may this role EXECUTE this function?
--
-- Postgres grants EXECUTE on new functions to PUBLIC automatically, so this
-- line is usually belt-and-braces. It is here so you can see the gate exists,
-- and because on a locked-down project it will be the thing that bites you.
-- If a function returns 404 to one role and works for another, check here.

grant execute on function public.first_penguins(integer) to anon, authenticated;


-- ----------------------------------------------------------------------------
-- 4. Tell the API about the new function.
-- ----------------------------------------------------------------------------
-- PostgREST keeps a cache of what exists. Supabase normally refreshes it
-- automatically when you run DDL, but this forces the issue so the function is
-- callable immediately. Harmless to run.

notify pgrst, 'reload schema';


-- ----------------------------------------------------------------------------
-- 5. A label, so the dashboard explains itself later.
-- ----------------------------------------------------------------------------
comment on function public.first_penguins(integer) is
  'Returns the first N penguins (default 10). Runs as the caller, so RLS applies.';


-- ============================================================================
--  VERIFY — run these to see what you created.
-- ============================================================================

-- Call it directly in SQL, as if you were the browser.
select * from public.first_penguins(10);

-- Or with a different limit.
select * from public.first_penguins(3);

-- Confirm it is INVOKER (not definer) and stable.
-- prosecdef = false  -> security invoker, RLS applies. TRUE here would mean the
--                       function bypasses every policy on the table.
select proname                                as function_name,
       pg_get_function_arguments(oid)         as arguments,
       prosecdef                              as is_security_definer,
       provolatile                           as volatility  -- 's' = stable
from pg_proc
where proname = 'first_penguins';


-- ============================================================================
--  TROUBLESHOOTING
-- ============================================================================
-- If the page reports that it cannot find the function, the API cache is stale.
-- Run this on its own and reload the page:
--
--     notify pgrst, 'reload schema';
--
-- If you later change the function's ARGUMENTS (not just its body), Postgres
-- treats it as a new overload and you can end up with two versions. To see
-- every overload and drop the right one:
--
--     select oid::regprocedure from pg_proc where proname = 'first_penguins';
--     drop function public.first_penguins(integer);
--
-- Note: dropping the function does NOT affect the data. Only the function goes.
