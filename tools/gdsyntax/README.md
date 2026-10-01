# Optional grammar-only check

This is a local Lark harness using the gdtoolkit GDScript grammar and indenter
(MIT, copyright Pawel Lampe). The grammar and indenter were transcribed/adapted
from the primary repository text retrieved on 2026-10-01 because this working
container could not resolve package/binary download hosts.

Source:
- https://github.com/Scony/godot-gdscript-toolkit/blob/master/gdtoolkit/parser/gdscript.lark
- https://github.com/Scony/godot-gdscript-toolkit/blob/master/gdtoolkit/parser/gdscript_indenter.py

Python dependencies: `lark`, `regex` (already available in the working container).
Run from the project root: `python3 tools/gdsyntax/check.py .`

This checks grammar, NOT the Godot parser, engine type inference, runtime,
rendering, touch input or Android performance. Passing here does not prove that
the project runs in Godot. The GDScript smoke tests must still be run in Godot.
