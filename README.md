# Modern C++ 工程模板（`cpp-template`）V1 设计文档

| 文档属性 | 说明 |
| --- | --- |
| **模板仓库名** | `cpp-template`（工程内部安全占位符：`my_project`） |
| **核心场景定位** | 机器人 ROS 2 中台纯 C++ 核心库、算法/仿真引擎与客户端 SDK 标准基座 |
| **语言与构建基线** | C++17 / C++20（默认 C++17 契合 ROS 2 生态，一键切换 C++20），`CMake >= 3.16`，面向 Linux（GCC / Clang） |
| **构建与工具体系** | 原生 Modern CMake + `package.xml`（兼容 `colcon`）+ 根目录 `Makefile` + `CMakePresets.json` + 离线强门禁 `pre-commit` |
| **依赖与安全策略** | 100% 本地离线自治（严禁云端外发与 `CPM.cmake` 联网拉取），采用**“本地预编译动/静态库优先 → 本地源码编译兜底”**机制 |
| **核心设计理念** | **简单（Simple）、易用（Easy to Use）、方便扩展（Extensible）、优雅（Elegant）** |

---

## 一、 设计目标

本模板旨在为机器人 ROS 2 中台研发团队提供一套**高透明、零黑盒、开箱即用、符合企业内网安全合规**的纯 C++ 工程标准基座，解决传统项目目录混乱、ROS 通信层与核心算法耦合过重、构建参数不统一、内存与并发隐患后置等问题。具体目标分为五个维度：

1. **100% 本地离线自治，契合中台依赖管理体系**
   * **严守企业数据安全红线**：坚决不引入 GitHub Actions、Codecov 等需要将代码或度量数据外发至第三方云端的服务；同时完全排斥 `CPM.cmake`、`FetchContent` 等配置期联网拉取工具。
   * **本地预编译优先 + 源码回退**：贴合企业中台“通用三方库（如 `spdlog`、`GTest` 等）已有预编译产物且源码由内部专仓统一维护”的现状，建立标准依赖查找契约——**优先查找本地已安装的动态库/静态库（系统路径、ROS 2 环境、Conda 或中台预置目录），未命中时按需回退至本地受控源码目录编译**。

2. **ROS 2 中台“内核解耦 + 工作空间无缝融合”**
   * 践行 **Core-Wrapper 分离架构**：模板核心库保持 100% 纯标准 C++ 与原生 CMake，不耦合 `rclcpp` 或 `ament_cmake`，保证极速增量编译与脱离 ROS 环境的独立可测试性。
   * 原生内置符合 REP-149 规范的纯 CMake 版 `package.xml` 与本地构建隔离锁（`COLCON_IGNORE`），既支持在单仓内执行 `make build` 极速迭代，又支持直接放入 `ros2_ws/src/` 由 `colcon build` 统一编排并供下游 ROS 2 节点无缝 `find_package` 链接。

3. **务实的低版本 CMake 基线与无污染源码嵌套**
   * 以 C++17 成熟期对应的 **`CMake 3.16`**（Ubuntu 20.04 / 22.04 默认自带版本）作为最低支持基线，在核心脚本与 `Makefile` 中规避高版本 CMake 专属语法，确保在各类存量开发机与容器内零升级直接运行。
   * 内置兼容低版本 CMake 的顶层工程守卫（`MY_PROJECT_IS_TOP_LEVEL`），当本仓库作为源码子模块被其他中台工程通过 `add_subdirectory` 引入时，自动静默自身的测试、示例、文档与 `-Werror`，仅暴露干净的核心库目标。

4. **极致的开箱体验、一键派生与编译性能防呆**
   * **克隆即编**：无需手工准备前置参数，执行 `make build && make test` 即可 100% 编译通过并运行测试。
   * **一键派生**：内部统一采用 `my_project` / `MY_PROJECT_` 作为占位符（规避 C++ 关键字 `template`），通过 `make init NAME=<project_name>` 一键完成目录、文件、命名空间、`package.xml` 与宏前缀的无损重命名。
   * **防误操作与防重编风暴**：内置源码内构建拦截锁防止误敲 `cmake .` 覆盖 `Makefile`；将动态变化的 Git Commit Hash 隔离生成至内部 `version.cpp` 而非公共头文件，避免每次 `git commit` 引发全工程及下游包的重编雪崩。

