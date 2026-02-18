#include "pkg/commands.hpp"

#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

#include "pkg/config.hpp"
#include "pkg/group.hpp"
#include "pkg/lockfile.hpp"
#include "pkg/resolver.hpp"

namespace pkg {
namespace {

void printUsage() {
  std::cout
      << "Usage:\n"
      << "  pkg validate [--root <path>]\n"
      << "  pkg resolve --group <name> [--root <path>]\n"
      << "  pkg build --group <name> [--root <path>]\n"
      << "  pkg apply [--root <path>]\n";
}

void printStatusError(const Status& status) {
  std::cerr << "error: " << status.message() << "\n";
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
  std::string group_name = parseGroup(args);
  if (group_name.empty()) {
    return Status{StatusCode::kInvalidArgument,
                  "--group <name> is required"};
  }

  auto group = GroupStore::loadByName(root, cfg.value(), group_name);
  if (!group.ok()) {
    return group.status();
  }

  auto resolved = Resolver::resolveGroup(root, cfg.value(), group.value());
  if (!resolved.ok()) {
    return resolved.status();
  }

  if (out_cfg) {
    *out_cfg = cfg.value();
  }
  if (out_group) {
    *out_group = group.value();
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
    entry.store = cfg.layout.store_dir + "/<hash>-" + recipe.name + "-" + recipe.version;
    entry.deps = recipe.deps;
    lock.entries.push_back(std::move(entry));
  }

  auto save = LockfileStore::save(root, cfg, lock);
  if (!save.ok()) {
    printStatusError(save);
    return 1;
  }

  std::cout << "build: planned " << lock.entries.size() << " ports into "
            << (root / cfg.layout.lockfile).string() << "\n";
  return 0;
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
