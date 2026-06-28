# Header-only boost_system shim.
#
# Since Boost 1.69, boost_system is header-only: there is no compiled library
# and no per-component CMake config file.  Recent CMake's FindBoost (module
# mode) and Boost's own BoostConfig (config mode) both fail to resolve a
# `system` *component* for modern Boost.  This shim provides the
# boost_system-config that BoostConfig's per-component find_package looks for,
# declaring Boost::system as a header-only target.
#
# Lives in the distribution layer (not in the vendored upstream/ subtree).
include_guard(DIRECTORY)

if(NOT TARGET Boost::system)
    add_library(Boost::system INTERFACE IMPORTED)
    if(TARGET Boost::headers)
        target_link_libraries(Boost::system INTERFACE Boost::headers)
    endif()
endif()

set(boost_system_FOUND TRUE)
