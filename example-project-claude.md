# NEST GPU

NEST GPU is a CUDA + MPI library for simulating large-scale spiking neural networks, usable from Python, C++ and C. Its Python interface mirrors the NEST simulator (dictionaries for neuron/connection/synapse properties). User docs: <https://nest-gpu.readthedocs.io>.

The branch (`sapi-update`) focuses on **SAPI**, the Spatial API in `//work/sapi-update/nest-gpu/sapi/`: a pure C++20 (no CUDA) library for distributed spatial node placement and spatially-masked connection generation across MPI ranks and OpenMP threads.

## Directory hierarchy

- Project root: `//work/sapi-update`
- NEST GPU repository: `//work/sapi-update/nest-gpu`
- Python venv: `//work/sapi-update/venv-ngpu`
- Project documentation: `//work/sapi-update/documentation`
- Build directory: `//work/sapi-update/build`

## Commands

- Load Python venv: ```source /work/sapi-update/venv-ngpu/bin/activate```
- Configure CMake: ```cmake -S /work/sapi-update/nest-gpu -B /work/sapi-update/build -Dwith-cpp-tests=ON```
- Build: ```cmake --build /work/sapi-update/build -j```
- Install: ```cmake --install /work/sapi-update/build```
- Run C++ SAPI tests: ```cd /work/sapi-update/build && make sapicheck```

## Compilation

- Always load Python venv first then in order: configure, build, install.
- A new `sapi/*.cpp` must be added to `sapi_kernel_sources` in `sapi/CMakeLists.txt` (then clean rebuild).
- The configuration step is only needed once unless there is a change in the `CMake` files. If there is a change in these files, then clean the build directory and re-run the configuration step.
- Ensure build and install are executed after every change to the nest-gpu repository.
- If the repository branch changes then clean the build directory, and re-run configure, build, install.

## Tests

- C++ SAPI test files: `//work/sapi-update/nest-gpu/testsuite/sapi/*.cpp`
- Python test file: `//work/sapi-update/nest-gpu/python/tests/sapi_tests/sapi_test.py`
- Before running the C++ SAPI tests ensure the build directory is up to date.
- The C++ SAPI test command runs a bash script that executes all C++ SAPI tests. Each test success is checked with the exit code, code 0 denotes successful execution. The bash script automatically executes MPI tests with varying configuration of processes. If all tests pass then the test command exits with code 0 too.
- Before running any Python tests ensure the Python venv is loaded and all compilation steps successfully ran since the last change to the repository.
- To run invididual Python tests execute: ```mpirun -np #N# python <test_file>.py``` where N is the number of MPI processes. Test success is checked with the exit code, code 0 denotes successful execution. Tests be should run with at least 1 and 2 MPI processes.
- New tests: add the source to `sapi_tests_sources` in `testsuite/sapi/CMakeLists.txt`, MPI tests also to `multi_processing_tests`, tests with deliberately oversized inputs also to `memory_capped_tests` (run under `ulimit -v`). Changing that CMake file means a clean rebuild.
- SAPI builds with GCC's default FMA contraction (`-ffp-contract=fast`): one expression can round differently at different inlined call sites (test vs library). Tests comparing recomputed floating-point values use tolerances scaled to the geometry, not exact or absolute `almost_equal` comparisons. `-ffp-contract=off` was measured 3–8% slower and is not used.
- New shared test headers go in `sapi_tests_helper_headers` (same CMake file).
- Geometry tests: `geometry_test_helpers.h` holds the reference polygons and samplers, and `exact_geometry_test.cpp` checks the mask/tile filters against an independent oracle (`geometry_oracle.h` for the generic part, `geometry2d_oracle.h` for 2D). Any change to `tile_overlap`, `tiles_within_mask_range` or `overlap_with_tile_surface` must keep it passing. Its `EXACT_NONCIRCULAR_B1/B2` flags switch on the gap checks for the non-circular masks once those filters are exact.
- Test-only checks that must also hold under NDEBUG use a `require()` helper, not `assert`.
- Including `grid_generation.h` in a test needs `bounding_box.h` included first.
- Run new or memory-heavy tests one at a time under `ulimit -v` (e.g. 4 GB per process) before the full `make sapicheck`; unbounded runs have exhausted the machine's memory.
- `make sapicheck` runs the installed test copies in `build/tests/sapi/`, not `build/testsuite/sapi/`: always build **and** install before it, or it reports stale results.
- `capi_error_handling_test` hardcodes each registry's names list in its expected messages; registering a new mask, grid functor, etc. means updating that string.
- `exact_geometry_test`'s `conservative_*` references copy single filter stages; moving a test between stages (e.g. into the per-shape surface test) needs those references updated, even when results are bit-identical.
- Agent-written tests are never compiled by the agent: expect a fix-up round, and check coverage thresholds and test premises (e.g. "push past contact ⇒ overlap" is false for flat sets) against an independent oracle before trusting a failure.
- A new regression test must fail on the old code: compile it in the scratchpad against a `git archive HEAD sapi` tree's `libsapi_kernel.a` (library flags) and run it there, with `-DNDEBUG` to get past asserts.
- Test geometry: `Tile(shape, center, {side}, {angle})` takes whole degrees (`angle_t` is an integer), turned clockwise, and needs side² > `SP_EPSILON`. Parallelogram mask params are half-diagonals a0, a1 (edges a0 − a1 and a0 + a1 from the corner anchor − a0); triangular params are the edge vectors from the anchor vertex.