5. **提交前标准化强门禁与高性能 C++ 质量防线**
   * 在 **`git commit` 提交前阶段强制拦截**代码风格（`clang-format`）、增量静态分析（`clang-tidy`）、公共 API 注释完整性（Doxygen）与提交规范（`gitlint`），确保入库代码 100% 经过本地标准化检查。
   * 将严格编译警告、内存越界/泄漏与未定义行为检测（`ASan/UBSan`）、多线程数据竞争检测（`TSan`）深度整合进 `Makefile` 日常指令，将底层隐患消灭在研发本机。

---

## 二、 目录架构及设计原因

### 2.1 标准目录结构

```text
cpp-template/
├── .clang-format                 # C++17/20 统一代码风格规则
├── .clang-tidy                   # 静态分析规则（聚焦内存、并发、零拷贝性能与现代 C++）
├── .gitlint                      # Git Commit Message 规范配置
├── .gitignore                    # 忽略 build/、install/、log/、compile_commands.json 及 IDE 缓存
├── .pre-commit-config.yaml       # 纯本地离线 Git 提交前强拦截钩子（repo: local）
├── package.xml                   # ROS 2 包描述清单（声明 <build_type>cmake</build_type>，原生支持 colcon）
├── Makefile                      # 开发者唯一命令行入口（兼容 CMake 3.16+，覆盖初始化、构建、测试与门禁）
├── CMakeLists.txt                # 顶层构建脚本（防源码内构建锁、顶层工程守卫、C++17/20 切换）
├── CMakePresets.json             # 面向现代 IDE（VS Code / CLion）与高版本 CMake 的 5 套标准预设
├── cmake/                        # 高内聚原生 CMake 模块（仅保留不可替代的 4 个核心文件）
│   ├── CompilerWarnings.cmake    # 跨编译器严格警告集（GCC / Clang）
│   ├── Sanitizers.cmake          # 内存与线程动态检测（支持 -DUSE_SANITIZER 完整参数与互斥校验）
│   ├── Dependencies.cmake        # 本地依赖探测辅助模块（优先查找本地动/静态库，未命中回退本地源码目录）
│   └── my_projectConfig.cmake.in # 原生 find_package 导出包配置模板
├── include/                      # 对外暴露的公共头文件（Doxygen 强校验唯一作用范围）
│   └── my_project/               # 二级项目命名空间目录，彻底防止下游 #include 命名冲突
│       ├── core/                 # 核心引擎 / 中台算法与业务逻辑公共接口
│       │   └── engine.hpp
│       ├── client/               # 客户端 / SDK 公共接口（推荐 PImpl 隐藏底层通信/序列化实现）
│       │   └── client.hpp
│       └── version.hpp           # 稳定语义化版本号与 Git Commit 查询接口声明（不含动态宏，防重编）
├── src/                          # 核心库内部实现与私有头文件（对外完全不可见）
│   ├── CMakeLists.txt            # 编译核心库并导出标准别名目标 my_project::my_project
│   ├── core/
│   │   ├── version.cpp.in        # 构建期注入语义化版本与 Git Commit Hash 的实现模板
│   │   └── engine.cpp
│   └── client/
│       ├── client_impl.hpp       # 私有实现头文件，随 .cpp 存放，不暴露给下游调用方
│       └── client.cpp
├── apps/                         # 独立可执行程序薄封装层（仅做参数解析、生命周期与进程启动）
│   ├── CMakeLists.txt
│   └── main.cpp
├── tests/                        # 单元测试与集成测试（接入 CTest，支持本地 GTest 库/源码与零依赖兜底）
│   ├── CMakeLists.txt
│   └── test_core.cpp
├── benchmarks/                   # 独立性能基准测试（默认关闭，Release 压测时按需开启）
│   ├── CMakeLists.txt
│   └── bench_engine.cpp
├── examples/                     # 外部调用视角最小示例（验证 SDK/Client 接口易用性）
│   ├── CMakeLists.txt
│   └── basic_client.cpp
├── docs/                         # 本地 API 文档生成与公共头文件注释门禁配置
│   ├── CMakeLists.txt            # 注册 docs 与 check-docs 原生构建目标
│   └── Doxyfile.in               # Doxygen 配置模板（仅针对 include/ 开启 WARN_AS_ERROR）
└── .claude/                      # [可选] 团队现有 AI 辅助研发命令（commit / review / push / summary）
    └── commands/
```

