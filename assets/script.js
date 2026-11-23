/* 交互：入场淡入 / 导航高亮 / 阅读进度 / 图片灯箱 / 复制邮箱
   无第三方依赖，全部尊重 prefers-reduced-motion。 */
(function () {
  "use strict";

  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- 1. 入场：淡入 + 上浮 14px ---------- */
  var items = document.querySelectorAll("[data-reveal]");
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

  /* ---------- 2. 导航高亮 + 阅读进度 ---------- */
  var links = Array.prototype.slice.call(document.querySelectorAll('.nav__links a[href^="#"]'));
  var targets = links.map(function (a) { return document.querySelector(a.getAttribute("href")); }).filter(Boolean);
  var bar = document.querySelector(".progress span");
  var ticking = false;

  function update() {
    var y = window.scrollY || window.pageYOffset;

    if (targets.length) {
      var line = y + 120;
      var current = null;
      targets.forEach(function (sec) { if (sec.offsetTop <= line) current = sec; });
      links.forEach(function (a) {
        var on = current && a.getAttribute("href") === "#" + current.id;
        a.classList.toggle("is-active", !!on);
        if (on) { a.setAttribute("aria-current", "true"); }
        else { a.removeAttribute("aria-current"); }
      });
    }

    if (bar) {
      var max = document.documentElement.scrollHeight - window.innerHeight;
      var pct = max > 0 ? Math.min(100, Math.max(0, (y / max) * 100)) : 0;
      bar.style.width = pct.toFixed(2) + "%";
    }

    ticking = false;
  }

  window.addEventListener("scroll", function () {
    if (!ticking) { ticking = true; window.requestAnimationFrame(update); }
  }, { passive: true });
  window.addEventListener("resize", update, { passive: true });
  update();

  /* ---------- 3. 图片灯箱 ---------- */
  var box = document.getElementById("lightbox");
  if (box) {
    var boxImg = box.querySelector(".lightbox__img");
    var closeBtn = box.querySelector(".lightbox__close");
    var lastFocus = null;

    function openLb(img) {
      lastFocus = img;
      boxImg.src = img.currentSrc || img.src;
      boxImg.alt = img.alt || "";
      box.hidden = false;
      document.body.classList.add("is-locked");
      closeBtn.focus({ preventScroll: true });
    }

    function closeLb() {
      box.hidden = true;
      boxImg.removeAttribute("src");
      document.body.classList.remove("is-locked");
      if (lastFocus) { lastFocus.focus({ preventScroll: true }); }
    }

    document.querySelectorAll(".shot img").forEach(function (img) {
      img.addEventListener("click", function () { openLb(img); });
    });

    closeBtn.addEventListener("click", closeLb);
    box.addEventListener("click", function (e) { if (e.target === box) closeLb(); });
    document.addEventListener("keydown", function (e) {
      if (!box.hidden && (e.key === "Escape" || e.key === "Esc")) closeLb();
    });
  }

  /* ---------- 4. 复制邮箱 ---------- */
  var copyBtn = document.querySelector(".copy");
  if (copyBtn) {
    var label = copyBtn.querySelector(".copy__text");
    var original = label ? label.textContent : "";
    var timer = null;

    copyBtn.addEventListener("click", function () {
      var text = copyBtn.getAttribute("data-copy") || "";
      var done = function () {
        if (label) label.textContent = "已复制";
        copyBtn.classList.add("is-done");
        clearTimeout(timer);
        timer = setTimeout(function () {
          if (label) label.textContent = original;
          copyBtn.classList.remove("is-done");
        }, 1800);
      };

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done).catch(fallback);
      } else {
        fallback();
      }

      function fallback() {
        var ta = document.createElement("textarea");
        ta.value = text;
        ta.setAttribute("readonly", "");
        ta.style.position = "fixed";
        ta.style.top = "-1000px";
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand("copy"); done(); } catch (err) { /* 静默失败 */ }
        document.body.removeChild(ta);
      }
    });
  }
})();
