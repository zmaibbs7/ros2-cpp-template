SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# ------------------------------------------------------------------------------
# 全局参数（兼容 CMake 3.16+，无需强依赖 CMakePresets CLI）
# ------------------------------------------------------------------------------
CXX_STD       ?= 17
JOBS          ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
CMAKE_GEN     := $(if $(shell command -v ninja 2>/dev/null),-G Ninja,)
BUILD_ROOT    := build
DEBUG_DIR     := $(BUILD_ROOT)/debug
RELEASE_DIR   := $(BUILD_ROOT)/release
RELDBG_DIR    := $(BUILD_ROOT)/relwithdebinfo
ASAN_DIR      := $(BUILD_ROOT)/asan-ubsan
TSAN_DIR      := $(BUILD_ROOT)/tsan

CPP_DIRS      := include src apps tests benchmarks examples
CPP_FILES     := $(shell find $(CPP_DIRS) -type f \( -name '*.h' -o -name '*.hpp' -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' \) 2>/dev/null | sort)
SRC_CPP_FILES := $(shell find src apps tests benchmarks examples -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' \) 2>/dev/null | sort)

# 终端颜色
CYAN   := \033[36m
GREEN  := \033[32m
YELLOW := \033[33m
RED    := \033[31m
BOLD   := \033[1m
RESET  := \033[0m

.PHONY: help init install build release relwithdebinfo test bench clean \
        format check-format tidy tidy-all doxygen docs asan tsan check \
        commit review push summary

# 内部复用：确保 build/COLCON_IGNORE 存在并刷新根目录 compile_commands.json 软链
define ensure_build_env
	@mkdir -p $(BUILD_ROOT)
	@touch $(BUILD_ROOT)/COLCON_IGNORE
endef

define link_compile_commands
	@if [ -f "$(1)/compile_commands.json" ]; then \
		ln -sfn "$(1)/compile_commands.json" compile_commands.json; \
	fi
endef

# ==============================================================================
# 1. 引导与项目派生
# ==============================================================================
help: ## 展示彩色分类命令帮助菜单
	@printf "$(BOLD)$(CYAN)my_project — Modern C++ (ROS 2 Middleware) 工程命令行入口$(RESET)\n\n"
	@printf "$(BOLD)常用参数:$(RESET) CXX_STD=17|20 (当前: $(CXX_STD)), JOBS=$(JOBS)\n\n"
	@printf "$(BOLD)$(GREEN)[引导与项目派生]$(RESET)\n"
	@printf "  $(CYAN)make help$(RESET)                   展示本帮助菜单\n"
	@printf "  $(CYAN)make init NAME=<pkg>$(RESET)        一键派生新工程（替换命名空间/目录/package.xml/宏前缀）\n"
	@printf "  $(CYAN)make install$(RESET)                检查本地工具链完整性并挂载离线 Git hooks（不执行 sudo）\n\n"
	@printf "$(BOLD)$(GREEN)[构建与测试]$(RESET)\n"
	@printf "  $(CYAN)make build$(RESET)                  Debug 模式构建并更新 compile_commands.json 软链\n"
	@printf "  $(CYAN)make release$(RESET)                Release 模式优化构建（含 IPO 与 benchmarks）\n"
	@printf "  $(CYAN)make relwithdebinfo$(RESET)         RelWithDebInfo 构建（供 perf / 火焰图剖析）\n"
	@printf "  $(CYAN)make test$(RESET)                   运行 Debug 模式全量单元测试 (CTest)\n"
	@printf "  $(CYAN)make bench$(RESET)                  编译 Release 并执行性能基准测试\n"
	@printf "  $(CYAN)make clean$(RESET)                  清理 build/ 构建产物与软链接\n\n"
	@printf "$(BOLD)$(GREEN)[质量门禁与动态检测]$(RESET)\n"
	@printf "  $(CYAN)make format$(RESET)                 使用 clang-format 格式化全库源码\n"
	@printf "  $(CYAN)make check-format$(RESET)           只检不改：校验全库代码格式是否合规\n"
	@printf "  $(CYAN)make tidy$(RESET)                   对暂存区/工作区变更文件运行 clang-tidy 增量分析\n"
	@printf "  $(CYAN)make tidy-all$(RESET)               全量运行 clang-tidy 静态分析\n"
	@printf "  $(CYAN)make doxygen$(RESET)                严格校验 include/ 公共头文件 Doxygen 注释\n"
	@printf "  $(CYAN)make docs$(RESET)                   生成本地离线 HTML API 文档\n"
	@printf "  $(CYAN)make asan$(RESET)                   ASan + UBSan 构建并运行全量单测\n"
	@printf "  $(CYAN)make tsan$(RESET)                   TSan 构建并运行全量单测（并发数据竞争排查）\n"
	@printf "  $(CYAN)make check$(RESET)                  一键提交前全检：check-format -> build -> test -> doxygen -> tidy\n\n"
	@printf "$(BOLD)$(GREEN)[团队 AI 提效（可选）]$(RESET)\n"
	@printf "  $(CYAN)make commit | review | push | summary$(RESET)   调用 .claude/commands/*.sh\n"

define INIT_PY
import os, pathlib, shutil, sys
new_lower = sys.argv[1]
new_upper = new_lower.upper()
root = pathlib.Path(".")
skip_dirs = {".git", "build", "install", "log", ".cache"}
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in skip_dirs]
    for fname in filenames:
        fpath = pathlib.Path(dirpath) / fname
        if fpath.name == "README.md":
            continue
        try:
            text = fpath.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        updated = text.replace("my_project", new_lower).replace("MY_PROJECT", new_upper)
        if updated != text:
            fpath.write_text(updated, encoding="utf-8")
inc_old = root / "include" / "my_project"
inc_new = root / "include" / new_lower
if inc_old.exists():
    shutil.move(str(inc_old), str(inc_new))
cfg_old = root / "cmake" / "my_projectConfig.cmake.in"
cfg_new = root / "cmake" / f"{new_lower}Config.cmake.in"
if cfg_old.exists():
    shutil.move(str(cfg_old), str(cfg_new))
endef
export INIT_PY

init: ## 一键派生新工程：make init NAME=motion_planner
	@if [ -z "$(NAME)" ]; then \
		printf "$(RED)[ERROR]$(RESET) 请指定新项目名，例如: make init NAME=motion_planner\n"; \
		exit 1; \
	fi
	@if ! printf '%s' "$(NAME)" | grep -Eq '^[a-z][a-z0-9_]*$$'; then \
		printf "$(RED)[ERROR]$(RESET) 项目名 '$(NAME)' 不合法，必须匹配 ^[a-z][a-z0-9_]*$$（小写字母开头，仅含小写字母、数字和下划线）\n"; \
		exit 1; \
	fi
	@if [ "$(NAME)" = "my_project" ]; then \
		printf "$(YELLOW)[WARN]$(RESET) 项目名仍为 my_project，无需替换。\n"; \
		exit 0; \
	fi
	@command -v python3 >/dev/null 2>&1 || { printf "$(RED)[ERROR]$(RESET) make init 需要 python3。\n"; exit 1; }
	@python3 -c "$$INIT_PY" "$(NAME)"
	@printf "$(GREEN)[OK]$(RESET) 已将工程派生为 '$(NAME)'（包含目录、命名空间、宏前缀、CMake 目标及 package.xml）。\n"

install: ## 检查本地工具链完整性并安装本地 Git hooks（不执行 sudo）
	@printf "$(BOLD)>>> 检查本地研发工具链...$(RESET)\n"
	@for tool in cmake g++ make clang-format clang-tidy doxygen pre-commit gitlint; do \
		if command -v $$tool >/dev/null 2>&1; then \
			printf "  $(GREEN)[OK]$(RESET)      %-14s -> %s\n" "$$tool" "$$(command -v $$tool)"; \
		else \
			printf "  $(YELLOW)[MISSING]$(RESET) %-14s\n" "$$tool"; \
		fi; \
	done
	@printf "\n$(BOLD)提示：$(RESET)若缺失可选工具，可按需通过系统包管理器或 Conda 安装（本命令不执行 sudo）：\n"
	@printf "  apt:   sudo apt-get install -y clang-format clang-tidy doxygen\n"
	@printf "  pip:   pip install --user pre-commit gitlint\n\n"
	@if [ -d .git ] && command -v pre-commit >/dev/null 2>&1; then \
		pre-commit install --hook-type pre-commit --hook-type commit-msg; \
		printf "$(GREEN)[OK]$(RESET) 已安装本地离线 Git hooks。\n"; \
	elif [ ! -d .git ]; then \
		printf "$(YELLOW)[INFO]$(RESET) 当前目录尚未初始化 Git 仓库，跳过 hook 挂载（git init 后再执行 make install）。\n"; \
	else \
		printf "$(YELLOW)[INFO]$(RESET) 未检测到 pre-commit，跳过 hook 挂载。\n"; \
	fi

# ==============================================================================
# 2. 构建与测试
# ==============================================================================
build: ## Debug 模式构建并刷新 compile_commands.json
	$(ensure_build_env)
	cmake $(if $(wildcard $(DEBUG_DIR)/CMakeCache.txt),,$(CMAKE_GEN)) -S . -B $(DEBUG_DIR) \
		-DCMAKE_BUILD_TYPE=Debug \
		-DMY_PROJECT_CXX_STANDARD=$(CXX_STD) \
		-DMY_PROJECT_BUILD_TESTS=ON \
		-DMY_PROJECT_WARNINGS_AS_ERRORS=ON
	cmake --build $(DEBUG_DIR) -j $(JOBS)
	$(call link_compile_commands,$(DEBUG_DIR))

release: ## Release 模式优化构建（含 IPO 与 benchmarks）
	$(ensure_build_env)
	cmake $(if $(wildcard $(RELEASE_DIR)/CMakeCache.txt),,$(CMAKE_GEN)) -S . -B $(RELEASE_DIR) \
		-DCMAKE_BUILD_TYPE=Release \
		-DMY_PROJECT_CXX_STANDARD=$(CXX_STD) \
		-DMY_PROJECT_ENABLE_IPO=ON \
		-DMY_PROJECT_ENABLE_BENCHMARKS=ON
	cmake --build $(RELEASE_DIR) -j $(JOBS)
	$(call link_compile_commands,$(RELEASE_DIR))

relwithdebinfo: ## RelWithDebInfo 构建（供 perf / 火焰图剖析）
	$(ensure_build_env)
	cmake $(if $(wildcard $(RELDBG_DIR)/CMakeCache.txt),,$(CMAKE_GEN)) -S . -B $(RELDBG_DIR) \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DMY_PROJECT_CXX_STANDARD=$(CXX_STD) \
		-DCMAKE_CXX_FLAGS_RELWITHDEBINFO="-O2 -g -fno-omit-frame-pointer"
	cmake --build $(RELDBG_DIR) -j $(JOBS)
	$(call link_compile_commands,$(RELDBG_DIR))

test: build ## 运行 Debug 模式全量单元测试
	cd $(DEBUG_DIR) && ctest --output-on-failure

bench: release ## 编译 Release 并运行性能基准测试
	./$(RELEASE_DIR)/benchmarks/bench_engine

clean: ## 清理本地 build/ 目录与 compile_commands.json 软链
	rm -rf $(BUILD_ROOT) compile_commands.json

# ==============================================================================
# 3. 规范检查、静态分析与动态检测
# ==============================================================================
format: ## 使用 clang-format 自动格式化全库代码
	@command -v clang-format >/dev/null 2>&1 || { printf "$(RED)[ERROR]$(RESET) 未找到 clang-format\n"; exit 1; }
	@if [ -n "$(CPP_FILES)" ]; then clang-format -i $(CPP_FILES); fi
	@printf "$(GREEN)[OK]$(RESET) 格式化完成。\n"

check-format: ## 只检不改：检查全库代码风格
	@command -v clang-format >/dev/null 2>&1 || { printf "$(RED)[ERROR]$(RESET) 未找到 clang-format\n"; exit 1; }
	@if [ -n "$(CPP_FILES)" ]; then clang-format --dry-run --Werror $(CPP_FILES); fi
	@printf "$(GREEN)[OK]$(RESET) 代码风格校验通过。\n"

tidy: ## 对变更文件运行增量 clang-tidy 分析
	@if ! command -v clang-tidy >/dev/null 2>&1; then \
		printf "$(YELLOW)[SKIP]$(RESET) 未检测到 clang-tidy，跳过静态分析。\n"; \
	else \
		if [ ! -f "$(DEBUG_DIR)/compile_commands.json" ]; then $(MAKE) build; fi; \
		changed=""; \
		if [ -d .git ]; then \
			changed=$$(git diff --name-only --diff-filter=ACMR HEAD -- src apps tests benchmarks examples 2>/dev/null | grep -E '\.(c|cc|cpp)$$' || true); \
		fi; \
		if [ -z "$$changed" ]; then \
			printf "$(CYAN)[INFO]$(RESET) 未检测到变更的 .cpp 文件，改用全量核心源码扫描...\n"; \
			clang-tidy -p $(DEBUG_DIR) --header-filter='^(include|src)/' $(SRC_CPP_FILES); \
		else \
			clang-tidy -p $(DEBUG_DIR) --header-filter='^(include|src)/' $$changed; \
		fi; \
	fi

tidy-all: ## 对全库源码运行 clang-tidy 静态分析
	@command -v clang-tidy >/dev/null 2>&1 || { printf "$(RED)[ERROR]$(RESET) 未找到 clang-tidy\n"; exit 1; }
	@if [ ! -f "$(DEBUG_DIR)/compile_commands.json" ]; then $(MAKE) build; fi
	clang-tidy -p $(DEBUG_DIR) --header-filter='^(include|src)/' $(SRC_CPP_FILES)

doxygen: ## 严格校验 include/ 公共头文件注释
	@if ! command -v doxygen >/dev/null 2>&1; then \
		printf "$(YELLOW)[SKIP]$(RESET) 未检测到 doxygen，跳过注释校验。\n"; \
	else \
		if [ ! -f "$(DEBUG_DIR)/docs/Doxyfile.check" ]; then $(MAKE) build; fi; \
		cmake --build $(DEBUG_DIR) --target check-docs; \
	fi

docs: ## 生成本地离线 HTML API 文档
	@command -v doxygen >/dev/null 2>&1 || { printf "$(RED)[ERROR]$(RESET) 未找到 doxygen\n"; exit 1; }
	@if [ ! -f "$(DEBUG_DIR)/docs/Doxyfile.html" ]; then \
		$(MAKE) build; \
	fi
	cmake --build $(DEBUG_DIR) --target docs
	@printf "$(GREEN)[OK]$(RESET) HTML 文档已生成至 $(DEBUG_DIR)/docs/html/index.html\n"

asan: ## ASan + UBSan 构建并运行全量单测
	$(ensure_build_env)
	cmake $(if $(wildcard $(ASAN_DIR)/CMakeCache.txt),,$(CMAKE_GEN)) -S . -B $(ASAN_DIR) \
		-DCMAKE_BUILD_TYPE=Debug \
		-DMY_PROJECT_CXX_STANDARD=$(CXX_STD) \
		-DUSE_SANITIZER="Address;Undefined"
	cmake --build $(ASAN_DIR) -j $(JOBS)
	cd $(ASAN_DIR) && ctest --output-on-failure

tsan: ## TSan 构建并运行全量单测
	$(ensure_build_env)
	cmake $(if $(wildcard $(TSAN_DIR)/CMakeCache.txt),,$(CMAKE_GEN)) -S . -B $(TSAN_DIR) \
		-DCMAKE_BUILD_TYPE=Debug \
		-DMY_PROJECT_CXX_STANDARD=$(CXX_STD) \
		-DUSE_SANITIZER="Thread"
	cmake --build $(TSAN_DIR) -j $(JOBS)
	cd $(TSAN_DIR) && ctest --output-on-failure

check: check-format build test doxygen tidy ## 一键提交前自检
	@printf "$(GREEN)$(BOLD)[PASS] 本地提交前全量自检通过！$(RESET)\n"

# ==============================================================================
# 4. 团队 AI 辅助命令（可选）
# ==============================================================================
commit review push summary:
	@if [ -x ".claude/commands/$@.sh" ]; then \
		./.claude/commands/$@.sh; \
	else \
		printf "$(YELLOW)[INFO]$(RESET) 未检测到 .claude/commands/$@.sh，跳过团队可选 AI 命令。\n"; \
	fi