### 2.2 为什么这样设计（关键工程决策解析）

| 目录 / 文件设计 | 背后的工程考量与原因 |
| --- | --- |
| **内置纯 CMake 版 `package.xml` + `COLCON_IGNORE`** | 主力面向 ROS 2 中台时，声明 `<build_type>cmake</build_type>` 让仓库保持 **零 ROS 依赖纯 C++ 属性**的同时，能直接放入 `ros2_ws/src/` 被 `colcon build` 识别、参与依赖拓扑排序并导出给 ROS 2 节点使用；而本地执行 `make build` 时自动在 `./build/` 下生成 `COLCON_IGNORE`，防止外层 `colcon` 误扫描本地构建缓存目录。 |
| **`Makefile` 原生 `-B` 驱动 + `CMakePresets.json` 协同** | `CMakePresets.json` 需要 CMake 3.20+ 才支持命令行调用，而部分 C++17 存量环境（如 Ubuntu 20.04 默认 CMake 3.16）版本较低。因此 `Makefile` 底层直接采用 CMake 3.16 原生支持的 `-S . -B build/<mode>` 参数驱动，确保低版本环境 100% 畅通；同时保留参数一致的 `CMakePresets.json` 供现代 IDE 直接读取，兼顾兼容性与体验。 |
| **`cmake/Dependencies.cmake` 封装本地双模查找** | 摒弃 `CPM.cmake` 联网拉取，统一封装 `my_project_find_or_build()` 逻辑：**第 1 优先级**调用 `find_package` / `find_library` 查找系统、ROS 2 或中台预编译好的 `.so`/`.a`；**第 2 优先级**在未找到预编译库时，探测指定的本地源码路径（如企业统一挂载的三方源码目录或 `third_party/`）并通过 `add_subdirectory` 源码编译。 |
| **`version.hpp` 与 `version.cpp.in` 动静分离** | 若将 Git Commit Hash 直接生成到公共头文件 `version.hpp` 中，每次 `git commit` 都会改变头文件时间戳与内容，导致全项目及下游 ROS 节点全量重编。将接口声明放在静态的 `version.hpp`，把动态 Hash 生成到内部 `src/core/version.cpp`，每次提交仅需 0.1 秒重编单个源文件并重链。 |
| **占位符用 `my_project` + `make init` 一键派生** | `template` 是 C++ 保留关键字，不能用作 `namespace` 且全局替换会破坏模板语法。采用无歧义的 `my_project` 配合 `make init NAME=xxx`，自动完成目录改名、配置文件更新与命名空间替换，杜绝手工改名遗漏。 |
| **Library-First 分层**（`include/` + `src/` 与 `apps/` 分离） | 核心算法、中台服务与 `client` 逻辑全部编译为独立目标 `my_project::my_project`，`apps/`（或外部的 ROS 2 Node 封装仓）只做极薄的入口壳层。这使得 `tests/`、`benchmarks/`、`examples/` 以及未来可能扩展的 Python 绑定都能零成本直接复用核心库。 |
| **公私头文件物理隔离**（`include/my_project/` vs `src/`） | 稳定对外 API 放入 `include/my_project/`，内部实现与通信细节头文件放入 `src/`（配合 PImpl 模式隐藏三方通信库头文件）。修改内部实现不会污染下游头文件依赖，大幅缩短大型 ROS 2 工作空间的增量编译时间。 |
| **`docs/` 仅对 `include/` 开启严格校验** | 对内部私有实现强制写 Doxygen 会造成严重研发负担。将校验范围精准收敛在 `include/` 公共接口目录，贯彻“**对外契约严苛、内部实现灵活**”的务实治理原则。 |

---

## 三、 核心功能清单

### 3.1 构建、低版本兼容与 ROS 2 导出能力

