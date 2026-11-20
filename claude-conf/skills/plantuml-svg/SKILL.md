---
name: plantuml-svg
description: Render PlantUML diagrams kept in markdown files to SVG through the public PlantUML REST API (encoded GET with curl). Use whenever diagrams are requested or a markdown file with ```plantuml blocks is created or changed and its SVGs need (re)rendering.
---

# PlantUML diagrams in markdown → SVG

Diagrams live as ```` ```plantuml ```` fenced blocks inside a markdown file. Each block is
rendered to its own SVG next to the markdown (or wherever the project instructions say diagrams go).

## Writing the markdown

- One diagram per fenced block, starting with `@startuml <name>` and ending with `@enduml`.
  `<name>` becomes the SVG file name (`<name>.svg`), so keep it unique and file-safe.
- Reference the SVG from the markdown with `![title](<name>.svg)` under the block if wanted.

## Rendering

Run the bundled script:

```bash
python3 ~/.claude/skills/plantuml-svg/render_plantuml.py <file.md> [--out-dir DIR] [name ...]
```

- No names: renders every block. With names: only those blocks (use it after editing a
  subset of the diagrams).
- Default output dir is the markdown's directory.
- Prints `<name>: <path> (<bytes>) ok|FAILED|SYNTAX ERROR` per block and exits 1 on any problem.
  On `SYNTAX ERROR`, open the SVG (the error line is in it), fix the block and re-render.

## How it works (if doing it by hand)

1. Raw-deflate the diagram source (zlib with `wbits=-15`, no header).
2. Base64-encode, strip `=` padding, and remap the alphabet
   `A-Za-z0-9+/` → `0-9A-Za-z-_`.
3. `curl -s -f https://www.plantuml.com/plantuml/svg/<encoded> -o <name>.svg`
4. `grep -c "yntax error" <name>.svg` must be 0.

## Gotchas

- **Do not POST** the source to `https://www.plantuml.com/plantuml/svg`: the public server
  returns an empty body. Only the encoded GET form works.
- Very large diagrams can exceed URL length limits; split them into several blocks.
- Sending a diagram to the public server publishes its content; only render material that
  may leave the machine.
