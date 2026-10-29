# Host perf installation status

Update: the user installed perf. The real binary at
`/usr/lib/linux-tools-6.8.0-147/perf` works for software events on this WSL host.
See the [actual baseline profile results](baseline-profile.md) for completed
measurements. The restrictions below describe the earlier installation attempt.

On 2026-10-29 the agent attempted to obtain perf for this Ubuntu 24.04 / WSL2
6.6.87.2 host. Installation could not complete in the managed environment:

- Shell network access could not resolve archive.ubuntu.com.
- System package directories are read-only to the agent.
- sudo cannot elevate: the process has NoNewPrivs enabled.
- No cached perf binary or linux-tools package was found.

This is an agent-environment restriction, not evidence that WSL cannot profile
the workload. A direct perf_event_open check succeeded for userspace cpu-clock
and task-clock events. Hardware cycles/instructions returned ENOENT on this
host. Thus software CPU-time sampling is the first suitable measurement to try.
The probe only opened and closed disabled events; it collected no samples or
counter measurements. Raw probe: results/perf-access-probe.json.

Install from the user's normal WSL terminal outside the agent sandbox:

```sh
sudo apt-get update
sudo apt-get install linux-tools-common linux-tools-generic
```

Ubuntu's /usr/bin/perf wrapper may require a kernel-version-specific directory
that is absent for Microsoft's WSL kernel. In that case select an installed
actual binary, rather than the wrapper:

```sh
find /usr/lib -path '*linux-tools*' -type f -name perf
export PERF=/path/printed/above/perf
"$PERF" --version
"$PERF" stat -e task-clock:u -- sleep 1
```

Replace the example path with a real result. A distribution binary may work
with this older WSL kernel for basic software events; test it rather than
assuming compatibility. If it fails, a perf build from matching WSL kernel
sources is the next option. No kernel permissions need changing based solely
on the current successful userspace-event probe.

The runner now accepts --kind host-practice with --profile stat/record and
honors PERF. It continues rejecting smoke profiles and direct QEMU invocations.
Use --events task-clock:u for counts on this host; default stat also requests
hardware events, which were unavailable in the probe. Default record samples
cpu-clock:u at 99 Hz. Host-practice profiles never become RVV evidence.

After installation, run the existing case correctness check and profile the
unchanged baseline without a model:

```sh
python3 kernel-study/baseline.py run --mode test --case rms-f32-k896-n1
python3 kernel-study/measure.py run --kind host-practice --profile record \
  --artifact kernel-study/workspace/operation-baseline/source.json \
  --artifact kernel-study/workspace/operation-baseline/build.json \
  --artifact kernel-study/workspace/operation-baseline/cases/rms-f32-k896-n1.txt \
  -- kernel-study/workspace/operation-baseline/build/bin/test-backend-ops \
  perf -b CPU --output sql \
  --test-file kernel-study/workspace/operation-baseline/cases/rms-f32-k896-n1.txt
```

Then inspect perf report/annotate for the printed run directory. Verify useful
sample counts, function names and initialization versus timed-operation costs.
Repeat for Q8_0, Q4_0 and IQ4_NL cases. These use the upstream tester's documented
thread policy and whole-process sampling scope.

Actual operation profiles have now been collected. Model files have since been
downloaded, hash-verified, benchmarked and
profiled. See the [real-model inference results](../inference-baseline/results.md).
