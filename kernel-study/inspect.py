"""Save linked kernel disassembly and check the proposed code-generation effect."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys


def main():
    binary = Path(sys.argv[1])
    text = subprocess.check_output(
        [os.environ.get("OBJDUMP", "riscv64-linux-gnu-objdump"), "-d",
         "--no-show-raw-insn", str(binary)], text=True)
    binary.with_suffix(".dis").write_text(text)
    matches = list(re.finditer(r"^([0-9a-f]+) <([^>]+)>:\n", text, re.MULTILINE))
    summary = {}
    for i, match in enumerate(matches):
        name = match.group(2)
        if not re.match(r"^(baseline|candidate)_vl(128|256)(\.|$)", name):
            continue
        body = text[match.end():matches[i + 1].start() if i + 1 < len(matches) else len(text)]
        instructions = re.findall(r"^\s*[0-9a-f]+:\s+(\S+)\s*(.*)$", body, re.MULTILINE)
        stem = re.match(r"(baseline|candidate)_vl(128|256)", name).group(0)
        counts = {"symbol": name, "instructions_in_function": len(instructions)}
        for opcode in ("vse32.v", "vmv.x.s", "vwredsum.vs", "vsetvli", "vsetivli"):
            counts[opcode] = sum(op == opcode for op, _ in instructions)
        counts["scalar_lw_from_sp"] = sum(op == "lw" and "(sp)" in args for op, args in instructions)
        addressed = [(int(address, 16), op, args) for address, op, args in re.findall(
            r"^\s*([0-9a-f]+):\s+(\S+)\s*(.*)$", body, re.MULTILINE)]
        loops = []
        for address, op, args in addressed:
            target = re.search(r"(?:,|\s)([0-9a-f]+)\s+<", args)
            if not op.startswith("b") or target is None:
                continue
            start = int(target.group(1), 16)
            loop = [(o, a) for pc, o, a in addressed if start <= pc <= address]
            if start < address and sum(o == "vwredsum.vs" for o, _ in loop) == 2:
                loops.append(loop)
        if len(loops) != 1:
            raise SystemExit("Expected one pair loop: " + name)
        counts["pair_loop_instructions"] = len(loops[0])
        counts["pair_loop_vset"] = sum(o in ("vsetvli", "vsetivli") for o, _ in loops[0])
        summary[stem] = counts
        binary.with_name(binary.name + "-" + stem + ".dis").write_text(match.group(0) + body)
        baseline = stem.startswith("baseline")
        if counts["vse32.v"] != (2 if baseline else 0) or counts["vmv.x.s"] != (0 if baseline else 2):
            raise SystemExit("Code generation hypothesis not established: " + name)
    if len(summary) != 4:
        raise SystemExit("Expected four distinct kernel symbols; inspect compiler output")
    binary.with_name(binary.name + "-assembly.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
