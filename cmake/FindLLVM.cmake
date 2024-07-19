set(llvm_config_names llvm-config-18.1 llvm-config181 llvm-config-18 llvm-config-17.0 llvm-config170 llvm-config-17 llvm-config-16.0 llvm-config160 llvm-config-16 llvm-config-15.0 llvm-config150 llvm-config-15 llvm-config)
find_program(LLVM_CONFIG
    NAMES ${llvm_config_names}
    PATHS ${LLVM_ROOT_DIR}/bin NO_DEFAULT_PATH
    DOC "Path to llvm-config tool.")
find_program(LLVM_CONFIG NAMES ${llvm_config_names})
if(APPLE)
    find_program(LLVM_CONFIG
        NAMES ${llvm_config_names}
        PATHS /opt/local/libexec/llvm-18/bin /opt/local/libexec/llvm-17/bin /opt/local/libexec/llvm-16/bin /opt/local/libexec/llvm-15/bin /opt/local/libexec/llvm/bin /usr/local/opt/llvm@18/bin /usr/local/opt/llvm@17/bin /usr/local/opt/llvm@16/bin /usr/local/opt/llvm@15/bin /usr/local/opt/llvm/bin
        NO_DEFAULT_PATH)
endif()
macro(_LLVM_FAIL _msg)
  if(LLVM_FIND_REQUIRED)
    message(FATAL_ERROR "${_msg}")
  else()
    if(NOT LLVM_FIND_QUIETLY)
      message(WARNING "${_msg}")
    endif()
  endif()
endmacro()


if(NOT LLVM_CONFIG)
    if(NOT LLVM_FIND_QUIETLY)
        _LLVM_FAIL("No LLVM installation (>= ${LLVM_FIND_VERSION}) found. Try manually setting the 'LLVM_ROOT_DIR' or 'LLVM_CONFIG' variables.")
    endif()