## Formatting

- To format C++/CUDA files use ```clang-format```, the configuration file is in `//work/sapi-update/nest-gpu/.clang-format`.
- To format Python files use ```ruff format```, the configuration file is in `//work/sapi-update/nest-gpu/.ruff.toml`.
- There are also additional formatting scripts run by ```pre-commit```, the configuration file is in `//work/sapi-update/nest-gpu/.pre-commit-config.yaml`.
- ```clang-format```, ```ruff format```, and ```pre-commit``` are available in the Python venv.
- To run all formatters on changed files run: ```pre-commit run --all-files``` in the repository directory.
- `pre-commit run --all-files` only checks files git already knows about: run `git add -N <new files>` first so new files are checked too.
- Always format after editing files, especially before running building steps after changes.
- No linting is currently required.

## Architecture

Build targets and how they layer:

```text
pythonlib/ (ctypes)  ──►  libnestgpu.so  (nestgpu/nestgpu_C.cpp: flat C API)
                              ├── nestgpu_kernel  (src/: CUDA simulator core)
                              └── sapi_kernel     (sapi/: C++ spatial API, static)
```

- **`src/`**: the GPU simulator. Neuron models (`aeif_*`, `iaf_*`, `izhikevich*`, each `.cu` + `.h` + often `_kernel.h`/`_rk5.h` for the RK5 adaptive solver), connection storage (`conn12b`/`conn16b`, `connect*.cu`, `remote_connect*`), spike buffers, and the `NESTGPU` class in `nestgpu.h/.cu`.
- **`nestgpu/nestgpu_C.cpp`**: the C ABI that wraps both `NESTGPU` and SAPI. It holds a single static `sapi::CAPI capi` and translates SAPI results into simulator node/connection creation. Errors cross the boundary through `propagate_error.h` macros, not exceptions.
- **`pythonlib/`**: installed as the `nestgpu` Python package. `nestgpu_api.py` loads `libnestgpu.so` with `ctypes.CDLL` and exposes the NEST-like API. `ll_sapi.py` holds the ctypes struct and type mirrors of SAPI types. **The ctypes aliases there (`vp_t`, `nix_t`, `space_t`, …) must stay in sync with the typedefs in `sapi/sapi_config.h`, and ctypes `Structure`s with the C++ structs in `sapi/api_containers.h`.**

### SAPI (`sapi/`)

Everything is in `namespace sapi`, mostly header-only templates over a coordinate type `CoordT`. `Coord3D` and the 3D primitives exist; tiles, grids, masks and the manager are still 2D only.

