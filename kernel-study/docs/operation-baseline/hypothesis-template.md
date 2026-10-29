# Investigation: <short name>

- Owner / reviewer:
- Status: proposed / implemented / correctness-checked / native-measured / rejected / inconclusive
- Source revision and baseline build hash:
- Operation, data types, shapes and case IDs:
- Actual caller and dispatch evidence (or explicitly unverified):
- Existing source/assembly evidence and suspected limiting resource:
- One proposed change:
- Expected mechanism and conditions under which it should win or lose:
- Correctness contract: widths, accumulation precision/order, tails, special values, tolerance:
- Reference computation and tests (including independent oracle where needed):
- Exact build/run commands and raw result bundle location:
- Run kind: smoke / host-practice / native; CPU, ISA/VLEN, threads and cache regime:
- Unprofiled timing evidence across repetitions and independent sessions:
- Separate profile/counter evidence, supported events and measurement scope:
- Alternative explanations, uncertainty and remaining integration checks:
- Decision: retain / reject / inconclusive, and why:

Start with the unchanged baseline. Make one change at a time. A complete result
may reject the hypothesis. Host practice validates setup; native results decide
RVV performance. Recheck upstream before investing in an implementation.