else()
    macro(llvm_set var flag)
       if(LLVM_FIND_QUIETLY)
            set(_quiet_arg ERROR_QUIET)
        endif()
        set(result_code)
        execute_process(
            COMMAND ${LLVM_CONFIG} --${flag}
            RESULT_VARIABLE result_code
            OUTPUT_VARIABLE LLVM_${var}
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ${_quiet_arg}
        )
        if(result_code)
            _LLVM_FAIL("Failed to execute llvm-config ('${LLVM_CONFIG}', result code: '${result_code})'")
        else()
            if(${ARGV2})
                file(TO_CMAKE_PATH "${LLVM_${var}}" LLVM_${var})
            endif()
        endif()
    endmacro()
    macro(llvm_set_libs var flag components)
       if(LLVM_FIND_QUIETLY)
            set(_quiet_arg ERROR_QUIET)
        endif()
        set(result_code)
        execute_process(
            COMMAND ${LLVM_CONFIG} --${flag} ${components}
            RESULT_VARIABLE result_code
            OUTPUT_VARIABLE tmplibs
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ${_quiet_arg}
        )
        if(result_code)
            _LLVM_FAIL("Failed to execute llvm-config ('${LLVM_CONFIG}', result code: '${result_code})'")
        else()        
            file(TO_CMAKE_PATH "${tmplibs}" tmplibs)
            string(REGEX MATCHALL "${pattern}[^ ]+" LLVM_${var} ${tmplibs})
        endif()
    endmacro()

    llvm_set(VERSION_STRING version)
    llvm_set(CXXFLAGS cxxflags)
    llvm_set(INCLUDE_DIRS includedir true)
    llvm_set(ROOT_DIR prefix true)
    llvm_set(ENABLE_ASSERTIONS assertion-mode)

    # The LLVM version string _may_ contain a git/svn suffix, so match only the x.y.z part
    string(REGEX MATCH "^[0-9]+[.][0-9]+[.][0-9]+" LLVM_VERSION_BASE_STRING "${LLVM_VERSION_STRING}")
    string(REGEX REPLACE "([0-9]+).*" "\\1" LLVM_VERSION_MAJOR "${LLVM_VERSION_STRING}" )
    string(REGEX REPLACE "[0-9]+\\.([0-9]+).*[A-Za-z]*" "\\1" LLVM_VERSION_MINOR "${LLVM_VERSION_STRING}" )

    llvm_set(SHARED_MODE shared-mode)
    if(LLVM_SHARED_MODE STREQUAL "shared")
        set(LLVM_IS_SHARED ON)
    else()
        set(LLVM_IS_SHARED OFF)
    endif()

    llvm_set(LDFLAGS ldflags)
    llvm_set(SYSTEM_LIBS system-libs)
    string(REPLACE "\n" " " LLVM_LDFLAGS "${LLVM_LDFLAGS} ${LLVM_SYSTEM_LIBS}")
    if(APPLE) # unclear why/how this happens
        string(REPLACE "-llibxml2.tbd" "-lxml2" LLVM_LDFLAGS ${LLVM_LDFLAGS})
    endif()

    if(${LLVM_VERSION_MAJOR} LESS "15")
        list(REMOVE_ITEM LLVM_FIND_COMPONENTS "windowsdriver")
    endif()

    llvm_set(LIBRARY_DIRS libdir true)
    llvm_set_libs(LIBRARIES libs "${LLVM_FIND_COMPONENTS}")
    if("${LLVM_FIND_COMPONENTS}" MATCHES "tablegen")
        if (NOT "${LLVM_LIBRARIES}" MATCHES "LLVMTableGen")
            set(LLVM_LIBRARIES "${LLVM_LIBRARIES};-lLLVMTableGen")
        endif()
    endif()

    llvm_set(CMAKEDIR cmakedir)
    llvm_set(TARGETS_TO_BUILD targets-built)
    string(REGEX MATCHALL "${pattern}[^ ]+" LLVM_TARGETS_TO_BUILD ${LLVM_TARGETS_TO_BUILD})

    file(STRINGS "${LLVM_CMAKEDIR}/LLVMConfig.cmake" LLVM_NATIVE_ARCH LIMIT_COUNT 1 REGEX "^set\\(LLVM_NATIVE_ARCH (.+)\\)$")
    string(REGEX MATCH "set\\(LLVM_NATIVE_ARCH (.+)\\)" LLVM_NATIVE_ARCH "${LLVM_NATIVE_ARCH}")
    set(LLVM_NATIVE_ARCH ${CMAKE_MATCH_1})
    message(STATUS "LLVM_NATIVE_ARCH: ${LLVM_NATIVE_ARCH}")
    if(NOT MSVC AND (CMAKE_COMPILER_IS_GNUCXX OR (${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang")))
        if(NOT ${LLVM_CXXFLAGS} MATCHES "-fno-rtti")
            set(LLVM_CXXFLAGS "${LLVM_CXXFLAGS} -fno-rtti")
        endif()
    endif()
    if(CMAKE_COMPILER_IS_GNUCXX)
        string(REPLACE "-Wcovered-switch-default " "" LLVM_CXXFLAGS ${LLVM_CXXFLAGS})
        string(REPLACE "-Wstring-conversion " "" LLVM_CXXFLAGS ${LLVM_CXXFLAGS})
        string(REPLACE "-fcolor-diagnostics " "" LLVM_CXXFLAGS ${LLVM_CXXFLAGS})
        string(REPLACE "-Werror=unguarded-availability-new " "" LLVM_CXXFLAGS ${LLVM_CXXFLAGS})
    endif()
    if(${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")
        string(REPLACE "-Wno-maybe-uninitialized " "" LLVM_CXXFLAGS ${LLVM_CXXFLAGS})
    endif()
    if (${LLVM_VERSION_STRING} VERSION_LESS ${LLVM_FIND_VERSION})
        _LLVM_FAIL("Unsupported LLVM version ${LLVM_VERSION_STRING} found (${LLVM_CONFIG}). At least version ${LLVM_FIND_VERSION} is required. You can also set variables 'LLVM_ROOT_DIR' or 'LLVM_CONFIG' to use a different LLVM installation.")
    endif()
endif()
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LLVM
    REQUIRED_VARS LLVM_ROOT_DIR
    VERSION_VAR LLVM_VERSION_STRING)