- **Entry points**: `c_api.h/.cpp` (`CAPI`) is the boundary object. It owns the rank/thread/RNG configuration, garbage collectors (`garbage_collector.h`) for arrays handed out to C/Python, and a `BaseSpatialManager*`. `spatial_manager.h` declares `BaseSpatialManager` (virtual interface) and `SpatialManager<CoordT>`, which orchestrate the pipeline.
- **Pipeline**: a tile grid is generated (`grid_generation.h`, `tile*`, `gf*` = grid functor geometry and creators) and tiles are assigned to owning ranks. Then nodes are generated or inserted into tiles (`node_creation.h`, `node_insertion.h`, `node_distribution`, `node_slicing`). Connections are computed using masks (`mask*.h`, `mask_tile_processing.h`, `mask_node_processing.h`) and connection rules/generators (`connection_rules.h`, `connection_generator.h`, `cg_creators`). Results are exchanged across ranks in `spatial_communication.h`, in particular MPI messages are composed in `payload_preparation.h`. Connection data is prepared and stored in structures defined in `connection_containers.*`.
- **Plugin-style creators**: masks, grid functors, numeric functors (`nf_*`), connection generators (`cg_*`) and RNGs (`rng_*`) are registered by string name in a templated `CreatorRegistry` (`creator_registry.h`) and built from parameter structs (`MPStruct`, `GPStruct`, `CPStruct`). Adding a new kind means adding a creator and registering its name. Parameter names are exposed to Python via `get_parameter_names()`.
- **Determinism**: RNG streams are seeded per rank/thread/parity from constants in `sapi_config.h` (`random_manager.*`). Results must be identical for the same number of MPI processes and OpenMP threads per process, which `repeatability_test` checks for repeated construction within one run. Reproducibility across different process or thread counts is not supported yet. Only the multiset of connections is reproducible, not their order. Preserve this when changing generation order or RNG consumption.
- **Parallelism**: MPI code is guarded by `HAVE_MPI` (from the generated `libnestutil/config.h`). OpenMP uses `taskloop` with `num_tasks(strict: …)`. Per-thread data uses `thread_aligned_array.h` to avoid false sharing.
- Signed/unsigned and width choices in `sapi_config.h` typedefs are deliberate (see the comments there). Avoid narrowing conversions, which recent commits have been removing.

## SAPI code rules

- No `throw`, `try` or `catch` inside OpenMP regions. Validate inputs before the region, in the function that uses them, with data every rank holds, so all ranks throw the same `std::invalid_argument`. Inside regions only `assert` conditions that were validated up front.
- Check each input once, where it is used; the manager does not repeat checks of the modules it forwards to.
- Prefer named free functions over lambdas that hold logic; keep lambdas for short predicates and one-line forwarders (e.g. `dispatch_bools`).
- Only `sapi/` and `testsuite/sapi/` change for SAPI work; existing test files change only when asked.
- Dimension layering: generic files (no `2d`/`3d` in the name) hold only the dimension-agnostic interface, the shared object definitions and plain dispatch (`if constexpr` on `CoordT`, `switch` on shape). Dimension-specific logic goes in `*2d_*` files (later `*3d_*`). `coordinates.h`/`coordinate_geometry.*` may hold both 2D and 3D primitives, which generic code reaches only through the `Coordinate` concept. `enum_store.h` is the free-standing enum header. `layer_check.sh` (see Verification) must report 0 leaks.
- Generic `Mask` tests assume neither convexity nor an anchor inside the mask; tests that depend on a shape property live in the per-shape functions behind the `mask_geometry.h` dispatchers. The convex shapes contain their `anchor_`, which their per-shape tests rely on (first accept: `anchor_in_tile`); the annulus is centered on its anchor and starts with its hole reject instead. The per-pair `coord_in_mask` dispatchers switch over the convex shapes only and forward `default` to `coord_in_nonconvex_mask` (a fifth case made GCC emit a jump table, ~5% slower). `bounding_disk_` is centered on the shape, so for triangles it is not centered on the anchor, which is a vertex.
- The per-pair image-displacement loop (minimal displacement over the used images, node test inlined) is written out where the pairs are iterated: in the probabilistic `compute_minimal_displacement` and in `generate_fixed_number_connections` (`connection_rules.h`), not in a per-pair helper. A helper stays inlined only under GCC's single-function inlining limit, which small node-test changes crossed (30–60% slower when it was not, measured 2026-11-25/26). Per-pair changes still need the same-session A/B (`run_bench.sh` covers circle/ellipse/annulus with Bernoulli and Poisson only: also bench parallelogram/triangle masks and fixed-number rules when they are affected); avoid compiler attributes.
- Style: switch ladders on a bit-keyed integer (as in `displacement_in_ellipse`) over if chains; early returns that skip further computation are the exception. typedefs/`using` at the top of the file (an alias may follow a struct of the same header it uses). Pass by value only trivially copyable types < 128 bits (`Coord2D` is 128 bits: `const&`; dynamic `std::span`: `const&`), and make unmodified parameters `const`; RNG engines that get called are never `const`. No locals that only alias available objects (dereferenced pointers and variable-index elements are fine). Fold a single-use helper into its caller only if it does simple reads or arithmetic (helpers keeping a switch case simple stay). `inline` only on simple functions (no loops, few locals), except hot-path functions that rely on inlining; other non-simple functions leave headers for a `.cpp`.
- Correctness fixes are tried even on hot paths, then benchmarked (same-session A/B); keep them only if the correctness gain outweighs the slowdown, otherwise revert and document the limit at the code location.
- Before adding a function similar to an existing one, ask: prefer generalizing or merging it (bit changes are fine if results stay correct); existing look-alikes are merged when it costs no measurable performance.
- Common operations across functions should be refactored out into free-standing helper functions.
- Rotations turn clockwise everywhere: `rotate_displacement` places a body (2D: R(−α); 3D: Rᵀ with `Rotation3D` rows of R = Rz·Ry·Rx), and `inverse_rotate_displacement` maps into its frame. Tiles, grids and the ellipse store the (cos, sin) of +angle; `create_angular_offset` is exact at multiples of 90°.

