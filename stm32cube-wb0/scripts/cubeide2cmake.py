#!/usr/bin/env python3
"""cubeide2cmake: write a CMakeLists.txt for an ST STM32CubeIDE project.

    cubeide2cmake.py WORK_DIR ORIGINAL_DIR NAME

WORK_DIR is a copy of a project folder that holds STM32CubeIDE/.project and
STM32CubeIDE/.cproject (as every example under $STM32CUBEWB0/Projects does).
ORIGINAL_DIR is where it was copied from. The Release configuration's sources,
include folders, defines, libraries and linker script are read from those two
files, the way STM32CubeIDE would build it, and written to WORK_DIR/CMakeLists.txt
as a stm32wb0_firmware(NAME RAW ...) call.

Paths that leave the project (../../../Drivers/..., PARENT-6-PROJECT_LOC/...)
point into the SDK. They are resolved against ORIGINAL_DIR when that is inside
$STM32CUBEWB0, and otherwise looked up under $STM32CUBEWB0, $STM32CUBEWB0/Projects,
$STM32CUBEWB0/Projects/NUCLEO-WB09KE and its sub-folders, so a copied example
builds too.
"""
from __future__ import annotations

import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

SDK = os.environ.get("STM32CUBEWB0", "/opt/st/STM32CubeWB0")
SRC_EXT = (".c", ".cpp", ".cc", ".cxx", ".s", ".S")


def die(msg: str) -> None:
    print(f"cubeide2cmake: {msg}", file=sys.stderr)
    sys.exit(2)


