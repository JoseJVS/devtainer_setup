# NEST GPU

NEST GPU is a CUDA + MPI library for simulating large-scale spiking neural networks, usable from Python, C++ and C. Its Python interface mirrors the NEST simulator (dictionaries for neuron/connection/synapse properties). User docs: <https://nest-gpu.readthedocs.io>.

The branch (`sapi-update`) focuses on **SAPI**, the Spatial API in `//work/sapi-update/nest-gpu/sapi/`: a pure C++17 (no CUDA) library for distributed spatial node placement and spatially-masked connection generation across MPI ranks and OpenMP threads.

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

## Formatting

- To format C++/CUDA files use ```clang-format```, the configuration file is in `//work/sapi-update/nest-gpu/.clang-format`.
- To format Python files use ```ruff format```, the configuration file is in `//work/sapi-update/nest-gpu/.ruff.toml`.
- There are also additional formatting scripts run by ```pre-commit```, the configuration file is in `//work/sapi-update/nest-gpu/.pre-commit-config.yaml`.
- ```clang-format```, ```ruff format```, and ```pre-commit``` are available in the Python venv.
- To run all formatters on changed files run: ```pre-commit run --all-files``` in the repository directory.
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

Everything is in `namespace sapi`, mostly header-only templates over a coordinate type `CoordT` (only 2D available now).

- **Entry points**: `c_api.h/.cpp` (`CAPI`) is the boundary object. It owns the rank/thread/RNG configuration, garbage collectors (`garbage_collector.h`) for arrays handed out to C/Python, and a `BaseSpatialManager*`. `spatial_manager.h` declares `BaseSpatialManager` (virtual interface) and `SpatialManager<CoordT>`, which orchestrate the pipeline.
- **Pipeline**: a tile grid is generated (`grid_generation.h`, `tile*`, `gf*` = grid functor geometry and creators) and tiles are assigned to owning ranks. Then nodes are generated or inserted into tiles (`node_creation.h`, `node_insertion.h`, `node_distribution`, `node_slicing`). Connections are computed using masks (`mask*.h`, `mask_tile_processing.h`, `mask_node_processing.h`) and connection rules/generators (`connection_rules.h`, `connection_generator.h`, `cg_creators`). Results are exchanged across ranks in `spatial_communication.h`, in particular MPI messages are composed in `payload_preparation.h`. Connection data is prepared and stored in structures defined in `connection_containers.*`.
- **Plugin-style creators**: masks, grid functors, numeric functors (`nf_*`), connection generators (`cg_*`) and RNGs (`rng_*`) are registered by string name in a templated `CreatorRegistry` (`creator_registry.h`) and built from parameter structs (`MPStruct`, `GPStruct`, `CPStruct`). Adding a new kind means adding a creator and registering its name. Parameter names are exposed to Python via `get_parameter_names()`.
- **Determinism**: RNG streams are seeded per rank/thread/parity from constants in `sapi_config.h` (`random_manager.*`). Results must be identical for the same number of MPI processes and OpenMP threads per process, which `repeatability_test` checks for repeated construction within one run. Reproducibility across different process or thread counts is not supported yet. Only the multiset of connections is reproducible, not their order. Preserve this when changing generation order or RNG consumption.
- **Parallelism**: MPI code is guarded by `HAVE_MPI` (from the generated `libnestutil/config.h`). OpenMP uses `taskloop` with `num_tasks(strict: …)`. Per-thread data uses `thread_aligned_array.h` to avoid false sharing.
- Signed/unsigned and width choices in `sapi_config.h` typedefs are deliberate (see the comments there). Avoid narrowing conversions, which recent commits have been removing.

## Conventions

- Every source file starts with the GPL-2.0 NEST GPU license header (`<filename>` / "This file is part of NEST GPU").
- On this branch the scope for conventional commits is `sapi`, e.g. `fix(sapi): ...`, `chore(sapi): ...`.
