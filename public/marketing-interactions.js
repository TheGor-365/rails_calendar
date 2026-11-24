document.addEventListener("click", event => {
  const closer = event.target.closest("[data-mk-close]");
  if (closer) document.getElementById(closer.dataset.mkClose)?.close();
  const trigger = event.target.closest("[data-mk-open]");
  if (trigger) {
    const dialog = document.getElementById(trigger.dataset.mkOpen);
    if (dialog instanceof HTMLDialogElement && !dialog.open) dialog.showModal();
  }
  const link = event.target.closest('a[href^="#"]');
  if (!link) return;
  const target = document.getElementById(link.hash.slice(1));
  if (target instanceof HTMLDetailsElement) target.open = true;
  if (!target || target instanceof HTMLDialogElement) return;
  document.querySelectorAll(".mk-sidebar-nav a").forEach(item => {
    const current = item.hash === link.hash;
    item.classList.toggle("is-current", current);
    if (current) item.setAttribute("aria-current", "location");
    else item.removeAttribute("aria-current");
  });
});
