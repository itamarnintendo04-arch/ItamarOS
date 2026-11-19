import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.119.1/+esm';

const SUPABASE_URL = 'https://slqjkysinhfkqjoigfuz.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable__WVo13dRVkDYChuGxHxk9A_CDoVR9ts';
const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { flowType: 'pkce', detectSessionInUrl: true, persistSession: true }
});
const $ = (id) => document.getElementById(id);
let currentUser = null;
let refreshing = false;
const status = (message) => { $('status').textContent = message || ''; };
const element = (tag, value, cls) => {
  const node = document.createElement(tag);
  if (value !== undefined) node.textContent = String(value);
  if (cls) node.className = cls;
  return node;
};
const button = (label, action, cls = 'secondary') => {
  const node = element('button', label, cls);
  node.type = 'button';
  node.addEventListener('click', action);
  return node;
};
async function call(action, data = {}) {
  const { data: result, error } = await supabase.functions.invoke('itamar-oauth-beta', {
    body: { action, ...data }
  });
  if (error) {
    let detail = error.message;
    try {
      if (error.context instanceof Response) {
        const json = await error.context.json();
        detail = json.error || detail;
      }
    } catch {}
    throw new Error(detail);
  }
  if (result?.error) throw new Error(result.error);
  return result;
}
async function refreshUser() {
  if (refreshing) return;
  refreshing = true;
  try {
    const { data, error } = await supabase.auth.getUser();
    if (error) throw error;
    currentUser = data.user || null;
    $('loginPanel').hidden = Boolean(currentUser);
    $('appPanel').hidden = !currentUser;
    $('signOut').hidden = !currentUser;
    $('userName').textContent = currentUser ? (currentUser.email || 'ItamarOS account') : '';
    if (currentUser) {
      await loadMyApplications();
      $('adminPanel').hidden = currentUser.app_metadata?.itamaros_admin !== true;
      if (!$('adminPanel').hidden) await loadAdmin();
    } else $('adminPanel').hidden = true;
  } catch (error) {
    status(error.message || 'Sign-in could not be verified.');
  } finally { refreshing = false; }
}
async function loadMyApplications() {
  const results = $('requests');
  results.replaceChildren(element('p', 'Loading applications…', 'muted'));
  try {
    const payload = await call('mine');
    results.replaceChildren();
    const requests = payload.requests || [];
    if (!requests.length) results.append(element('p', 'You have not applied yet.', 'muted'));
    for (const item of requests) {
      const card = element('div', undefined, 'request');
      card.append(element('h3', item.app_name));
      card.append(element('p', 'Status: ' + item.status.replaceAll('_', ' '), 'status'));
      card.append(element('p', 'Application type: ' + item.client_type));
      card.append(element('p', 'Callback: ' + item.redirect_uri));
      if (item.client_id) card.append(element('p', 'Client ID: ' + item.client_id));
      if (item.status === 'approved') card.append(button('Reveal client credentials (once)', () => claim(item.id), 'primary'));
      if (item.status === 'issuing') card.append(element('p', 'Registration is being processed. Contact support if this persists.', 'muted'));
      results.append(card);
    }
  } catch (error) { results.replaceChildren(element('p', error.message, 'warning')); }
}
function showCredentialRow(parent, label, value) {
  const wrapper = element('div', undefined, 'credential-row');
  wrapper.append(element('strong', label));
  wrapper.append(element('code', value ?? 'Not required', 'code'));
  wrapper.append(button('Copy', async () => {
    try { await navigator.clipboard.writeText(String(value ?? '')); status(label + ' copied.'); }
    catch { status('Copy manually using the text above.'); }
  }));
  parent.append(wrapper);
}
async function claim(id) {
  if (!confirm('Your secret will be shown only once. Continue?')) return;
  status('Registering your OAuth client…');
  try {
    const result = await call('claim', { id });
    const panel = $('credentials');
    panel.replaceChildren();
    showCredentialRow(panel, 'Client ID', result.client_id);
    if (result.client_secret) showCredentialRow(panel, 'Client Secret', result.client_secret);
    else panel.append(element('p', 'Public client: use PKCE. No client secret is issued.', 'muted'));
    showCredentialRow(panel, 'Authorization endpoint', result.authorization_url);
    showCredentialRow(panel, 'Token endpoint', result.token_url);
    if (result.notice) panel.append(element('p', result.notice, 'warning'));
    $('credentialsPanel').hidden = false;
    $('credentialsPanel').scrollIntoView({ behavior: 'smooth' });
    status('Client created. Save your credentials before closing this page.');
    await loadMyApplications();
  } catch (error) { status(error.message); }
}
async function loadAdmin() {
  const pending = $('pending');
  pending.replaceChildren(element('p', 'Loading…', 'muted'));
  try {
    const res = await call('list_pending');
    pending.replaceChildren();
    if (!res.requests?.length) { pending.append(element('p', 'No pending or awaiting-claim applications.', 'muted')); return; }
    for (const item of res.requests) {
      const card = element('div', undefined, 'request');
      card.append(element('h3', item.app_name));
      for (const line of [
        'Developer: ' + item.developer_name,
        'Email: ' + item.email,
        'Purpose: ' + item.purpose,
        'Website: ' + (item.app_website || 'Not supplied'),
        'Callback: ' + item.redirect_uri,
        'Type: ' + item.client_type
      ]) card.append(element('p', line));
      const actions = element('div', undefined, 'admin-actions');
      if (item.status === 'approved') {
        card.append(element('p', 'Approved — awaiting credential claim.', 'status'));
        actions.append(button('Resend approval email', () => resendApproval(item.id), 'secondary'));
      } else {
        actions.append(
          button('Approve', () => review(item.id, 'approve'), 'primary'),
          button('Reject', () => review(item.id, 'reject'), 'secondary')
        );
      }
      card.append(actions);
      pending.append(card);
    }
  } catch (error) { pending.replaceChildren(element('p', error.message, 'warning')); }
}
async function resendApproval(id) {
  if (!confirm('Send another secure sign-in link to the approved applicant?')) return;
  status('Sending approval email…');
  try {
    const result = await call('resend_email', { id });
    status(result.email_sent ? 'A new approval email was sent.' : 'Could not send the email.');
  } catch (error) { status(error.message); }
}
async function review(id, decision) {
  if (!confirm('Are you sure you want to ' + decision + ' this developer application?')) return;
  status('Updating application…');
  try {
    const result = await call('review', { id, decision });
    if (result.status === 'approved') {
      status(result.email_sent ? 'Approved! A secure sign-in email was sent.' :
        'Approved, but email delivery failed. Configure Supabase Auth SMTP and retry notification.');
    } else status('Application rejected.');
    await loadAdmin();
  } catch (error) { status(error.message); }
}
$('loginForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const email = $('loginEmail').value.trim();
  const submit = $('loginForm').querySelector('button');
  submit.disabled = true;
  status('Sending a secure sign-in link…');
  try {
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        shouldCreateUser: false,
        emailRedirectTo: new URL('/developers/index.html', window.location.origin).href
      }
    });
    if (error) throw error;
    status('Check your inbox. Follow the sign-in link to continue.');
  } catch (error) { status(error.message); }
  finally { submit.disabled = false; }
});
$('applicationForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const submit = $('submitRequest');
  submit.disabled = true;
  status('Submitting your application…');
  try {
    const fields = Object.fromEntries(new FormData(event.currentTarget).entries());
    const result = await call('submit', fields);
    if (result.ok) {
      status('Application received! You will be contacted after review.');
      event.currentTarget.reset();
      await loadMyApplications();
    }
  } catch (error) { status(error.message); }
  finally { submit.disabled = false; }
});
$('signOut').addEventListener('click', async () => {
  const { error } = await supabase.auth.signOut();
  if (error) { status(error.message); return; }
  $('credentialsPanel').hidden = true;
  $('credentials').replaceChildren();
  status('Signed out.');
  await refreshUser();
});
$('refreshAdmin').addEventListener('click', loadAdmin);
$('closeCredentials').addEventListener('click', () => {
  $('credentials').replaceChildren();
  $('credentialsPanel').hidden = true;
  status('Credentials have been hidden. The secret cannot be retrieved again.');
});
supabase.auth.onAuthStateChange(() => {
  queueMicrotask(() => refreshUser());
});
refreshUser();