## Verification and planning

- Restart point: `//work/sapi-update/documentation/progress.md` (status of all phases; plan in `sapi_improvement_plan.md`).
- Tools in `//work/sapi-update/documentation/tools` (see its README): `conversion_ratchet.sh check ../baseline/q0_conversion_warnings.txt` (no new conversion warnings), `link_check.sh`, `run_fingerprint.sh` + `compare_fingerprint.sh` (output must stay identical unless a change intends otherwise), `layer_check.sh` (no dimension leaks), `sapi_geometry_check`/`sapi_geometry_e2e` (geometry filters), `run_bench.sh` (A/B benchmarks; each rank gets its own hardware threads: `--map-by slot:PE=<t>:hwtcpus --bind-to hwthread`, `OMP_PLACES=threads`, `OMP_PROC_BIND=spread`).
- `run_fingerprint.sh <dir> <label>`, then `compare_fingerprint.sh <dirA> <labelA> <dirB> <labelB>` (e.g. `../baseline q8_3m_fingerprint ../baseline step3_fingerprint`); `layer_check.sh check ../baseline/q7_16_layer_leaks.txt` (run from `documentation/tools`). Baseline labels end in `_fingerprint` (e.g. `q8_2_fingerprint`), which `compare_fingerprint.sh` expects. Files with more than one rank hold per-rank sections, so new scenarios land mid-file: compare with the new scenario's lines filtered out (`grep -v <name>`).
- Hot-path changes (mask dispatch, per-pair code) need a same-session A/B, not a comparison with an old baseline file (drift reaches ±5%): build both trees in the scratchpad (`git archive <commit> sapi`, compile `sapi/*.cpp` with the `sapi_kernel` flags into `libsapi_kernel.a`, build `sapi_fingerprint` with `build_tools.sh`'s flags, copy `run_bench.sh` + `bench_summary.py` next to each binary) and run the versions alternately (A, B, A, B).
- Profiling a regression: `perf record -e cycles:u` (otherwise mostly kernel samples), then `perf report --sort sym`; for inlining, compile the TU with `-fopt-info-inline-missed=<file>` (e.g. `sapi/c_api.cpp` holds the connection loops); `--param max-inline-insns-single=<n>` sweeps give a function's inlining threshold, and `-fdump-ipa-inline-details` shows GCC's size estimate as callees are inlined.
- While a benchmark runs (often 15–45 min in the background), build nothing and start no CPU-heavy agents; queue the follow-up work until it finishes.

## Conventions

- Every source file starts with the GPL-2.0 NEST GPU license header (`<filename>` / "This file is part of NEST GPU").
- On this branch the scope for conventional commits is `sapi`, e.g. `fix(sapi): ...`, `chore(sapi): ...`.
- Comments never cite audit or plan items; they state the reason. External references: each cited at most once across `sapi/`, scholarly DOIs first, verified (resolved, authors, title, venue, year, supported claim) before adding.
