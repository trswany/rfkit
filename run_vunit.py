################################################################################
## SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
## SPDX-License-Identifier: MIT
################################################################################

from pathlib import Path
from vunit import VUnit

vu = VUnit.from_argv(compile_builtins=False)
vu.add_verilog_builtins()

# Look through the src/ directory and add any .sv files we find.
src_dir = Path(__file__).absolute().parent / "./src"
for path in Path(src_dir).iterdir():
  if path.is_dir():
    library_name = path.name
    library_pattern = path / "*.sv"
    vu.add_library(library_name).add_source_files(library_pattern)

vu.main()

