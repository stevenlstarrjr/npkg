#pragma once

#include <filesystem>
#include <string>
#include <vector>

#include "pkg/config.hpp"
#include "pkg/result.hpp"

namespace pkg {

struct LockEntry {
  std::string name;
  std::string version;
  std::string status;
  std::string recipe;
  std::vector<std::string> deps;
  std::string store;
};

struct Lockfile {
  int schema = 1;
  std::string state;
  std::vector<LockEntry> entries;
};

class LockfileStore {
 public:
  static Result<Lockfile> load(const std::filesystem::path& root,
                               const Config& config);
  static Status save(const std::filesystem::path& root,
                     const Config& config,
                     const Lockfile& lockfile);
};

}  // namespace pkg
