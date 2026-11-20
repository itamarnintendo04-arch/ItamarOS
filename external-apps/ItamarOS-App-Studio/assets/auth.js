import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.119.1/+esm';

// These are public, browser-safe project credentials. Never place a secret/service-role key here.
const SUPABASE_URL = 'https://ljvbuiilxcawhfvylzgq.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_60hWXLUX6Nds2nu9wqdjDQ_JcaBdsuF';
const LOVABLE_PROVIDER = 'custom:lovable';
const REDIRECT_URL = new URL('/projects/', window.location.origin).href;

const client = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: {
    flowType: 'pkce',
    detectSessionInUrl: true,
    autoRefreshToken: true,
    persistSession: true,
    storageKey: 'itamaros-app-studio-auth'
  }
});

const $ = (id) => document.getElementById(id);
const authDialog = $('authDialog');
const openAuth = $('openAuth');
const closeAuth = $('closeAuth');
const loginButton = $('lovableSignIn');
const signOutButton = $('signOut');
const account = $('authAccount');
const accountName = $('authName');
const message = $('authMessage');

function showMessage(text) {
  message.textContent = text || '';
}

function showDialog() {
  showMessage('');
  if (!authDialog.open) authDialog.showModal();
}

function renderUser(user) {
  const signedIn = Boolean(user);
  openAuth.hidden = signedIn;
  account.hidden = !signedIn;
  accountName.textContent = signedIn
    ? (user.user_metadata?.full_name || user.user_metadata?.name || user.email || 'Account')
    : '';
  if (signedIn && authDialog.open) authDialog.close();
}

openAuth.addEventListener('click', showDialog);
closeAuth.addEventListener('click', () => authDialog.close());

loginButton.addEventListener('click', async () => {
  loginButton.disabled = true;
  showMessage('Redirecting to Lovable…');
  try {
    const { error } = await client.auth.signInWithOAuth({
      provider: LOVABLE_PROVIDER,
      options: { redirectTo: REDIRECT_URL }
    });
    if (error) throw error;
  } catch (error) {
    showMessage(error.message || 'Unable to start Lovable sign-in.');
  } finally {
    loginButton.disabled = false;
  }
});

signOutButton.addEventListener('click', async () => {
  signOutButton.disabled = true;
  try {
    const { error } = await client.auth.signOut();
    if (error) throw error;
    renderUser(null);
  } catch (error) {
    showDialog();
    showMessage(error.message || 'Unable to sign out.');
  } finally {
    signOutButton.disabled = false;
  }
});

client.auth.onAuthStateChange((_event, session) => {
  renderUser(session?.user ?? null);
});

async function initialize() {
  const params = new URLSearchParams(window.location.search);
  const callbackError = params.get('error_description') || params.get('error');
  try {
    const { data, error } = await client.auth.getSession();
    if (error) throw error;
    renderUser(data.session?.user ?? null);
    if (data.session && params.has('code')) {
      const clean = new URL(window.location.href);
      clean.searchParams.delete('code');
      clean.searchParams.delete('sb_flow_id');
      window.history.replaceState(window.history.state, '', clean.pathname + clean.search + clean.hash);
    }
  } catch (error) {
    showDialog();
    showMessage(error.message || 'Unable to restore the sign-in session.');
  }
  if (callbackError) {
    showDialog();
    showMessage(callbackError);
    const clean = new URL(window.location.href);
    clean.searchParams.delete('error');
    clean.searchParams.delete('error_code');
    clean.searchParams.delete('error_description');
    window.history.replaceState(window.history.state, '', clean.pathname + clean.search + clean.hash);
  }
}

initialize();
