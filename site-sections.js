/* Renders owner-managed promotional sections on the homepage. */
(async()=>{
  const mount=document.getElementById('managed-sections');if(!mount||!window.supabase?.createClient)return;
  const db=window.supabase.createClient('https://yrfjqpzqmhddlxbwmsgb.supabase.co','sb_publishable_so1k3P8YeQNeydSvFF9PpQ_vscf0rz9');
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const {data,error}=await db.from('site_sections').select('*').eq('is_active',true).order('sort_order',{ascending:true});if(error||!data?.length)return;
  mount.replaceChildren();
  data.forEach(s=>{
    const section=document.createElement('section');section.className='my-8 sm:my-12 border border-stone-200 bg-[#f7f5f0] text-stone-900';
    const inner=document.createElement('div');inner.className='grid md:grid-cols-2';
    const copy=document.createElement('div');copy.className='p-6 sm:p-10 flex flex-col justify-center items-start';
    if(s.eyebrow){const eye=document.createElement('p');eye.className='text-[10px] uppercase tracking-[.25em] text-stone-500';eye.textContent=s.eyebrow;copy.append(eye);}
    const h=document.createElement('h2');h.className='text-2xl sm:text-4xl mt-3 font-semibold';h.textContent=s.title;copy.append(h);
    if(s.body){const p=document.createElement('p');p.className='text-sm leading-7 mt-4 text-stone-600 whitespace-pre-line';p.textContent=s.body;copy.append(p);}
    if(s.button_label&&s.button_url){const a=document.createElement('a');a.className='mt-6 inline-block bg-black text-white px-5 py-3 text-xs uppercase tracking-wider';a.textContent=s.button_label;a.href=s.button_url;copy.append(a);}
    inner.append(copy);if(s.image_url){const img=document.createElement('img');img.src=s.image_url;img.alt=s.title;img.loading='lazy';img.className='w-full h-full min-h-56 max-h-[440px] object-cover';inner.append(img);}section.append(inner);mount.append(section);
  });
})();
