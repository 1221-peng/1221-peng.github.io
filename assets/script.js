/* 极简交互：入场上浮 + 导航高亮。无第三方依赖。 */
(function () {
  "use strict";

  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var items = document.querySelectorAll("[data-reveal]");

  /* 1. 入场：淡入 + 上浮 14px */
  if (reduce || !("IntersectionObserver" in window)) {
    items.forEach(function (el) { el.classList.add("is-in"); });
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-in");
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -6% 0px" });

    items.forEach(function (el) { io.observe(el); });
  }

  /* 2. 导航高亮：当前视口所在的区块 */
  var links = Array.prototype.slice.call(document.querySelectorAll('.nav__links a[href^="#"]'));
  var targets = links.map(function (a) {
    return document.querySelector(a.getAttribute("href"));
  }).filter(Boolean);

  if (targets.length) {
    var ticking = false;

    function update() {
      var line = (window.scrollY || window.pageYOffset) + 120;
      var current = null;
      targets.forEach(function (sec) {
        if (sec.offsetTop <= line) current = sec;
      });
      links.forEach(function (a) {
        var on = current && a.getAttribute("href") === "#" + current.id;
        a.classList.toggle("is-active", !!on);
        if (on) { a.setAttribute("aria-current", "true"); }
        else { a.removeAttribute("aria-current"); }
      });
      ticking = false;
    }

    window.addEventListener("scroll", function () {
      if (!ticking) {
        ticking = true;
        window.requestAnimationFrame(update);
      }
    }, { passive: true });

    update();
  }
})();
