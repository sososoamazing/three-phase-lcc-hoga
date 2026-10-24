#!/usr/bin/env python3
"""Build the static GitHub Pages site from the Markdown sources.

No external dependencies.  Renders ONE_PAGE.md to index.html and every other
Markdown file to a sibling .html page, rewriting relative .md links.
"""
from __future__ import annotations

import html
import re
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SITE_TITLE = "三相 LCC HOGA 建模资料库"
SITE_DESC = (
    "50 V → 800 V 三相 Δ/Y LCC 谐振电容充电电源的 HOGA 建模、"
    "20 点模型对比、344 点归一化扫描与 AOC 充电轨迹验证。"
)
REPO_URL = "https://github.com/sososoamazing/three-phase-lcc-hoga"
PAGES_URL = "https://sososoamazing.github.io/three-phase-lcc-hoga/"


# ---------------------------------------------------------------------------
# Markdown rendering (small, dependency-free subset)
# ---------------------------------------------------------------------------

def esc(text: str) -> str:
    return html.escape(text, quote=False)


def slugify(text: str, used: dict[str, int]) -> str:
    base = re.sub(r"[^\w\u4e00-\u9fff]+", "-", text.strip().lower()).strip("-")
    base = base or "section"
    n = used.get(base, 0)
    used[base] = n + 1
    return base if n == 0 else f"{base}-{n + 1}"


def inline(text: str) -> str:
    # Protect inline code first.
    codes: list[str] = []

    def stash(m: re.Match) -> str:
        codes.append(esc(m.group(1)))
        return f"\x00CODE{len(codes) - 1}\x00"

    text = re.sub(r"`([^`]+)`", stash, text)
    text = esc(text)
    # Images before links.
    text = re.sub(
        r"!\[([^\]]*)\]\(([^)\s]+)\)",
        lambda m: f'<img src="{m.group(2)}" alt="{m.group(1)}" loading="lazy">',
        text,
    )
    text = re.sub(
        r"\[([^\]]+)\]\(([^)\s]+)\)",
        lambda m: f'<a href="{m.group(2)}">{m.group(1)}</a>',
        text,
    )
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<!\*)\*([^*\n]+)\*(?!\*)", r"<em>\1</em>", text)
    for i, code in enumerate(codes):
        text = text.replace(f"\x00CODE{i}\x00", f"<code>{code}</code>")
    return text


def is_cjk(ch: str) -> bool:
    return bool(ch) and ("\u4e00" <= ch <= "\u9fff")


def join_paragraph(lines: list[str]) -> str:
    out = ""
    for raw in lines:
        line = raw.rstrip()
        hard_break = raw.endswith("  ")
        if not out:
            out = line
        elif hard_break:
            out = out.rstrip() + "\x00BR\x00" + line
        elif is_cjk(out[-1]) or is_cjk(line[:1] if line else ""):
            out += line
        else:
            out += " " + line
    return out


def split_row(line: str) -> list[str]:
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [c.strip() for c in line.split("|")]


def is_sep_row(cells: list[str]) -> bool:
    return all(re.fullmatch(r":?-{2,}:?", c) for c in cells) and bool(cells)