def main() -> None:
    if len(sys.argv) != 4:
        die("usage: cubeide2cmake.py WORK_DIR ORIGINAL_DIR NAME")
    work, orig, name = (os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2]), sys.argv[3])
    ide = os.path.join(work, "STM32CubeIDE")
    orig_ide = os.path.join(orig, "STM32CubeIDE")
    sdk = os.path.realpath(SDK)
    in_sdk = os.path.realpath(orig).startswith(sdk + os.sep)

    def resolve(p: str, must: bool, sub: str = "") -> str | None:
        """An Eclipse path -> an absolute path. Linked resources are relative to the
        STM32CubeIDE folder, build options (includes, libraries) to its build folder
        (STM32CubeIDE/Release): `sub` is that folder."""
        p = p.strip().strip('"')
        p = re.sub(r"^\$\{workspace_loc:/\$\{ProjName\}/?(.*)\}$", r"\1", p)
        m = re.match(r"^PARENT-(\d+)-PROJECT_LOC/(.*)$", p)
        if m:
            p = "../" * int(m.group(1)) + m.group(2)
        p = re.sub(r"^PROJECT_LOC/", "", p)
        if os.path.isabs(p):
            return p if os.path.exists(p) or not must else die(f"{p} not found")
        local = os.path.normpath(os.path.join(ide, sub, p))
        if local == work or local.startswith(work + os.sep):
            if os.path.exists(local) or not must:
                return local
            die(f"{p} (from the STM32CubeIDE project) is not in the project folder")
        if in_sdk:
            cand = os.path.normpath(os.path.join(orig_ide, sub, p))
            if os.path.exists(cand):
                return cand
        rest = re.sub(r"^(\.\./)+", "", os.path.normpath(p))
        for base in [sdk, f"{sdk}/Projects", f"{sdk}/Projects/NUCLEO-WB09KE",
                     *sorted(glob.glob(f"{sdk}/Projects/NUCLEO-WB09KE/*/*"))]:
            cand = os.path.join(base, rest)
            if os.path.exists(cand):
                return cand
        if must:
            die(f"{p} (from the STM32CubeIDE project) is not in the project or in $STM32CUBEWB0")
        return None

    # -- .cproject: the Release configuration ---------------------------------
    cproject = os.path.join(ide, ".cproject")
    if not os.path.exists(cproject):
        die(f"no STM32CubeIDE/.cproject in {orig}")
    text = open(cproject, encoding="utf-8", errors="replace").read()
    summaries = re.findall(r'value="(com\.st\.stm32cube\.ide\.common\.services\.build\.inputs[^"]*)"', text)
    summary = next((s for s in summaries if s.split(" || ")[1:2] == ["Release"]), summaries[0] if summaries else None)
    if summary is None:
        die("the .cproject has no STM32CubeIDE build summary")
    f = [x.strip() for x in summary.split(" || ")]
    config = f[1]
    split = lambda s: [x.strip() for x in s.split(" | ") if x.strip()]
    includes = [r for r in (resolve(i, False, config) for i in split(f[10])) if r and os.path.isdir(r)]
    defines = split(f[13])
    libs = [resolve(lib, True, config) for lib in split(f[17])]
    ld = resolve(f[18], True) if f[18] else None

    excluded: list[str] = []
    root = ET.fromstring(text.encode())
    for cfg in root.iter("configuration"):
        if cfg.get("name") != config:
            continue
        for entry in cfg.iter("entry"):
            if entry.get("kind") == "sourcePath" and entry.get("excluding"):
                base = entry.get("name") or ""
                excluded += [os.path.normpath(os.path.join(base, e)) for e in entry.get("excluding").split("|")]

    def is_excluded(virtual: str) -> bool:
        v = os.path.normpath(virtual)
        return any(v == e or v.startswith(e + "/") for e in excluded)

    # -- .project: linked files and folders, then files under STM32CubeIDE/ ----
    sources: list[str] = []
    proj = ET.parse(os.path.join(ide, ".project")).getroot()
    for link in proj.iter("link"):
        vname = link.findtext("name") or ""
        ltype = link.findtext("type")
        loc = link.findtext("locationURI") or link.findtext("location") or ""
        if loc.startswith("virtual:") or is_excluded(vname):
            continue
        if ltype == "1" and vname.endswith(SRC_EXT):
            sources.append(resolve(loc, True))
        elif ltype == "2":
            d = resolve(loc, False)
            if d and os.path.isdir(d):
                for dp, _, fs in os.walk(d):
                    for fn in fs:
                        rel = os.path.relpath(os.path.join(dp, fn), d)
                        if fn.endswith(SRC_EXT) and not is_excluded(os.path.join(vname, rel)):
                            sources.append(os.path.join(dp, fn))
    for dp, dirs, fs in os.walk(ide):
        dirs[:] = [d for d in dirs if d not in ("Debug", "Release") and not d.startswith(".")]
        for fn in fs:
            rel = os.path.relpath(os.path.join(dp, fn), ide)
            if fn.endswith(SRC_EXT) and not is_excluded(rel):
                sources.append(os.path.join(dp, fn))
    sources = list(dict.fromkeys(sources))
    if not sources:
        die("the STM32CubeIDE project lists no sources")

    q = lambda xs: "\n    ".join(f'"{x}"' for x in xs)
    with open(os.path.join(work, "CMakeLists.txt"), "w") as out:
        out.write("# written by stm32wb0-build from the STM32CubeIDE project's "
                  f"{config} configuration\n")
        out.write(f"cmake_minimum_required(VERSION 3.22)\nproject({name} C CXX ASM)\n")
        out.write("include($ENV{STM32WB0_CMAKE}/stm32wb0.cmake)\n")
        out.write(f"stm32wb0_firmware({name} RAW\n  SOURCES\n    {q(sources)}\n")
        if includes:
            out.write(f"  INCLUDES\n    {q(includes)}\n")
        if defines:
            out.write(f"  DEFINES\n    {q(defines)}\n")
        if libs:
            out.write(f"  LIBS\n    {q(libs)}\n")
        if ld:
            out.write(f'  LINKER_SCRIPT "{ld}"\n')
        out.write(")\n")
    print(f"==> STM32CubeIDE project ({config}): {len(sources)} sources, {len(includes)} include folders, "
          f"defines {' '.join(defines) or '-'}{', libs ' + ' '.join(os.path.basename(l) for l in libs) if libs else ''}")


if __name__ == "__main__":
    main()
