#include "pkg/group.hpp"

#include <filesystem>

#include "toml_util.hpp"

namespace pkg {
namespace {

Result<Group> loadGroupFromPath(const std::filesystem::path& path) {
  auto parsed = toml_util::parseFile(path);
  if (!parsed.ok()) {
    return parsed.status();
  }

  Group group;
  const toml::Datum top = parsed.value().toptab();
  group.name = toml_util::getString(top, "name").value_or(path.stem().string());
  group.summary = toml_util::getString(top, "summary").value_or(std::string{});

  auto ports = toml_util::getStringArray(top, "ports");
  if (!ports.ok()) {
    return Status{ports.status().code(),
                  ports.status().message() + " in " + path.string()};
  }
  group.ports = std::move(ports.value());
  if (group.ports.empty()) {
    return Status{StatusCode::kParseError,
                  "Group has no ports: " + path.string()};
  }
  return group;
}

}  // namespace

Result<Group> GroupStore::loadByName(const std::filesystem::path& root,
                                     const Config& config,
                                     std::string_view group_name) {
  const auto path = root / config.layout.groups_dir / (std::string(group_name) + ".toml");
  if (!std::filesystem::exists(path)) {
    return Status{StatusCode::kNotFound,
                  "Group file not found: " + path.string()};
  }
  return loadGroupFromPath(path);
}

Status GroupStore::validateAll(const std::filesystem::path& root,
                               const Config& config) {
  const auto groups_dir = root / config.layout.groups_dir;
  if (!std::filesystem::exists(groups_dir)) {
    return Status{StatusCode::kNotFound,
                  "Groups directory not found: " + groups_dir.string()};
  }

  for (const auto& entry : std::filesystem::directory_iterator(groups_dir)) {
    if (!entry.is_regular_file() || entry.path().extension() != ".toml") {
      continue;
    }
    auto group = loadGroupFromPath(entry.path());
    if (!group.ok()) {
      return group.status();
    }
  }
  return Status::Ok();
}

}  // namespace pkg
