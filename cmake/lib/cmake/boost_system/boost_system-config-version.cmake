# Version-agnostic config-version for the header-only boost_system shim.
# Echo back whatever version was requested as an exact match, so the shim
# works against any installed Boost version (1.74 on Debian, 1.90 on Homebrew).
set(PACKAGE_VERSION "${PACKAGE_FIND_VERSION}")
if(PACKAGE_FIND_VERSION)
    set(PACKAGE_VERSION_EXACT TRUE)
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
else()
    set(PACKAGE_VERSION "1.0.0")
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
endif()