def render_markdown(md: str) -> tuple[str, list[tuple[int, str, str]]]:
    lines = md.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out: list[str] = []
    toc: list[tuple[int, str, str]] = []
    used: dict[str, int] = {}
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Fenced code.
        if stripped.startswith("```"):
            lang = stripped[3:].strip() or "text"
            i += 1
            buf: list[str] = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                buf.append(lines[i])
                i += 1
            i += 1
            out.append(
                f'<pre class="code"><code class="language-{esc(lang)}">'
                + esc("\n".join(buf))
                + "</code></pre>"
            )
            continue

        # Blank.
        if not stripped:
            i += 1
            continue

        # Heading.
        m = re.match(r"^(#{1,6})\s+(.*)$", stripped)
        if m:
            level = len(m.group(1))
            text = m.group(2).strip()
            sid = slugify(text, used)
            if level in (2, 3):
                toc.append((level, sid, text))
            out.append(f'<h{level} id="{sid}">{inline(text)}</h{level}>')
            i += 1
            continue

        # Horizontal rule.
        if re.fullmatch(r"-{3,}|\*{3,}|_{3,}", stripped):
            out.append("<hr>")
            i += 1
            continue

        # Table.
        if "|" in stripped and i + 1 < len(lines):
            head = split_row(stripped)
            sep = split_row(lines[i + 1]) if "|" in lines[i + 1] else []
            if head and is_sep_row(sep):
                aligns = []
                for c in sep:
                    if c.startswith(":") and c.endswith(":"):
                        aligns.append("center")
                    elif c.endswith(":"):
                        aligns.append("right")
                    else:
                        aligns.append("left")
                out.append('<div class="table-wrap"><table>')
                out.append("<thead><tr>")
                for j, c in enumerate(head):
                    a = aligns[j] if j < len(aligns) else "left"
                    out.append(f'<th class="align-{a}">{inline(c)}</th>')
                out.append("</tr></thead><tbody>")
                i += 2
                while i < len(lines) and "|" in lines[i] and lines[i].strip():
                    cells = split_row(lines[i])
                    out.append("<tr>")
                    for j in range(len(head)):
                        c = cells[j] if j < len(cells) else ""
                        a = aligns[j] if j < len(aligns) else "left"
                        out.append(f'<td class="align-{a}">{inline(c)}</td>')
                    out.append("</tr>")
                    i += 1
                out.append("</tbody></table></div>")
                continue

        # Blockquote.
        if stripped.startswith(">"):
            buf = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                buf.append(re.sub(r"^\s*>\s?", "", lines[i]))
                i += 1
            out.append("<blockquote>" + inline(join_paragraph(buf)).replace("\x00BR\x00", "<br>") + "</blockquote>")
            continue

        # Lists.
        lm = re.match(r"^\s*([-*+]|\d+\.)\s+(.*)$", line)
        if lm:
            ordered = lm.group(1)[0].isdigit()
            tag = "ol" if ordered else "ul"
            out.append(f"<{tag}>")
            while i < len(lines):
                m2 = re.match(r"^\s*([-*+]|\d+\.)\s+(.*)$", lines[i])
                if not m2:
                    break
                out.append(f"<li>{inline(m2.group(2).strip())}</li>")
                i += 1
            out.append(f"</{tag}>")
            continue

        # Paragraph.
        buf = [line]
        i += 1
        while i < len(lines) and lines[i].strip():
            nxt = lines[i].strip()
            if (
                nxt.startswith("#")
                or nxt.startswith("```")
                or nxt.startswith(">")
                or re.match(r"^\s*([-*+]|\d+\.)\s+", lines[i])
                or re.fullmatch(r"-{3,}", nxt)
                or ("|" in nxt and i + 1 < len(lines) and is_sep_row(split_row(lines[i + 1])))
            ):
                break
            buf.append(lines[i])
            i += 1
        out.append("<p>" + inline(join_paragraph(buf)).replace("\x00BR\x00", "<br>") + "</p>")

    return "\n".join(out), toc


def rewrite_links(html_text: str) -> str:
    def repl(m: re.Match) -> str:
        url = m.group(1)
        if url.startswith(("http://", "https://", "mailto:", "#")):
            return m.group(0)
        url = re.sub(r"\.md(?=#|$)", ".html", url)
        return f'href="{url}"'

    return re.sub(r'href="([^"]+)"', repl, html_text)


# ---------------------------------------------------------------------------
# Page template
# ---------------------------------------------------------------------------