* **基线兼容与标准切换**：顶层声明 `cmake_minimum_required(VERSION 3.16)`，通过缓存变量 `MY_PROJECT_CXX_STANDARD` 统一管理语言标准（默认 `17` 以获得最佳 ROS 2 生态兼容性，支持 `-DMY_PROJECT_CXX_STANDARD=20` 一键切换），强制开启 `CMAKE_CXX_STANDARD_REQUIRED ON` 并关闭编译器私有扩展（`CMAKE_CXX_EXTENSIONS OFF`）。
* **兼容式顶层工程守卫（支持源码级被依赖）**：使用兼容 CMake 3.16 的判断逻辑定义 `MY_PROJECT_IS_TOP_LEVEL`（比较 `CMAKE_SOURCE_DIR` 与 `CMAKE_CURRENT_SOURCE_DIR`）。当本库被其他中台仓库以本地源码方式 `add_subdirectory()` 引入时，自动关闭 `apps/`、`tests/`、`benchmarks/`、`docs/`、`-Werror` 及根目录软链接写入，做到零副作用嵌套。
* **防源码内构建保护**：顶层 `CMakeLists.txt` 首行拦截 `CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR`，阻断误执行 `cmake .` 污染源码树及覆盖根目录 `Makefile`。
* **编译数据库与 `COLCON_IGNORE` 自动维护**：默认开启 `CMAKE_EXPORT_COMPILE_COMMANDS ON`。本地构建配置完成后自动在 `build/` 下写入 `COLCON_IGNORE`，并在仓库根目录维护指向当前构建目录的 `compile_commands.json` 软链接，保障 `clangd`、VS Code、CLion 与 `clang-tidy` 精准索引。
* **5 套标准化构建模式**（`Makefile` 原生支持 CMake 3.16+，并同步映射至 `CMakePresets.json`）：

| 模式 / Preset 名称 | 构建类型 | 核心参数与工程用途 |
| --- | --- | --- |
| `debug` | `Debug` | 开启严格编译警告与单元测试，用于日常研发与断点调试 |
| `release` | `Release` | 开启 `-O3`、IPO/LTO（探测编译器支持后开启）及 `benchmarks/`，用于发布与压测 |
| `relwithdebinfo` | `RelWithDebInfo` | 开启 `-O2 -g -fno-omit-frame-pointer`，专用于 `perf` 与火焰图性能剖析 |
| `asan-ubsan` | `Debug` | 注入 `-DUSE_SANITIZER="Address;Undefined"`，排查内存越界、泄漏与未定义行为 |
| `tsan` | `Debug` | 注入 `-DUSE_SANITIZER="Thread"`，专项排查多线程控制、状态机与异步通信的数据竞争 |

* **标准安装规则与 ROS 2 `colcon` 无缝导出**：基于 `GNUInstallDirs` 与 `CMakePackageConfigHelpers` 生成标准安装目录及 `my_projectConfig.cmake` / `my_projectConfigVersion.cmake`。无论通过 `cmake --install` 安装至系统/中台目录，还是放入 `ros2_ws/src/` 执行 `colcon build --packages-select my_project`，下游 CMake 或 `ament_cmake` 工程均可通过标准方式消费：
  ```cmake
  find_package(my_project REQUIRED)
  target_link_libraries(downstream_target PRIVATE my_project::my_project)
  ```

### 3.2 本地依赖解析机制（`cmake/Dependencies.cmake`）

完全面向企业本地环境设计，提供清晰的二级探测标准范式：
1. **第一级（优先查找本地预编译动/静态库）**：通过标准 `find_package(<Pkg> CONFIG QUIET)` 或 `find_package(<Pkg> MODULE QUIET)` 在 `CMAKE_PREFIX_PATH`、ROS 2 环境、Conda 环境及中台公共库路径中检索已编译好的动态链接库（`.so`）或静态链接库（`.a`），支持通过 `BUILD_SHARED_LIBS` 或显式开关控制动/静态链接偏好。
2. **第二级（回退编译本地受控源码）**：当本机尚未安装对应预编译包时，检查显式传入的 `MY_PROJECT_<PKG>_SOURCE_DIR` 或约定的本地源码仓路径（如 `/usr/src/googletest`、工作空间同级源码包或仓库内 `third_party/<pkg>`），若存在则自动通过 `add_subdirectory(... EXCLUDE_FROM_ALL)` 将源码纳入当前构建。

