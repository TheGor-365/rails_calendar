document.addEventListener("click", event => {
  const closer = event.target.closest("[data-mk-close]");
  if (closer) closeMarketingDialog(document.getElementById(closer.dataset.mkClose));
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

function closeMarketingDialog(dialog) {
  if (!dialog?.open || dialog.classList.contains("mk-closing")) return;
  if (matchMedia("(prefers-reduced-motion: reduce)").matches) { dialog.close(); return; }
  dialog.classList.add("mk-closing");
  const finish = () => {
    dialog.classList.remove("mk-closing");
    if (dialog.open) dialog.close();
  };
  dialog.addEventListener("animationend", finish, { once:true });
  setTimeout(finish, 220);
}
document.querySelectorAll(".mk-process-dialog").forEach(dialog => {
  dialog.addEventListener("cancel", event => {
    event.preventDefault(); closeMarketingDialog(dialog);
  });
});
