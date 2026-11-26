/**
 * @file version.hpp
 * @brief Semantic version and build metadata query interface.
 */

#ifndef MY_PROJECT_VERSION_HPP
#define MY_PROJECT_VERSION_HPP

#include <string_view>

/**
 * @brief Root namespace for the my_project library.
 */
namespace my_project {

/**
 * @brief Return the major semantic version number.
 * @return Major version integer.
 */
int version_major() noexcept;

/**
 * @brief Return the minor semantic version number.
 * @return Minor version integer.
 */
int version_minor() noexcept;

/**
 * @brief Return the patch semantic version number.
 * @return Patch version integer.
 */
int version_patch() noexcept;

/**
 * @brief Return the semantic version string (e.g. "0.1.0").
 * @return Null-terminated version string view.
 */
std::string_view version_string() noexcept;

/**
 * @brief Return the Git commit hash captured at build configuration time.
 * @return Short Git commit hash string view, or "unknown" if unavailable.
 */
std::string_view git_commit_hash() noexcept;

}  // namespace my_project

#endif  // MY_PROJECT_VERSION_HPP
