(() => {
  'use strict';
  const path = location.pathname.split('/').pop();
  if (path === 'Dokains_Archive.html') {
    const root = document.querySelector('[data-archive-document]');
    if (!root) return;
    const observer = new MutationObserver(async () => {
      if (root.hidden || !root.querySelector('.record-hero')) return;
      observer.disconnect();
      try {
        const account = await TODMAuth.getAccount();
        if (!account.session) return;
        const { data, error } = await TODMAuth.client.from('archive_content').select('id').eq('slug', 'dokains-anatomy').maybeSingle();
        if (error || !data) return;
        await TODMAuth.client.from('content_reads').upsert({ user_id: account.user.id, content_id: data.id, last_opened_at: new Date().toISOString() }, { onConflict: 'user_id,content_id' });
      } catch (error) { console.warn('Document reading marker unavailable', error); }
    });
    observer.observe(root, { childList: true, subtree: true, attributes: true, attributeFilter: ['hidden'] });
    return;
  }
  if (!window.TODMDossiers?.publicDossiers.includes(path)) return;
  const mark = async () => {
    try {
      const session = await TODMAuth.getSession();
      if (!session) return;
      const { error } = await TODMAuth.client.rpc('archive_record_public_dossier', { p_path: path });
      if (error) console.warn('Dossier view could not be recorded', error);
    } catch (error) { console.warn('Dossier activity unavailable', error); }
  };
  if (window.TODMAuth) mark();
  else addEventListener('todm-auth-ready', mark, { once: true });
})();
