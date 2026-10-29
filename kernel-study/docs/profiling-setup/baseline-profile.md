# First real baseline profiles: x86 WSL2

Collected 2026-10-29 using `/usr/lib/linux-tools-6.8.0-147/perf` (perf 6.8.12)
on the existing Microsoft WSL2 6.6.87.2 kernel. Ubuntu's `/usr/bin/perf` wrapper
could not find tools matching the WSL kernel name; the actual binary worked.

These are real software-event profiles of unchanged native x86 CPU operations.
They are not emulation, RVV performance evidence, or model-inference profiles.
The source revision remains `31385c9cebf9e5271a38e14c26e5df6dd93718b1`;
file hashes were verified again after collection.

## What was run

Four model-free cases: F32 RMSNorm (width 896, one row) and matrix multiplication
with Q8_0, Q4_0 and IQ4_NL weights (64 output rows, reduction width 896, one
input column). Each case passed a fresh reference CPU correctness check before
one task-clock counter run and three sampled profiles. The upstream tester
warms and repeatedly computes the operation for at least one second per run.

All sampled runs used cpu-clock:u at 99 Hz, without call graphs. Samples include
all inherited threads and whole-process initialization/setup. The tested backend
uses the upstream hardware_concurrency()/2 policy: 12 requested backend threads
on this host. These profiles do not represent single-thread kernel costs.

There are 12 successful recordings containing 14,255 parsed samples in total.
Every perf report states zero lost samples. The expected GGML application
functions resolve by name. Some internal libgomp symbols are stripped, so their
reports contain addresses; those samples still count toward the runtime DSO.

Hardware cycles:u and instructions:u were attempted and reported unsupported.
There is consequently no measured IPC, hardware-cycle count, cache-miss count
or memory-stall diagnosis here. task-clock:u and userspace CPU-clock sampling
worked without changing system permissions.

## Finding: these small multithreaded cases mostly sample OpenMP runtime work

The percentages below use summed sampling periods by shared object within
each profile, then show the range across three recordings:

| Case | Samples across three runs | libgomp share of sampled userspace CPU time |
|---|---:|---:|
| RMSNorm | 3,544 | 93.3–94.7% |
| Q8_0 matrix operation | 3,581 | 81.6–84.7% |
| Q4_0 matrix operation | 3,582 | 81.3–83.5% |
| IQ4_NL matrix operation | 3,548 | 79.0–83.2% |

These are CPU-time shares across threads, not percentages of elapsed wall time.
For example, the RMSNorm counter run collected about 12,062 ms of userspace
task-clock at roughly 12 utilized CPUs during a roughly one-second workload.

The hot libgomp addresses include loops around 0x258a0 with `pause`, a counter,
and repeated shared-state checks; other hot addresses contain atomic state
updates. This disassembly supports a synchronization/spin-wait interpretation.
Without call graphs or internal runtime debug symbols, it does not identify an
exact named barrier routine or prove all runtime samples have one cause.

The expected application functions appear in the profiles:
`ggml_compute_forward_rms_norm`, `ggml_vec_dot_q8_0_q8_0`,
`ggml_vec_dot_q4_0_q8_0`, and `ggml_vec_dot_iq4_nl_q8_0`. Matrix profiles also
show `quantize_row_q8_0` and matrix/graph-compute overhead. This verifies those
x86 application paths in these specific cases; it does not establish future
RISC-V dispatch or their share of model inference.

The practical consequence is to add controlled single-thread kernel/operation
measurements, then larger and realistically threaded operation cases, before
ranking optimization candidates. Improving arithmetic could be obscured by
thread coordination in the current small cases. Do not treat the runtime share
as a proven end-to-end opportunity or apply it to a different architecture.

## Evidence

The [committed snapshot](../../evidence/host-2026-10-29/README.md) includes the
operation sample totals and inspected runtime disassembly. The raw-bundle links
below are local to the run owner and are not part of a fresh clone.

The complete final bundle is
[profiles.json](../../results/profiles/20261029T172121Z-pjl3ysvp/profiles.json).
Each case has a test capture, task-clock CSV, three raw perf.data files,
individual reports, sample listings, and copied binary/build/case/perf evidence.

Additional inspected artifacts:

- [RMSNorm report, recording 1](../../results/profiles/20261029T172121Z-pjl3ysvp/rms-f32-k896-n1/record/rep-001.report.txt)
- [IQ4_NL report, recording 1](../../results/profiles/20261029T172121Z-pjl3ysvp/mat-iq4_nl-m64-k896-n1/record/rep-001.report.txt)
- [Annotated IQ4_NL instructions](../../results/profiles/20261029T172121Z-pjl3ysvp/iq4-annotated.txt)
- [Hot OpenMP runtime disassembly](../../results/profiles/20261029T172121Z-pjl3ysvp/openmp-hot-addresses.dis)
- [Archived runtime library hash](../../results/profiles/20261029T172121Z-pjl3ysvp/runtime-library.json)

The annotated IQ4 output shows percentages local to that function (165 samples
in that recording), not its percentage of the complete process.

An earlier driver attempt successfully recorded data but failed normalization
because perf prints fields in a fixed order and omits symbols without requesting
IP. It is marked failed and is not used above. The parser was corrected, covered
by real-format fixture tests, and the full four-case collection rerun. All 15
tooling tests pass. The final bundle alone supplies the numbers in this report.

## Reproduce

After preparing the unchanged full baseline:

```sh
PERF=/usr/lib/linux-tools-6.8.0-147/perf python3 kernel-study/profile_operations.py
```

The driver runs correctness, software counters and three recordings per case,
then retains perf reports and period-weighted sample totals. Use --case CASE_ID
to restrict cases and --repetitions N to change recording count. The binary path
is specific to this host; set PERF to a working installed binary elsewhere.
Default classification is host-practice; --kind native requires riscv64.

At the time of these operation profiles, no model weights had been downloaded.
The [subsequent real-model inference profiles](../inference-baseline/results.md)
now provide one-thread Qwen2.5 prompt/decode results. The model-free profiles
above need no inference model. Native RVV profiling awaits the actual board.