CSS = """\
:root{
  --bg:#f6f7f9; --panel:#ffffff; --text:#1f2328; --muted:#5b6570;
  --line:#d8dee4; --accent:#0b5fff; --accent2:#0a7d4f; --warn:#9a6700;
  --code:#f3f4f6; --max:1180px;
}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{
  margin:0; background:var(--bg); color:var(--text);
  font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","Microsoft YaHei",
    "PingFang SC","Hiragino Sans GB",Arial,sans-serif;
  line-height:1.75; font-size:16px;
}
a{color:var(--accent); text-decoration:none}
a:hover{text-decoration:underline}
.topbar{
  position:sticky; top:0; z-index:10; background:rgba(255,255,255,.94);
  border-bottom:1px solid var(--line); backdrop-filter:blur(8px);
}
.topbar-inner{
  max-width:var(--max); margin:0 auto; padding:.65rem 1.2rem;
  display:flex; align-items:center; gap:1rem; flex-wrap:wrap;
}
.brand{font-weight:700; color:var(--text); letter-spacing:.2px}
.brand span{color:var(--accent2)}
.nav{display:flex; gap:.9rem; flex-wrap:wrap; font-size:.92rem}
.nav a{color:var(--muted)}
.nav a:hover{color:var(--accent)}
.hero{
  background:linear-gradient(135deg,#0b2a5b 0%,#0b5fff 55%,#0a7d4f 100%);
  color:#fff; padding:3.2rem 1.2rem 2.8rem;
}
.hero-inner{max-width:var(--max); margin:0 auto}
.hero .kicker{font-size:.82rem; letter-spacing:.16em; text-transform:uppercase; opacity:.8}
.hero h1{font-size:clamp(1.7rem,3.6vw,2.8rem); line-height:1.25; margin:.45rem 0 .8rem}
.hero p{max-width:900px; margin:.35rem 0; color:#e8f0ff}
.hero .links{display:flex; gap:.8rem; flex-wrap:wrap; margin-top:1.2rem}
.hero .links a{
  background:rgba(255,255,255,.14); color:#fff; border:1px solid rgba(255,255,255,.35);
  padding:.45rem .85rem; border-radius:.5rem; font-size:.92rem;
}
.hero .links a:hover{background:rgba(255,255,255,.24); text-decoration:none}
.layout{
  max-width:var(--max); margin:0 auto; padding:1.6rem 1.2rem 3rem;
  display:grid; grid-template-columns:250px minmax(0,1fr); gap:2rem;
}
.toc{
  position:sticky; top:4.4rem; align-self:start; max-height:calc(100vh - 5.4rem);
  overflow:auto; font-size:.88rem; padding-right:.4rem;
}
.toc h3{font-size:.78rem; letter-spacing:.12em; text-transform:uppercase; color:var(--muted); margin:.2rem 0 .6rem}
.toc a{display:block; color:var(--muted); padding:.18rem 0; border-left:2px solid transparent; padding-left:.6rem}
.toc a:hover{color:var(--accent); border-left-color:var(--accent); text-decoration:none}
.toc a.lvl3{padding-left:1.25rem; font-size:.84rem}
.content{
  background:var(--panel); border:1px solid var(--line); border-radius:.9rem;
  padding:2rem clamp(1rem,3vw,2.6rem); min-width:0;
  box-shadow:0 1px 2px rgba(0,0,0,.03);
}
.content h1,.content h2,.content h3,.content h4{line-height:1.35; scroll-margin-top:5rem}
.content h1{font-size:1.7rem; margin:0 0 1rem}
.content h2{font-size:1.3rem; margin:2.2rem 0 .8rem; padding-bottom:.35rem; border-bottom:1px solid var(--line)}
.content h3{font-size:1.1rem; margin:1.6rem 0 .55rem}
.content h4{font-size:1rem; margin:1.2rem 0 .45rem}
.content p{margin:.7rem 0}
.content ul,.content ol{padding-left:1.4rem; margin:.6rem 0}
.content li{margin:.25rem 0}
blockquote{
  margin:1rem 0; padding:.7rem 1rem; border-left:4px solid var(--accent2);
  background:#f2fbf6; color:#243b30; border-radius:0 .4rem .4rem 0;
}
blockquote p{margin:.2rem 0}
code{
  font-family:ui-monospace,SFMono-Regular,Consolas,"Liberation Mono",monospace;
  background:var(--code); padding:.1rem .3rem; border-radius:.25rem; font-size:.9em;
}
pre.code{
  background:#0f172a; color:#e5edf7; padding:1rem 1.1rem; border-radius:.6rem;
  overflow:auto; font-size:.86rem; line-height:1.55; margin:1rem 0;
}
pre.code code{background:transparent; padding:0; color:inherit; font-size:1em}
.table-wrap{overflow-x:auto; margin:1rem 0}
table{border-collapse:collapse; width:100%; font-size:.9rem}
th,td{border:1px solid var(--line); padding:.45rem .6rem; vertical-align:top}
th{background:#f1f4f8; font-weight:600; white-space:nowrap}
tbody tr:nth-child(even){background:#fafbfc}
.align-center{text-align:center}
.align-right{text-align:right}
img{max-width:100%; height:auto; border:1px solid var(--line); border-radius:.45rem; margin:.6rem 0; background:#fff}
hr{border:0; border-top:1px solid var(--line); margin:1.8rem 0}
.footer{
  max-width:var(--max); margin:0 auto; padding:0 1.2rem 3rem; color:var(--muted);
  font-size:.86rem;
}
.footer a{color:var(--muted)}
.badge{
  display:inline-block; font-size:.76rem; padding:.12rem .5rem; border-radius:1rem;
  background:#eef3ff; color:#0b4bd1; border:1px solid #cfe0ff; margin-right:.35rem;
}
.note{
  background:#fff8e6; border:1px solid #f0d48a; border-radius:.6rem;
  padding:.8rem 1rem; margin:1rem 0; color:#5c4500; font-size:.92rem;
}
@media (max-width: 900px){
  .layout{grid-template-columns:1fr; padding-top:1rem}
  .toc{position:static; max-height:none; order:-1; border-bottom:1px solid var(--line); padding-bottom:.8rem}
  .content{padding:1.2rem}
  .hero{padding:2.2rem 1rem 1.8rem}
}
@media print{
  .topbar,.toc,.hero .links,.footer{display:none}
  .layout{display:block; max-width:none}
  .content{border:0; box-shadow:none; padding:0}
  body{background:#fff}
}
"""


