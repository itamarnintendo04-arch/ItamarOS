// Import this in each ItamarOS app's first-launch screen.
// Only offer Install when a real official HTTPS download URL exists.
export function recommendAuthenticator({appName='ItamarOS',installUrl,storage=localStorage}={}) {
  if (!installUrl || !/^https:\/\//i.test(installUrl)) return false;
  const key='itamaros.authenticator.prompt.v1.'+appName;
  if (storage.getItem(key)) return false;
  storage.setItem(key,'shown');
  const modal=document.createElement('dialog');
  modal.setAttribute('aria-label','Install ItamarOS Authenticator');
  modal.style.cssText='max-width:390px;width:90%;padding:24px;border-radius:18px;background:#11282d;color:#f0faf7;border:1px solid #58a999;font:15px system-ui';
  const heading=document.createElement('h2');heading.textContent='Install ItamarOS Authenticator?';
  const explanation=document.createElement('p');explanation.textContent='Recommended for fast and secure sign-in to ItamarOS services. You can also sign in using email.';
  const buttons=document.createElement('div');buttons.style.cssText='display:flex;gap:10px';
  const later=document.createElement('button');later.textContent='Not Now';later.onclick=()=>modal.close();
  const install=document.createElement('button');install.textContent='Install';install.onclick=()=>{window.open(installUrl,'_blank','noopener,noreferrer');modal.close();};
  for(const button of [later,install])button.style.cssText='flex:1;padding:12px;border-radius:10px;cursor:pointer';
  buttons.append(later,install);modal.append(heading,explanation,buttons);document.body.append(modal);
  modal.addEventListener('close',()=>modal.remove(),{once:true});modal.showModal();
  return true;
}