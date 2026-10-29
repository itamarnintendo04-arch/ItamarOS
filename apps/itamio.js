/* Itamio — a simple YouTube link organizer and official embedded player.
  This project is not operated by or affiliated with YouTube. */
(()=>{
'use strict';
const $=id=>document.getElementById(id);
const storageKey='itamaros-itamio-favorites';
const node=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;return e};
function videoId(text){
 try{
  const url=new URL(text.trim());
  const host=url.hostname.toLowerCase().replace(/^www\./,'');
  let id='';
  if(host==='youtu.be')id=url.pathname.slice(1).split('/')[0];
  else if(['youtube.com','m.youtube.com','music.youtube.com','youtube-nocookie.com'].includes(host)){
   if(url.pathname==='/watch')id=url.searchParams.get('v')||'';
   else if(url.pathname.startsWith('/shorts/')||url.pathname.startsWith('/embed/')||url.pathname.startsWith('/live/'))id=url.pathname.split('/')[2]||'';
  }
  return /^[A-Za-z0-9_-]{11}$/.test(id)?id:null
 }catch{return null}
}
function saved(){try{const value=JSON.parse(localStorage.getItem(storageKey)||'[]');return Array.isArray(value)?value.filter(x=>/^[A-Za-z0-9_-]{11}$/.test(x)).slice(0,100):[]}catch{return []}}
function persist(items){try{localStorage.setItem(storageKey,JSON.stringify(items))}catch{}}
function makeButton(name,callback){const b=node('button',name);b.type='button';b.onclick=callback;return b}
function mount(){
 const container=$('content');if(!container)return;container.replaceChildren();
 const root=node('section');root.className='ios-feature';root.id='itamio-app';
 root.append(node('h2','▶ Itamio'));
 root.append(node('p','Your personal YouTube video launcher. Uses the official YouTube player; not affiliated with YouTube.'));
 const row=node('div');row.className='ios-row';
 const field=node('input');field.type='url';field.placeholder='Paste a YouTube video link';field.setAttribute('aria-label','YouTube video URL');field.style.flex='1';row.append(field);
 const select=makeButton('Open video',()=>openVideo(field.value));row.append(select);root.append(row);
 const searchRow=node('div');searchRow.className='ios-row';
 const search=node('input');search.placeholder='Search on YouTube';search.setAttribute('aria-label','YouTube search');search.style.flex='1';searchRow.append(search);
 searchRow.append(makeButton('Search YouTube',()=>{const q=search.value.trim();if(q)window.open('https://www.youtube.com/results?search_query='+encodeURIComponent(q),'_blank','noopener')}));root.append(searchRow);
 const message=node('p','Paste a YouTube video link or search using YouTube.');message.id='itamio-message';message.className='ios-caption';root.append(message);
 const viewer=node('div');viewer.id='itamio-viewer';viewer.className='ios-pane';root.append(viewer);
 root.append(node('h3','Saved videos'));
 const list=node('ul');list.id='itamio-saved';list.className='ios-list';root.append(list);
 root.append(node('p','Some videos cannot be embedded. On desktop, you can always open the official video page. A connection is required; no videos are downloaded.'));
 container.append(root);
 field.addEventListener('keydown',e=>{if(e.key==='Enter')openVideo(field.value)});
 renderSaved();
}
function openVideo(link){
 const id=videoId(link);const message=$('itamio-message'),viewer=$('itamio-viewer');
 if(!message||!viewer)return;
 if(!id){message.textContent='Enter a valid YouTube video URL.';return}
 viewer.replaceChildren();
 const frame=node('iframe');
 frame.title='YouTube video (official player)';
 frame.src='https://www.youtube-nocookie.com/embed/'+encodeURIComponent(id);
 frame.allow='accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
 frame.allowFullscreen=true;
 frame.referrerPolicy='strict-origin-when-cross-origin';
 frame.style.cssText='width:100%;min-height:280px;aspect-ratio:16/9;border:0;border-radius:10px;background:#101a33';
 viewer.append(frame);
 const links=node('div');links.className='ios-row';
 const official=node('a','Open on YouTube');official.href='https://www.youtube.com/watch?v='+encodeURIComponent(id);official.target='_blank';official.rel='noopener noreferrer';links.append(official);
 links.append(makeButton('Save video',()=>{const ids=saved();if(!ids.includes(id))ids.unshift(id);persist(ids.slice(0,100));renderSaved();message.textContent='Saved this video in your browser.'}));
 viewer.append(links);
 message.textContent='Video loaded using official YouTube embed controls. If unavailable, open it on YouTube.';
}
function renderSaved(){
 const list=$('itamio-saved');if(!list)return;list.replaceChildren();
 for(const id of saved()){
  const li=node('li');li.append(makeButton('▶ '+id,()=>openVideo('https://www.youtube.com/watch?v='+id)),makeButton('Remove',()=>{persist(saved().filter(x=>x!==id));renderSaved()}));list.append(li)
 }
 if(!list.childNodes.length)list.append(node('li','No saved videos yet.'));
}
window.Itamio={mount,videoId};
})();
