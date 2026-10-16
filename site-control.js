/* Public storefront maintenance gate. Keep admin.html reachable so the owner can reopen the store. */
(async()=>{
  if(location.pathname.toLowerCase().endsWith('/admin.html')||location.pathname.toLowerCase().endsWith('admin.html')||location.pathname.toLowerCase().endsWith('test.html')) return;
  const URL='https://yrfjqpzqmhddlxbwmsgb.supabase.co';
  const KEY='sb_publishable_so1k3P8YeQNeydSvFF9PpQ_vscf0rz9';
  try {
    if(!window.supabase?.createClient) return;
    const client=window.supabase.createClient(URL,KEY);
    const {data,error}=await client.from('site_settings').select('site_open,maintenance_message').eq('id',1).maybeSingle();
    if(error||!data||data.site_open) return;
    const overlay=document.createElement('div');
    overlay.id='bhavdrop-maintenance-gate';
    Object.assign(overlay.style,{position:'fixed',inset:'0',zIndex:'2147483000',background:'#08090b',color:'#f4efe6',display:'grid',placeItems:'center',padding:'28px',textAlign:'center',fontFamily:'system-ui,sans-serif'});
    const card=document.createElement('div');Object.assign(card.style,{maxWidth:'600px',width:'100%',border:'1px solid #39352b',padding:'40px 26px',background:'#101114'});
    const brand=document.createElement('div');brand.textContent='BHAVDROP';Object.assign(brand.style,{fontSize:'12px',letterSpacing:'.35em',color:'#f5c451',fontWeight:'700'});
    const title=document.createElement('h1');title.textContent='We’ll be back soon';Object.assign(title.style,{fontSize:'clamp(28px,5vw,46px)',margin:'20px 0 12px',fontWeight:'600'});
    const msg=document.createElement('p');msg.textContent=data.maintenance_message||'We are making the store better. Please check back soon.';Object.assign(msg.style,{color:'#b7b3ab',lineHeight:'1.7',fontSize:'14px'});
    card.append(brand,title,msg);overlay.append(card);document.body.append(overlay);
  } catch(e) { console.warn('BhavDrop site control could not be loaded:',e); }
})();
