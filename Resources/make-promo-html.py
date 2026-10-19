#!/opt/homebrew/bin/python3
"""把 docs/promo-longform.md 渲染成同目录的图文 HTML（供阅读/截图用）。

正文刻意保持纯文本（无 Markdown 语法），这样复制到 X 不会带 ** 和 ##。
本脚本只做最小解析：章节标题、图片、图注、链路图、配图清单表、thread 编号。
"""
import html
import pathlib
import re

HERE = pathlib.Path(__file__).resolve().parent.parent / "docs"
md_path = HERE / "promo-longform.md"

md = pathlib.Path(md_path).read_text()
lines = md.split("\n")

body = []
i = 0
while i < len(lines):
    line = lines[i].strip()

    if not line:
        i += 1
        continue

    m = re.match(r'^!\[\]\(([^)]+)\)$', line)
    if m:
        body.append(f'<figure><img src="{m.group(1)}" alt=""></figure>')
        i += 1
        continue

    if line.startswith("〔图"):
        body.append(f'<p class="cap">{html.escape(line)}</p>')
        i += 1
        continue

    if set(line) <= set("─-— ") and len(line) > 8:
        body.append("<hr>")
        i += 1
        continue

    if re.match(r'^[一二三四五六七八九十]+、', line) or line.startswith("附："):
        body.append(f"<h2>{html.escape(line)}</h2>")
        i += 1
        continue

    if i == 0:
        body.append(f"<h1>{html.escape(line)}</h1>")
        i += 1
        continue

    if line.startswith("（") and line.endswith("）"):
        body.append(f'<p class="meta">{html.escape(line)}</p>')
        i += 1
        continue

    if re.match(r'^\d+/$', line):
        body.append(f'<div class="tnum">{line}</div>')
        i += 1
        continue

    if "├" in line or "└" in line or line.startswith("系统音频 →"):
        block = []
        while i < len(lines) and lines[i].strip():
            block.append(lines[i].rstrip())
            i += 1
        body.append('<pre class="flow">' + html.escape("\n".join(block)) + "</pre>")
        continue

    if line.startswith("编号") and "文件" in line:
        rows = []
        i += 1
        while i < len(lines) and lines[i].strip():
            rows.append(lines[i].strip())
            i += 1
        t = ("<table><thead><tr><th>编号</th><th>文件</th><th>位置</th><th>内容</th>"
             "</tr></thead><tbody>")
        for r in rows:
            cols = re.split(r"\s{2,}", r)
            if len(cols) >= 4:
                t += "<tr>" + "".join(f"<td>{html.escape(c)}</td>" for c in cols[:4]) + "</tr>"
        t += "</tbody></table>"
        body.append(t)
        continue

    body.append(f"<p>{html.escape(line)}</p>")
    i += 1

TEMPLATE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>两只喇叭一起响，原本是个坏主意</title>
<style>
  :root {{
    --ink: #17171c; --sub: #6b6b78; --line: #e8e8ee;
    --accent: #6a4be8; --bg: #ffffff;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; background: var(--bg); color: var(--ink);
    font-family: -apple-system, "PingFang SC", "Helvetica Neue", sans-serif;
    -webkit-font-smoothing: antialiased;
  }}
  article {{ max-width: 720px; margin: 0 auto; padding: 72px 28px 120px; }}
  h1 {{ font-size: 34px; line-height: 1.35; letter-spacing: -0.4px; margin: 0 0 12px; font-weight: 700; }}
  .meta {{
    color: var(--sub); font-size: 14px; line-height: 1.7; margin: 0 0 40px;
    padding-bottom: 28px; border-bottom: 1px solid var(--line);
  }}
  h2 {{
    font-size: 21px; margin: 56px 0 20px; padding-left: 14px;
    border-left: 3px solid var(--accent); line-height: 1.4; font-weight: 650;
  }}
  p {{ font-size: 17px; line-height: 1.9; margin: 0 0 20px; letter-spacing: 0.1px; }}
  figure {{ margin: 32px 0 10px; }}
  img {{
    width: 100%; display: block; border-radius: 12px; border: 1px solid var(--line);
    box-shadow: 0 6px 24px rgba(20, 20, 40, 0.07);
  }}
  .cap {{
    font-size: 13px; color: var(--sub); margin: 0 0 10px;
    font-family: ui-monospace, Menlo, monospace;
  }}
  pre.flow {{
    background: #f7f7fa; border: 1px solid var(--line); border-radius: 10px;
    padding: 18px 20px; font-size: 13px; line-height: 1.8; overflow-x: auto;
    font-family: ui-monospace, Menlo, monospace; color: #33333d;
  }}
  hr {{ border: 0; border-top: 1px solid var(--line); margin: 56px 0 8px; }}
  .tnum {{ font-size: 15px; font-weight: 700; color: var(--accent); margin: 32px 0 8px; }}
  table {{ width: 100%; border-collapse: collapse; font-size: 14px; margin: 24px 0; }}
  th, td {{ text-align: left; padding: 10px 12px; border-bottom: 1px solid var(--line); vertical-align: top; }}
  th {{ color: var(--sub); font-weight: 600; font-size: 13px; }}
  td:nth-child(2) {{ font-family: ui-monospace, Menlo, monospace; font-size: 12.5px; }}
  @media (prefers-color-scheme: dark) {{
    :root {{ --ink: #ececf2; --sub: #9a9aa8; --line: #2a2a34; --bg: #12121a; }}
    pre.flow {{ background: #1a1a24; color: #d8d8e2; }}
    img {{ box-shadow: 0 6px 24px rgba(0, 0, 0, 0.5); }}
  }}
</style>
</head>
<body>
<article>
{content}
</article>
</body>
</html>
"""

out = HERE / "promo-longform.html"
out.write_text(TEMPLATE.format(content="\n".join(body)))
print(f"written {out}  ({len(body)} blocks)")
