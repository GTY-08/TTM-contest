(async () => {
  const form = document.getElementById('supportForm');
  const message = document.getElementById('supportMessage');

  function setMessage(text, isError = false) {
    if (!message) return;
    message.textContent = text || '';
    message.className = `status-line${isError ? ' support-message error' : ''}`;
  }

  form?.addEventListener('submit', async (event) => {
      event.preventDefault();
      const values = new FormData(form);
      const submit = document.getElementById('supportSubmit');
      setMessage('문의 접수 중입니다.');
      if (submit) submit.disabled = true;
      try {
        const response = await fetch('/api/support-inquiry', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            email: `${values.get('email')}`.trim(),
            category: `${values.get('category')}`.trim(),
            subject: `${values.get('subject')}`.trim(),
            message: `${values.get('message')}`.trim(),
            website: `${values.get('website')}`.trim(),
          }),
        });
        const payload = await response.json().catch(() => ({}));
        if (!response.ok) {
          throw new Error(payload.reason || `support_submit_${response.status}`);
        }
        form.reset();
        setMessage(
          payload.emailSent
            ? '문의가 접수되었고 고객센터 메일로 전달되었습니다.'
            : '문의는 관리자 접수함에 저장되었지만 메일 알림은 전송되지 않았습니다.',
          !payload.emailSent,
        );
      } catch (error) {
        const raw = `${error?.message || ''}`.toLowerCase();
        const text = raw.includes('invalid_email')
          ? '이메일 주소를 확인해 주세요.'
          : raw.includes('invalid_args')
            ? '제목과 문의 내용을 조금 더 자세히 입력해 주세요.'
            : '문의 접수에 실패했습니다. 잠시 후 다시 시도하거나 support@ttmttm.com으로 알려 주세요.';
        setMessage(text, true);
      } finally {
        if (submit) submit.disabled = false;
      }
  });
})();