### 3.3 编译期警告与运行时 Sanitizer 防线

* **跨编译器高价值警告集（`CompilerWarnings.cmake`）**：针对 GCC / Clang 统一挂载 `-Wall -Wextra -Wpedantic -Wshadow -Wnon-virtual-dtor -Wold-style-cast -Wcast-align -Wunused -Woverloaded-virtual -Wconversion -Wsign-conversion -Wnull-dereference -Wdouble-promotion -Wformat=2`，以 `PRIVATE` 属性绑定至内部目标（不传染下游调用方），并提供 `MY_PROJECT_WARNINGS_AS_ERRORS` 开关（顶层开发默认开启，作为子模块被引入时自动关闭）。
* **动态检测器（`Sanitizers.cmake`）**：支持通过 `-DUSE_SANITIZER` 开启 `Address`、`Undefined`、`Thread`、`Leak`、`Memory` 及其合法组合，并在配置阶段自动拦截互斥组合（如 `Address` 与 `Thread` 同时开启时立即报错阻断）。

### 3.4 提交前强拦截门禁（`pre-commit`）、静态分析与文档校验

采用 `.pre-commit-config.yaml`（全部 `repo: local`，100% 离线执行），在 **`git commit` 阶段强制把关**，确保每一次提交均满足质量基线：

* **代码格式强校验（`clang-format`）**：对暂存区变更的 `.h` / `.hpp` / `.c` / `.cpp` 文件执行本机 `clang-format` 检查与格式化。
* **增量静态分析强拦截（`clang-tidy`）**：在 `commit` 前对暂存区变更代码执行严格静态检查，并内建两项防呆保障解决痛点：
  1. **编译数据库自动就绪**：若检测到根目录尚未生成 `compile_commands.json`（如刚克隆仓库修改后首次提交），门禁自动触发一次轻量 CMake Configure 生成编译数据库，避免因缺少文件报错中断。
  2. **头文件变更精准覆盖与边界隔离**：限定 `-header-filter=^(include|src)/` 屏蔽系统与三方库头文件噪声；当暂存区包含 `.cpp` 时直接增量扫描，当仅修改公共/私有 `.hpp` 头文件时自动关联对应编译参数执行检查，确保头文件改动同样受控。
* **公共 API 注释强门禁（Doxygen `check-docs`）**：当暂存区涉及 `include/` 目录下的公共头文件变更时，自动触发毫秒级的 `check-docs` 检查（`GENERATE_HTML=NO`、`WARN_IF_UNDOCUMENTED=YES`、`WARN_NO_PARAMDOC=YES`、`WARN_AS_ERROR=YES`），任何未注释的公开类、函数或参数不一致均直接阻断提交。
* **提交信息规范检查（`gitlint`）**：挂载于 `commit-msg` 钩子，强制规范团队提交日志格式（如 Conventional Commits）。

### 3.5 测试与性能基准骨架

* **单元测试（`tests/`）**：接入 `CTest`。通过 `Dependencies.cmake` 自动探测本地预编译 `GTest` 库或本机 `googletest` 源码（如 Ubuntu/ROS 2 环境自带的 `libgtest-dev` / `/usr/src/googletest`）；在极端裸机无 `GTest` 环境下提供标准 C++ 轻量测试宏兜底，保证任何环境下首次 `make test` 均能 100% 编译运行。
* **性能基准（`benchmarks/`）**：受 `MY_PROJECT_ENABLE_BENCHMARKS` 控制（默认 `OFF`，`release` 模式开启）。同样支持“本地预编译 `benchmark` 库 → 本地源码 → `std::chrono` 零依赖基准桩”三级探测。

### 3.6 统一本地命令入口（根目录 `Makefile`）

