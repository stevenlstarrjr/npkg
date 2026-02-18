#include "pkg/commands.hpp"

#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#include "pkg/config.hpp"
#include "pkg/group.hpp"
#include "pkg/lockfile.hpp"
#include "pkg/port.hpp"
#include "pkg/resolver.hpp"

namespace pkg {
namespace {

void printUsage() {
  std::cout
      << "Usage:\n"
      << "  pkg validate [--root <path>]\n"
      << "  pkg resolve --group <name> [--root <path>]\n"
      << "  pkg resolve <port> [<port> ...] [--root <path>]\n"
      << "  pkg build --group <name> [--root <path>]\n"
      << "  pkg build <port> [<port> ...] [--root <path>]\n"
      << "  pkg apply [--root <path>]\n";
}

void printStatusError(const Status& status) {
  std::cerr << "error: " << status.message() << "\n";
}

std::string shellQuote(const std::string& value) {
  std::string out = "'";
  for (char c : value) {
    if (c == '\'') {
      out += "'\\''";
    } else {
      out.push_back(c);
    }
  }
  out.push_back('\'');
  return out;
}

std::string hashKey(std::string_view text) {
  const std::size_t h = std::hash<std::string_view>{}(text);
  std::ostringstream oss;
  oss << std::hex << std::setfill('0') << std::setw(16)
      << static_cast<unsigned long long>(h);
  return oss.str();
}

Status runCommandToLog(const std::string& command,
                       const std::filesystem::path& log_path) {
  const std::string shell_cmd =
      command + " >> " + shellQuote(log_path.string()) + " 2>&1";
  const int rc = std::system(shell_cmd.c_str());
  if (rc != 0) {
    return Status{StatusCode::kInternalError,
                  "Command failed: " + command + " (see " +
                      log_path.string() + ")"};
  }
  return Status::Ok();
}

Status prepareSource(const PortRecipe& recipe,
                     const std::filesystem::path& src_dir,
                     const std::filesystem::path& downloads_dir,
                     const std::filesystem::path& log_path) {
  std::error_code ec;
  std::filesystem::create_directories(src_dir, ec);
  if (ec) {
    return Status{StatusCode::kIoError,
                  "Failed to create source dir: " + src_dir.string()};
  }

  if (recipe.src.type == "git") {
    if (recipe.src.url.empty()) {
      return Status::Ok();
    }
    const auto git_dir = src_dir / ".git";
    if (!std::filesystem::exists(git_dir)) {
      return runCommandToLog(
          "git clone --depth 1 " + shellQuote(recipe.src.url) + " " +
              shellQuote(src_dir.string()),
          log_path);
    }
    auto s = runCommandToLog("git -C " + shellQuote(src_dir.string()) +
                                 " fetch --depth 1 origin",
                             log_path);
    if (!s.ok()) {
      return s;
    }
    return runCommandToLog("git -C " + shellQuote(src_dir.string()) +
                               " reset --hard origin/HEAD",
                           log_path);
  }

  if (recipe.src.type == "url") {
    if (recipe.src.url.empty()) {
      return Status::Ok();
    }
    std::filesystem::create_directories(downloads_dir, ec);
    if (ec) {
      return Status{StatusCode::kIoError,
                    "Failed to create downloads dir: " + downloads_dir.string()};
    }
    std::string filename = "source.tar";
    const auto slash = recipe.src.url.find_last_of('/');
    if (slash != std::string::npos && slash + 1 < recipe.src.url.size()) {
      filename = recipe.src.url.substr(slash + 1);
    }
    const auto archive_path =
        downloads_dir / (recipe.name + "-" + recipe.version + "-" + filename);

    std::string fetch_cmd;
    fetch_cmd = "(command -v fetch >/dev/null 2>&1 && fetch -o " +
                shellQuote(archive_path.string()) + " " +
                shellQuote(recipe.src.url) +
                ") || (command -v curl >/dev/null 2>&1 && curl -LfsS -o " +
                shellQuote(archive_path.string()) + " " +
                shellQuote(recipe.src.url) + ")";
    auto s = runCommandToLog(fetch_cmd, log_path);
    if (!s.ok()) {
      return s;
    }

    if (!recipe.src.sha256.empty()) {
      s = runCommandToLog(
          "test \"$(sha256 -q " + shellQuote(archive_path.string()) +
              ")\" = " + shellQuote(recipe.src.sha256),
          log_path);
      if (!s.ok()) {
        return Status{StatusCode::kInternalError,
                      "sha256 mismatch for " + archive_path.string()};
      }
    }

    std::filesystem::remove_all(src_dir, ec);
    ec.clear();
    std::filesystem::create_directories(src_dir, ec);
    if (ec) {
      return Status{StatusCode::kIoError,
                    "Failed to prepare source dir: " + src_dir.string()};
    }

    return runCommandToLog(
        "tar -xf " + shellQuote(archive_path.string()) + " -C " +
            shellQuote(src_dir.string()) + " --strip-components=1",
        log_path);
  }

  if (recipe.src.type.empty()) {
    return Status::Ok();
  }

  return Status{StatusCode::kInvalidArgument,
                "Unsupported src.type for " + recipe.name + ": " +
                    recipe.src.type};
}

Status runScript(const std::filesystem::path& script_path,
                 const std::filesystem::path& log_path,
                 const PortRecipe& recipe,
                 const std::filesystem::path& root,
                 const std::filesystem::path& src_dir,
                 const std::filesystem::path& build_dir,
                 const std::filesystem::path& store_dir,
                 int jobs) {
  std::ostringstream cmd;
  cmd << "env "
      << "PKG_NAME=" << shellQuote(recipe.name) << " "
      << "PKG_VERSION=" << shellQuote(recipe.version) << " "
      << "PKG_ROOT=" << shellQuote(root.string()) << " "
      << "PKG_SRC_DIR=" << shellQuote(src_dir.string()) << " "
      << "PKG_BUILD_DIR=" << shellQuote(build_dir.string()) << " "
      << "PKG_STORE_DIR=" << shellQuote(store_dir.string()) << " "
      << "PKG_JOBS=" << shellQuote(std::to_string(jobs)) << " "
      << "/bin/sh " << shellQuote(script_path.string())
      << " >> " << shellQuote(log_path.string()) << " 2>&1";

  return runCommandToLog(cmd.str(), log_path);
}

std::filesystem::path parseRoot(const std::vector<std::string>& args) {
  for (size_t i = 0; i + 1 < args.size(); ++i) {
    if (args[i] == "--root") {
      return args[i + 1];
    }
  }
  return std::filesystem::current_path();
}

std::string parseGroup(const std::vector<std::string>& args) {
  for (size_t i = 0; i + 1 < args.size(); ++i) {
    if (args[i] == "--group") {
      return args[i + 1];
    }
  }
  return {};
}

std::vector<std::string> parsePortTargets(const std::vector<std::string>& args) {
  std::vector<std::string> ports;
  for (size_t i = 1; i < args.size(); ++i) {
    if (args[i] == "--group" || args[i] == "--root") {
      ++i;
      continue;
    }
    if (!args[i].empty() && args[i][0] == '-') {
      continue;
    }
    ports.push_back(args[i]);
  }
  return ports;
}

int runValidate(const std::filesystem::path& root) {
  auto cfg = ConfigStore::load(root);
  if (!cfg.ok()) {
    printStatusError(cfg.status());
    return 1;
  }
  auto s = ConfigStore::validate(root);
  if (!s.ok()) {
    printStatusError(s);
    return 1;
  }
  s = GroupStore::validateAll(root, cfg.value());
  if (!s.ok()) {
    printStatusError(s);
    return 1;
  }
  s = PortStore::validateAll(root, cfg.value());
  if (!s.ok()) {
    printStatusError(s);
    return 1;
  }
  std::cout << "validate: ok\n";
  return 0;
}

Result<ResolveResult> resolveFromArgs(const std::filesystem::path& root,
                                      const std::vector<std::string>& args,
                                      Config* out_cfg,
                                      Group* out_group) {
  auto cfg = ConfigStore::load(root);
  if (!cfg.ok()) {
    return cfg.status();
  }
  Group resolved_group;
  std::string group_name = parseGroup(args);
  if (!group_name.empty()) {
    auto group = GroupStore::loadByName(root, cfg.value(), group_name);
    if (!group.ok()) {
      return group.status();
    }
    resolved_group = group.value();
  } else {
    auto ports = parsePortTargets(args);
    if (ports.empty()) {
      return Status{StatusCode::kInvalidArgument,
                    "Provide --group <name> or one or more port names"};
    }
    resolved_group.name = "adhoc";
    resolved_group.summary = "ad-hoc targets";
    resolved_group.ports = std::move(ports);
  }

  auto resolved = Resolver::resolveGroup(root, cfg.value(), resolved_group);
  if (!resolved.ok()) {
    return resolved.status();
  }

  if (out_cfg) {
    *out_cfg = cfg.value();
  }
  if (out_group) {
    *out_group = resolved_group;
  }

  return resolved;
}

int runResolve(const std::filesystem::path& root,
               const std::vector<std::string>& args) {
  auto resolved = resolveFromArgs(root, args, nullptr, nullptr);
  if (!resolved.ok()) {
    printStatusError(resolved.status());
    return 1;
  }

  std::cout << "resolved order:\n";
  for (const auto& name : resolved.value().order) {
    const auto& recipe = resolved.value().nodes.at(name).recipe;
    std::cout << "  - " << recipe.name << "@" << recipe.version
              << " (" << recipe.build.system << ")\n";
  }
  return 0;
}

int runBuild(const std::filesystem::path& root,
             const std::vector<std::string>& args) {
  Config cfg;
  Group group;
  auto resolved = resolveFromArgs(root, args, &cfg, &group);
  if (!resolved.ok()) {
    printStatusError(resolved.status());
    return 1;
  }

  Lockfile lock;
  lock.schema = 1;
  lock.state = "planned";
  for (const auto& name : resolved.value().order) {
    const auto& recipe = resolved.value().nodes.at(name).recipe;
    LockEntry entry;
    entry.name = recipe.name;
    entry.version = recipe.version;
    entry.status = "planned";
    entry.recipe = std::filesystem::relative(recipe.recipe_path, root).string();
    entry.store = cfg.layout.store_dir + "/" +
                  hashKey(recipe.name + "@" + recipe.version).substr(0, 12) +
                  "-" + recipe.name + "-" + recipe.version;
    entry.deps = recipe.deps;
    lock.entries.push_back(std::move(entry));
  }

  const auto logs_dir = root / cfg.layout.build_dir / "logs";
  std::error_code ec;
  std::filesystem::create_directories(logs_dir, ec);
  if (ec) {
    printStatusError(Status{StatusCode::kIoError,
                            "Failed to create logs dir: " + logs_dir.string()});
    return 1;
  }

  bool has_failure = false;
  const int jobs = std::max(1u, std::thread::hardware_concurrency());
  int built_count = 0;
  int reused_count = 0;
  int failed_count = 0;
  int skipped_count = 0;
  int planned_count = 0;
  for (size_t i = 0; i < lock.entries.size(); ++i) {
    auto& entry = lock.entries[i];
    const auto& recipe = resolved.value().nodes.at(entry.name).recipe;
    const auto recipe_dir = recipe.recipe_path.parent_path();
    const auto src_dir =
        root / cfg.layout.build_dir / "src" / (recipe.name + "-" + recipe.version);
    const auto build_dir =
        root / cfg.layout.build_dir / (recipe.name + "-" + recipe.version);
    const auto downloads_dir = root / cfg.layout.build_dir / "downloads";
    const auto store_dir = root / entry.store;
    const auto log_path =
        logs_dir / (recipe.name + "-" + recipe.version + ".log");

    if (has_failure) {
      entry.status = "skipped";
      ++skipped_count;
      continue;
    }

    if (std::filesystem::exists(store_dir) &&
        !std::filesystem::is_empty(store_dir, ec)) {
      entry.status = "reused";
      ++reused_count;
      continue;
    }

    std::filesystem::create_directories(src_dir, ec);
    if (ec) {
      entry.status = "failed";
      has_failure = true;
      ++failed_count;
      continue;
    }
    std::filesystem::remove_all(build_dir, ec);
    ec.clear();
    std::filesystem::create_directories(build_dir, ec);
    if (ec) {
      entry.status = "failed";
      has_failure = true;
      ++failed_count;
      continue;
    }
    std::filesystem::remove_all(store_dir, ec);
    ec.clear();
    std::filesystem::create_directories(store_dir, ec);
    if (ec) {
      entry.status = "failed";
      has_failure = true;
      ++failed_count;
      continue;
    }

    const auto patch_script = recipe.scripts.patch.empty()
                                  ? std::filesystem::path{}
                                  : recipe_dir / recipe.scripts.patch;
    const auto build_script = recipe_dir / recipe.scripts.build;
    const auto install_script = recipe_dir / recipe.scripts.install;
    const auto check_script = recipe.scripts.check.empty()
                                  ? std::filesystem::path{}
                                  : recipe_dir / recipe.scripts.check;

    {
      auto s = prepareSource(recipe, src_dir, downloads_dir, log_path);
      if (!s.ok()) {
        entry.status = "failed";
        has_failure = true;
        ++failed_count;
        continue;
      }
    }

    if (!patch_script.empty()) {
      auto s = runScript(patch_script, log_path, recipe, root, src_dir, build_dir,
                         store_dir, jobs);
      if (!s.ok()) {
        entry.status = "failed";
        has_failure = true;
        ++failed_count;
        continue;
      }
    }
    {
      auto s = runScript(build_script, log_path, recipe, root, src_dir, build_dir,
                         store_dir, jobs);
      if (!s.ok()) {
        entry.status = "failed";
        has_failure = true;
        ++failed_count;
        continue;
      }
    }
    {
      auto s = runScript(install_script, log_path, recipe, root, src_dir,
                         build_dir, store_dir, jobs);
      if (!s.ok()) {
        entry.status = "failed";
        has_failure = true;
        ++failed_count;
        continue;
      }
    }
    if (!check_script.empty()) {
      auto s = runScript(check_script, log_path, recipe, root, src_dir, build_dir,
                         store_dir, jobs);
      if (!s.ok()) {
        entry.status = "failed";
        has_failure = true;
        ++failed_count;
        continue;
      }
    }

    entry.status = "built";
    ++built_count;
  }

  for (const auto& entry : lock.entries) {
    if (entry.status == "planned") {
      ++planned_count;
    }
  }

  lock.state = has_failure ? "failed" : "done";
  auto save = LockfileStore::save(root, cfg, lock);
  if (!save.ok()) {
    printStatusError(save);
    return 1;
  }

  std::cout << "build: processed " << lock.entries.size() << " ports into "
            << (root / cfg.layout.lockfile).string() << "\n";
  std::cout << "build: built=" << built_count
            << " reused=" << reused_count
            << " failed=" << failed_count
            << " skipped=" << skipped_count
            << " planned=" << planned_count << "\n";
  return has_failure ? 1 : 0;
}

int runApply(const std::filesystem::path& root) {
  auto cfg = ConfigStore::load(root);
  if (!cfg.ok()) {
    printStatusError(cfg.status());
    return 1;
  }
  auto lock = LockfileStore::load(root, cfg.value());
  if (!lock.ok()) {
    printStatusError(lock.status());
    return 1;
  }

  std::cout << "apply: read " << lock.value().entries.size() << " lock entries\n";
  std::cout << "apply: target profile " << cfg.value().profile.activate_target << "\n";
  std::cout << "apply: activation symlink " << cfg.value().profile.activate_symlink << "\n";
  std::cout << "apply: note: symlink-tree materialization is not yet implemented\n";
  return 0;
}

}  // namespace

int Commands::run(int argc, char** argv) {
  if (argc < 2) {
    printUsage();
    return 1;
  }

  std::vector<std::string> args;
  args.reserve(static_cast<size_t>(argc));
  for (int i = 1; i < argc; ++i) {
    args.emplace_back(argv[i]);
  }

  const std::string command = args[0];
  const auto root = parseRoot(args);

  if (command == "validate") {
    return runValidate(root);
  }
  if (command == "resolve") {
    return runResolve(root, args);
  }
  if (command == "build") {
    return runBuild(root, args);
  }
  if (command == "apply") {
    return runApply(root);
  }
  if (command == "--help" || command == "help") {
    printUsage();
    return 0;
  }

  std::cerr << "Unknown command: " << command << "\n";
  printUsage();
  return 1;
}

}  // namespace pkg
