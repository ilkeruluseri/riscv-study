# Measurement capture and profiling setup

## What
Provide a standard-library Python entry point to check tool availability and
capture benchmark commands in self-contained result directories. Adapt the
existing IQ4 native script to use it. Prepare native perf collection without
claiming that native counters or timings have been validated on this x86 host.

## Requirements
- `doctor` reports platform, tool availability/versions, affinity and available
  Linux performance/frequency metadata without changing system configuration.
- `run` records exact argv/cwd, selected run kind, environment, elapsed process
  times, exit codes, stdout/stderr and hashes/copies of requested input artifacts.
- Default kind is smoke; native timing/profiling requires a riscv64 host and
  rejects direct QEMU invocation. Document that architecture checks cannot prove
  the absence of a VM, emulator wrapper or remote execution.
- Repetitions are explicit and sequential; a failed command stops the run,
  retains diagnostics, and returns failure. No shell evaluation of command text.
- Optional perf stat/record runs require native mode and an available perf;
  errors are preserved, never silently replaced with other events.
- The IQ4 script retains correctness-before-timing, paired samples and its
  existing summary; its binaries/build evidence and CSV become captured artifacts.
- Existing studies and frozen upstream inputs keep their behavior.

## Design
Add `measure.py` with `doctor` and `run` subcommands, using JSON metadata and
unique run directories. Run kinds are smoke, host-practice and native; host
practice is explicitly not RVV performance evidence. Generic elapsed time
includes startup/teardown and is distinct from benchmark-internal kernel timing.
Use process sampling without call graphs by default; unwinding is board-specific.
Do not install packages or change perf permissions globally. Simulators and an
LLVM scheduling-model evaluation are separate work.

## Testing strategy
Exercise successful and failed subprocesses, separate streams, repeat handling,
literal shell metacharacters, artifact capture, mode guards and mocked perf
invocations. Run the existing full IQ4 check under QEMU. Capture a real IQ4
emulated benchmark smoke run and a tool inventory on this machine. Native perf
execution remains unverified until hardware is available.

## Out of scope
Kernel optimizations, model downloads, full llama.cpp builds, selecting a board,
streaming changes to the IQ4 harness, statistical significance claims, workflow
policy for the team, system package installation and VM detection guarantees.