| 命令分类 | Make 指令 | 核心行为（全面兼容 CMake 3.16+） |
| --- | --- | --- |
| **引导与项目派生** | `make help` | 展示彩色分类命令说明菜单 |
|  | `make init NAME=<pkg>` | **一键派生新工程**：校验名称合法性后，自动重命名 `include/<pkg>`、`cmake/<pkg>Config.cmake.in`，并全局更新命名空间、CMake 目标、`package.xml` 与宏前缀 |
|  | `make install` | 检测本机/ROS 2/Conda 工具链完整性（缺失时给出安装提示，不执行侵入式 `sudo`），并挂载本地 `pre-commit` 与 `commit-msg` Git 钩子 |
| **构建与测试** | `make build` | 执行 `debug` 模式构建，自动写入 `build/COLCON_IGNORE` 并更新根目录 `compile_commands.json` 软链 |
|  | `make release` | 执行 `release` 模式优化构建（默认开启 `benchmarks/`） |
|  | `make test` | 运行 `build/debug` 下的全量 `ctest --output-on-failure` 单元测试 |
|  | `make bench` | 构建 `release` 并执行 `benchmarks/` 性能基准测试 |
|  | `make clean` | 清理本地 `build/` 构建目录与软链接 |
| **质量门禁与动态检测** | `make format` | 全库执行 `clang-format` 自动格式化（另提供 `make check-format` 只检不改） |
|  | `make tidy` | 对当前变更文件运行 `clang-tidy` 增量分析（另提供 `make tidy-all` 全量扫描） |
|  | `make doxygen` | 执行 `check-docs` 严格校验 `include/` 注释（另提供 `make docs` 生成本地离线 HTML 文档） |
|  | `make asan` / `make tsan` | 一键构建对应 Sanitizer 模式并执行全量单元测试，排查内存泄漏、越界与并发数据竞争 |
| **一键提交前全检** | `make check` | 串联执行：`check-format` → `build` → `test` → `doxygen` → `tidy`（与本地提交规范完全对齐） |
| **团队 AI 提效（可选）** | `make commit` / `review` / `push` / `summary` | 兼容调用 `.claude/commands/*.sh`（未放置 `.claude/` 目录时给出友好提示，不影响核心研发流） |

---

## 四、 适用场景与演进边界

### 4.1 核心适用场景

1. **机器人 ROS 2 中台核心模块（推荐 Core-Wrapper 模式）**
   将运动规划、控制律计算、状态机调度、定位融合或任务编排等核心逻辑基于本模板沉淀为纯 C++ 库（可独立调试、跑 `ASan/TSan` 与基准压测），既可直接置于 `ros2_ws/src/` 随 `colcon build` 一同编译，也可单独编译分发给上层 ROS 2 Node 仓库调用。
2. **仿真后台引擎与高性能算法库**
   适用于物理仿真、传感器模拟、数值求解等对单步耗时（Frame Time）和内存布局高度敏感的模块。独立的 `benchmarks/`、`relwithdebinfo` 火焰图预设以及 `.clang-tidy` 的零拷贝性能规则可直接护航性能调优。
3. **跨进程/跨团队 C++ 客户端 SDK 与基础组件**
   适用于对外提供通信客户端、硬件驱动封装或通用协议解析的基础库。通过 `include/my_project/client/` + PImpl 隔离底层依赖、Doxygen 公共头文件强门禁以及标准 `find_package` 导出，保障下游业务团队获得干净、文档齐全的集成体验。
4. **企业内网离线工作站、容器与预置依赖环境**
   适用于无公网访问权限、依赖由中台统一预编译或由内部源码仓集中管控的研发环境。

### 4.2 明确边界（V1 不覆盖范围）与后续演进规划

* **不包含任何云端 CI 与外发服务**：不内置 GitHub Actions、GitLab CI 编排脚本或 Codecov 上传逻辑。企业内部 CI 流水线接入时，可直接复用仓库现成的 `make check`、`make asan`、`make tsan` 命令，保证本地与流水线行为 100% 一致。
* **V1 暂不纳入代码覆盖率模块**：为保持 V1 模板极致精简与聚焦，本地及流水线代码覆盖率（`gcov` / `lcov` / `gcovr`）暂不在本版本引入，留待后续大版本按实际度量诉求独立演进。
* **坚决不引入外部网络包拉取器**：不内置 `CPM.cmake`、`FetchContent` 或特定包管理器锁文件，始终遵循企业“本地预编译动/静态库优先、本地受控源码编译兜底”的确定性构建原则。
* **聚焦 Linux + ROS 2 主力平台**：V1 针对 Linux（GCC / Clang）与 ROS 2 工具链深度打磨，避免掺杂 Windows / MSVC 跨平台条件分支带来的脚本复杂度。
