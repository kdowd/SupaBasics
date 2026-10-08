/* ==========================================================================
   supabase-config.js
   --------------------------------------------------------------------------
   The ONE place in this project where we connect to Supabase.

   Every page (index.html and the later auth pages) loads this file first,
   so we write the URL and the key exactly once and never copy-paste them
   around. If the project ever moves, you change it here and all pages
   follow.

   IMPORTANT — script order in your HTML:
       <script src="...supabase-js..."></script>   <-- loads the SDK first
       <script src="supabase-config.js"></script>  <-- then this file
       <script> ...your page code... </script>     <-- then your page

   The SDK must exist before this file runs, because this file calls
   supabase.createClient(). Reverse the first two lines and you get
   "supabase is not defined" in the browser console.
   ========================================================================== */

/* --------------------------------------------------------------------------
   1. WHERE the database lives.
   --------------------------------------------------------------------------
   This is the project URL from your Supabase dashboard
   (Project Settings -> Data API -> Project URL). It is public information:
   anyone can see which project you are talking to. Knowing the address is
   not the same as being allowed in.
   -------------------------------------------------------------------------- */
const SUPABASE_URL = 'https://decwucuwqnzrxzbxxifu.supabase.co';

/* --------------------------------------------------------------------------
   2. The PUBLISHABLE KEY.
   --------------------------------------------------------------------------
   This key is DESIGNED to be shipped inside browser code. It is not a
   password and it is not a secret. It only tells Supabase *which project*
   is asking — it does not let you bypass security.

   What actually protects your data is Row Level Security (RLS) on each
   table, plus the logged-in user's session token. This key is a low
   privilege "anonymous" identity. On the penguins table we have switched
   RLS OFF on purpose, so this key can read everything — which is exactly
   what we want to demonstrate on page 1, and exactly what we will fix on
   the later pages.

   NEVER put a "secret" / "service_role" key in a web page. Those keys
   ignore RLS entirely and would give away full control of the database.
   -------------------------------------------------------------------------- */
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_ONnalS_8pdIUH2Qrsz67CA_z4Wco9I2';

/* --------------------------------------------------------------------------
   3. Build ONE client and share it.
   --------------------------------------------------------------------------
   createClient() returns a "client" object: a small bundle of methods for
   talking to this project. We store it on `window.db` so that every script
   on the page can reach it as simply `db`, and so it shows up in DevTools
   when you type `db` in the console.

   Later pages will call db.auth.signUp(...) and db.auth.signInWithPassword(...)
   on this exact same object — the auth methods and the database methods
   live together on one client.
   -------------------------------------------------------------------------- */
window.db = supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);

/* Also expose the two raw values.
   The client covers almost everything, but once in a while you need to make a
   plain fetch() call — for example page 2's emergency clean-up, which has to
   fire while the page is unloading, when the SDK is no longer reliable. */
window.SUPABASE_URL = SUPABASE_URL;
window.SUPABASE_PUBLISHABLE_KEY = SUPABASE_PUBLISHABLE_KEY;

/* Handy while teaching: confirm in the console that the setup worked. */
console.log('[config] Supabase client ready ->', SUPABASE_URL);