def page_html(title: str, body: str, base: str, toc: list[tuple[int, str, str]], hero: bool) -> str:
    nav = f"""\
<header class="topbar"><div class="topbar-inner">
  <a class="brand" href="{base}index.html">LCC<span>·</span>HOGA</a>
  <nav class="nav">
    <a href="{base}index.html">总览</a>
    <a href="{base}docs/00_项目梳理总览.html">项目梳理</a>
    <a href="{base}docs/02_论文精读_HOGA方法.html">论文</a>
    <a href="{base}docs/04_模型对比结果.html">结果</a>
    <a href="{base}docs/05_归一化特性扫描.html">扫描</a>
    <a href="{base}docs/06_充电轨迹_AOC.html">AOC</a>
    <a href="{base}docs/07_局限与证据等级.html">边界</a>
    <a href="{base}data/README.html">数据</a>
    <a href="{REPO_URL}">GitHub</a>
  </nav>
</div></header>"""
    if hero:
        hero_html = f"""\
<section class="hero"><div class="hero-inner">
  <div class="kicker">50 V → 800 V · Three-Phase Δ/Y LCC · HOGA</div>
  <h1>三相 LCC 电容充电电源<br>HOGA 建模资料库</h1>
  <p>事件增强高阶广义平均（HOGA）的公开归档：论文、方法、实现、20 点模型对比、344 点归一化扫描、AOC 0→800 V 充电轨迹验证。</p>
  <p><span class="badge">HOGA Io MAE 15.579 μA</span><span class="badge">波形 NRMSE 0.0566%</span><span class="badge">344 点扫描</span><span class="badge">无硬件实验</span></p>
  <div class="links">
    <a href="{base}docs/00_项目梳理总览.html">项目梳理总览</a>
    <a href="{base}docs/02_论文精读_HOGA方法.html">论文精读</a>
    <a href="{base}docs/04_模型对比结果.html">20 点结果</a>
    <a href="{base}docs/09_GPT阅读指南.html">给 GPT 的读法</a>
    <a href="{base}paper/HOGA_TPEL2024_Li_Wang_Fang_Chen_Yang.pdf">论文 PDF</a>
  </div>
</div></section>"""
        layout_start = '<main class="layout">'
        toc_html = '<aside class="toc"><h3>本页目录</h3>'
        for level, sid, text in toc:
            cls = "lvl3" if level == 3 else "lvl2"
            toc_html += f'<a class="{cls}" href="#{sid}">{esc(text)}</a>'
        toc_html += "</aside>"
        layout_end = "</main>"
    else:
        hero_html = ""
        layout_start = '<main class="layout">'
        toc_html = '<aside class="toc"><h3>本页目录</h3>'
        for level, sid, text in toc:
            cls = "lvl3" if level == 3 else "lvl2"
            toc_html += f'<a class="{cls}" href="#{sid}">{esc(text)}</a>'
        toc_html += "</aside>"
        layout_end = "</main>"
    return f"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)} · {SITE_TITLE}</title>
