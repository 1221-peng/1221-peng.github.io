# 彭佳艺 · 个人简历网站

一个手写的单页简历网站，重点展示 2026 年 10–11 月的三个 AI 产品实践项目。

- 纯 HTML / CSS / 原生 JavaScript，无构建步骤、无第三方依赖
- 响应式：1440 / 1024 / 834 / 390 均实测通过
- 配色只用「蓝 + 黑灰 + 浅灰白」，留白优先
- 动效只有入场淡入与导航高亮，尊重 `prefers-reduced-motion`

## 目录

```
index.html          页面结构
assets/styles.css   样式（设计变量集中在 :root）
assets/script.js    入场动画 + 导航高亮
assets/portrait.jpg 证件照（4:5，760×950，70 KB）
assets/favicon.svg  站点图标
```

## 本地预览

```bash
python -m http.server 8765
# 打开 http://127.0.0.1:8765/
```

## 部署

本站发布在 GitHub Pages：

- 仓库：`1221-peng/1221-peng.github.io`
- 访问：https://1221-peng.github.io/
- 分支 `main` 的根目录即站点根目录，推送后自动构建

## 内容说明

项目里的数字均来自真实产物或云端记录（PRD 版本、验收标准条数、云函数检查记录、截图数量等）。
无法核实的结果没有写；未完成的部分在项目末尾以「说明」标注，例如短片未合成成片、小程序未对外发布。

联系方式：pengjiayi2929@163.com
