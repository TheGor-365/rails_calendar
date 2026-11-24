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

function syncMarketingSection() {
  const links = [...document.querySelectorAll(".mk-sidebar-nav a[href^='#']")];
  const sections = links.map(link => document.getElementById(link.hash.slice(1)))
    .filter(section => section && !(section instanceof HTMLDialogElement));
  const line = 160;
  const active = sections.filter(section => section.getBoundingClientRect().top <= line).pop() || sections[0];
  if (!active) return;
  links.forEach(link => {
    const current = link.hash === "#" + active.id;
    link.classList.toggle("is-current", current);
    if (current) link.setAttribute("aria-current", "location");
    else link.removeAttribute("aria-current");
  });
}
let marketingScrollPending = false;
window.addEventListener("scroll", () => {
  if (marketingScrollPending) return;
  marketingScrollPending = true;
  requestAnimationFrame(() => {
    marketingScrollPending = false;
    syncMarketingSection();
  });
}, { passive: true });
window.addEventListener("hashchange", syncMarketingSection);
syncMarketingSection();