<meta name="description" content="{esc(SITE_DESC)}">
<link rel="stylesheet" href="{base}assets/style.css">
<link rel="alternate" type="text/markdown" href="{base}ONE_PAGE.md">
<script>
window.MathJax = {{
  tex: {{ inlineMath: [['$','$'],['\\(','\\)']], displayMath: [['$$','$$'],['\\[','\\]']] }},
  svg: {{ fontCache: 'global' }}
}};
</script>
<script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
</head>
<body>
{nav}
{hero_html}
{layout_start}
{toc_html}
<article class="content">
{body}
</article>
{layout_end}
<footer class="footer">
  <p>公开归档 · 代码 MIT · 原创文档 CC BY 4.0 · 论文 PDF CC BY-NC-ND 4.0 ·
  <a href="{REPO_URL}">GitHub</a> ·
  <a href="{PAGES_URL}">Pages</a></p>
  <p>最后构建：{date.today().isoformat()}。本页由 <code>tools/build_site.py</code> 从 Markdown 生成；如与源文件冲突，以源文件为准。</p>
</footer>
</body>
</html>
"""


def main() -> None:
    pages: list[tuple[Path, Path]] = []
    # Root pages.
    pages.append((ROOT / "ONE_PAGE.md", ROOT / "ONE_PAGE.html"))
    pages.append((ROOT / "ONE_PAGE.md", ROOT / "index.html"))
    pages.append((ROOT / "README.md", ROOT / "README.html"))
    pages.append((ROOT / "LICENSE_DOCS.md", ROOT / "LICENSE_DOCS.html"))
    # All other Markdown pages (docs, reports, sub-READMEs).
    for path in sorted(ROOT.rglob("*.md")):
        rel = path.relative_to(ROOT)
        if rel.as_posix() in {"ONE_PAGE.md", "README.md", "LICENSE_DOCS.md"}:
            continue
        if any(part.startswith(".") for part in rel.parts):
            continue
        pages.append((path, path.with_suffix(".html")))

    built = 0
    for src, dst in pages:
        md = src.read_text(encoding="utf-8")
        body, toc = render_markdown(md)
        body = rewrite_links(body)
        # Title from first H1, else stem.
        m = re.search(r"^#\s+(.+)$", md, flags=re.M)
        title = m.group(1).strip() if m else src.stem
        base = "../" * len(dst.parent.relative_to(ROOT).parts)
        hero = dst.name == "index.html"
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(page_html(title, body, base, toc, hero), encoding="utf-8")
        built += 1
        print(f"built {dst.relative_to(ROOT)}")

    (ROOT / "assets" / "style.css").write_text(CSS, encoding="utf-8")
    (ROOT / ".nojekyll").write_text("", encoding="utf-8")
    print(f"\nDone: {built} pages, assets/style.css, .nojekyll")


if __name__ == "__main__":
    main()
