(async () => {
  const list = document.getElementById('noticeList');
  const status = document.getElementById('noticeStatus');
  const adminPanel = document.getElementById('noticeAdmin');
  const form = document.getElementById('noticeForm');
  const adminMessage = document.getElementById('noticeAdminMessage');

  function setStatus(text) {
    if (status) status.textContent = text || '';
  }

  function setAdminMessage(text) {
    if (adminMessage) adminMessage.textContent = text || '';
  }

  function formatDate(value) {
    if (!value) return '공지';
    try {
      return new Intl.DateTimeFormat('ko-KR', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
      }).format(new Date(value));
    } catch {
      return '공지';
    }
  }

  function escapeHtml(value) {
    return `${value ?? ''}`
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }

  function renderNotices(items, canManage = false) {
    if (!list) return;
    if (!items?.length) {
      list.innerHTML = '<div class="notice-empty">아직 등록된 공지가 없습니다.</div>';
      return;
    }
    list.innerHTML = items.map((item) => {
      const body = escapeHtml(item.body || item.summary || '').replaceAll('\n', '<br>');
      const summary = item.summary ? `<p>${escapeHtml(item.summary)}</p>` : '';
      const deleteButton = canManage
        ? `<button class="notice-delete" type="button" data-notice-id="${escapeHtml(item.id)}">삭제</button>`
        : '';
      return `
        <article class="notice-card reveal on">
          <div class="notice-card-head">
            <div class="notice-meta">
              <time>${formatDate(item.published_at || item.created_at)}</time>
              ${item.status === 'draft' ? '<span class="chip">임시 저장</span>' : ''}
            </div>
            ${deleteButton}
          </div>
          <h3>${escapeHtml(item.title)}</h3>
          ${summary}
          <p>${body}</p>
        </article>
      `;
    }).join('');
  }

  async function loadConfig() {
    const response = await fetch('/api/auth-config', { headers: { Accept: 'application/json' } });
    const config = await response.json();
    if (!response.ok || !config.ok || !window.supabase?.createClient) {
      throw new Error('config_unavailable');
    }
    return window.supabase.createClient(config.supabaseUrl, config.publishableKey, {
      auth: { persistSession: true, detectSessionInUrl: true, autoRefreshToken: true },
    });
  }

  async function loadNotices(client, includeDrafts = false) {
    const { data, error } = await client.rpc('list_web_notices', {
      p_include_drafts: includeDrafts,
      p_limit: 30,
      p_offset: 0,
    });
    if (error) throw error;
    renderNotices(data?.items || [], includeDrafts);
  }

  try {
    const client = await loadConfig();
    await loadNotices(client, false);
    setStatus('');

    const { data: { session } } = await client.auth.getSession();
    if (session) {
      const { data: isAdmin } = await client.rpc('my_is_admin');
      if (isAdmin && adminPanel) {
        adminPanel.hidden = false;
        await loadNotices(client, true);
      }
    }

    form?.addEventListener('submit', async (event) => {
      event.preventDefault();
      setAdminMessage('등록 중입니다.');
      const values = new FormData(form);
      const submit = form.querySelector('button[type="submit"]');
      if (submit) submit.disabled = true;
      try {
        const { error } = await client.rpc('admin_upsert_web_notice', {
          p_title: `${values.get('title')}`.trim(),
          p_summary: `${values.get('summary')}`.trim(),
          p_body: `${values.get('body')}`.trim(),
          p_status: `${values.get('status')}`.trim() || 'published',
        });
        if (error) throw error;
        form.reset();
        setAdminMessage('공지 등록이 완료되었습니다.');
        await loadNotices(client, true);
      } catch (error) {
        setAdminMessage(`등록 실패: ${error?.message || '권한 또는 네트워크 오류'}`);
      } finally {
        if (submit) submit.disabled = false;
      }
    });

    list?.addEventListener('click', async (event) => {
      const button = event.target.closest('.notice-delete');
      if (!button || !list.contains(button)) return;

      const noticeId = button.dataset.noticeId;
      if (!noticeId || !window.confirm('이 공지를 삭제하시겠습니까? 삭제 후에는 복구할 수 없습니다.')) {
        return;
      }

      button.disabled = true;
      setAdminMessage('공지를 삭제하는 중입니다.');
      try {
        const { error } = await client.rpc('admin_delete_web_notice', {
          p_notice_id: noticeId,
        });
        if (error) throw error;
        setAdminMessage('공지를 삭제했습니다.');
        await loadNotices(client, true);
      } catch (error) {
        setAdminMessage(`삭제 실패: ${error?.message || '권한 또는 네트워크 오류'}`);
        button.disabled = false;
      }
    });
  } catch (_error) {
    renderNotices([]);
    setStatus('공지 시스템을 불러오지 못했습니다. 잠시 후 다시 확인해 주세요.');
  }
})();
