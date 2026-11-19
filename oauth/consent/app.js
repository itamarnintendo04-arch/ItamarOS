import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.119.1/+esm';
const supabase = createClient(
  'https://slqjkysinhfkqjoigfuz.supabase.co',
  'sb_publishable__WVo13dRVkDYChuGxHxk9A_CDoVR9ts',
  { auth: { flowType: 'pkce', detectSessionInUrl: true, persistSession: true } }
);
const $ = (id) => document.getElementById(id);
const status = (text) => { $('status').textContent = text; };
const authorizationId = new URLSearchParams(location.search).get('authorization_id');
let loading = false;
async function load() {
  if (loading) return;
  loading = true;
  try {
    if (!authorizationId || authorizationId.length > 256) throw new Error('Missing or invalid authorization request.');
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError) throw authError;
    $('login').hidden = Boolean(user);
    if (!user) {
      $('heading').textContent = 'Sign in to ItamarOS';
      $('description').textContent = 'Sign in to review this application’s permissions.';
      return;
    }
    const { data: details, error } = await supabase.auth.oauth.getAuthorizationDetails(authorizationId);
    if (error) throw error;
    if (!details) throw new Error('Authorization request was not found.');
    if (!('authorization_id' in details) && details.redirect_url) {
      location.replace(details.redirect_url);
      return;
    }
    $('client').textContent = details.client?.name || 'Unknown app';
    $('redirectUri').textContent = details.redirect_uri || 'Not available';
    const perms = (details.scope || '').trim().split(/\s+/).filter(Boolean);
    $('scopes').textContent = perms.length ? perms.join(', ') : 'Basic account access';
    $('heading').textContent = 'Authorize ' + (details.client?.name || 'application') + '?';
    $('description').textContent = 'This app is requesting permission to use your ItamarOS identity.';
    $('consent').hidden = false;
    status('');
  } catch (error) {
    status(error.message || 'Unable to load authorization request.');
    $('description').textContent = 'The authorization request could not be loaded.';
    $('consent').hidden = true;
  } finally { loading = false; }
}
$('loginForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const email = $('email').value.trim();
  status('Sending a sign-in email…');
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: false, emailRedirectTo: location.href }
  });
  status(error ? error.message : 'Check your inbox and open the sign-in link.');
});
async function decide(approve) {
  $('approve').disabled = $('deny').disabled = true;
  status(approve ? 'Approving access…' : 'Denying access…');
  try {
    const response = approve
      ? await supabase.auth.oauth.approveAuthorization(authorizationId)
      : await supabase.auth.oauth.denyAuthorization(authorizationId);
    if (response.error) throw response.error;
    if (!response.data?.redirect_url) throw new Error('Missing OAuth redirect URL.');
    location.assign(response.data.redirect_url);
  } catch (error) {
    status(error.message || 'Unable to finish authorization.');
    $('approve').disabled = $('deny').disabled = false;
  }
}
$('approve').addEventListener('click', () => decide(true));
$('deny').addEventListener('click', () => decide(false));
supabase.auth.onAuthStateChange(() => queueMicrotask(() => load()));
load();
