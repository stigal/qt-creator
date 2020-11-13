if(QT_CREATOR_API_DEFINED)
  return()
endif()
set(QT_CREATOR_API_DEFINED TRUE)

set(IDE_QT_VERSION_MIN "5.14.0")

include(${CMAKE_CURRENT_LIST_DIR}/QtCreatorAPIInternal.cmake)

set(IDE_APP_PATH "${_IDE_APP_PATH}")                    # The target path of the IDE application (relative to CMAKE_INSTALL_PREFIX).
set(IDE_APP_TARGET "${_IDE_APP_TARGET}")                # The IDE application name.
set(IDE_PLUGIN_PATH "${_IDE_PLUGIN_PATH}")              # The IDE plugin path (relative to CMAKE_INSTALL_PREFIX).
set(IDE_LIBRARY_BASE_PATH "${_IDE_LIBRARY_BASE_PATH}")  # The IDE library base path (relative to CMAKE_INSTALL_PREFIX).
set(IDE_LIBRARY_PATH "${_IDE_LIBRARY_PATH}")            # The IDE library path (relative to CMAKE_INSTALL_PREFIX).
set(IDE_LIBEXEC_PATH "${_IDE_LIBEXEC_PATH}")            # The IDE libexec path (relative to CMAKE_INSTALL_PREFIX).
set(IDE_DATA_PATH "${_IDE_DATA_PATH}")                  # The IDE data path (relative to CMAKE_INSTALL_PREFIX).
set(IDE_DOC_PATH "${_IDE_DOC_PATH}")                    # The IDE documentation path (relative to CMAKE_INSTALL_PREFIX).
set(IDE_BIN_PATH "${_IDE_BIN_PATH}")                    # The IDE bin path (relative to CMAKE_INSTALL_PREFIX).

file(RELATIVE_PATH RELATIVE_PLUGIN_PATH "/${IDE_BIN_PATH}" "/${IDE_PLUGIN_PATH}")
file(RELATIVE_PATH RELATIVE_LIBEXEC_PATH "/${IDE_BIN_PATH}" "/${IDE_LIBEXEC_PATH}")
file(RELATIVE_PATH RELATIVE_DATA_PATH "/${IDE_BIN_PATH}" "/${IDE_DATA_PATH}")
file(RELATIVE_PATH RELATIVE_DOC_PATH "/${IDE_BIN_PATH}" "/${IDE_DOC_PATH}")

list(APPEND DEFAULT_DEFINES
  RELATIVE_PLUGIN_PATH="${RELATIVE_PLUGIN_PATH}"
  RELATIVE_LIBEXEC_PATH="${RELATIVE_LIBEXEC_PATH}"
  RELATIVE_DATA_PATH="${RELATIVE_DATA_PATH}"
  RELATIVE_DOC_PATH="${RELATIVE_DOC_PATH}"
)

# use CMAKE_CURRENT_FUNCTION_LIST_DIR when we can require CMake 3.17
set(_THIS_MODULE_BASE_DIR "${CMAKE_CURRENT_LIST_DIR}")

option(BUILD_PLUGINS_BY_DEFAULT "Build plugins by default. This can be used to build all plugins by default, or none." ON)
option(BUILD_EXECUTABLES_BY_DEFAULT "Build executables by default. This can be used to build all executables by default, or none." ON)
option(BUILD_LIBRARIES_BY_DEFAULT "Build libraries by default. This can be used to build all libraries by default, or none." ON)

function(qtc_plugin_enabled varName name)
  if (NOT (name IN_LIST __QTC_PLUGINS))
    message(FATAL_ERROR "qtc_plugin_enabled: Unknown plugin target \"${name}\"")
  endif()
  if (TARGET ${name})
    set(${varName} ON PARENT_SCOPE)
  else()
    set(${varName} OFF PARENT_SCOPE)
  endif()
endfunction()

function(qtc_library_enabled varName name)
  if (NOT (name IN_LIST __QTC_LIBRARIES))
    message(FATAL_ERROR "qtc_library_enabled: Unknown library target \"${name}\"")
  endif()
  if (TARGET ${name})
    set(${varName} ON PARENT_SCOPE)
  else()
    set(${varName} OFF PARENT_SCOPE)
  endif()
endfunction()

function(qtc_output_binary_dir varName)
  if (QTC_MERGE_BINARY_DIR)
    set(${varName} ${QtCreator_BINARY_DIR} PARENT_SCOPE)
  else()
    set(${varName} ${PROJECT_BINARY_DIR} PARENT_SCOPE)
  endif()
endfunction()

function(add_qtc_library name)
  cmake_parse_arguments(_arg "STATIC;OBJECT;SKIP_TRANSLATION;ALLOW_ASCII_CASTS;UNVERSIONED"
    "DESTINATION;COMPONENT;SOURCES_PREFIX;BUILD_DEFAULT"
    "CONDITION;DEPENDS;PUBLIC_DEPENDS;DEFINES;PUBLIC_DEFINES;INCLUDES;PUBLIC_INCLUDES;SOURCES;EXPLICIT_MOC;SKIP_AUTOMOC;EXTRA_TRANSLATIONS;PROPERTIES" ${ARGN}
  )

  set(default_defines_copy ${DEFAULT_DEFINES})
  if (_arg_ALLOW_ASCII_CASTS)
    list(REMOVE_ITEM default_defines_copy QT_NO_CAST_TO_ASCII QT_RESTRICTED_CAST_FROM_ASCII)
  endif()

  if (${_arg_UNPARSED_ARGUMENTS})
    message(FATAL_ERROR "add_qtc_library had unparsed arguments")
  endif()

  update_cached_list(__QTC_LIBRARIES "${name}")

  if (NOT _arg_CONDITION)
    set(_arg_CONDITION ON)
  endif()

  string(TOUPPER "BUILD_LIBRARY_${name}" _build_library_var)
  if (DEFINED _arg_BUILD_DEFAULT)
    set(_build_library_default ${_arg_BUILD_DEFAULT})
  else()
    set(_build_library_default ${BUILD_LIBRARIES_BY_DEFAULT})
  endif()
  if (DEFINED ENV{QTC_${_build_library_var}})
    set(_build_library_default "$ENV{QTC_${_build_library_var}}")
  endif()
  set(${_build_library_var} "${_build_library_default}" CACHE BOOL "Build library ${name}.")

  if ((${_arg_CONDITION}) AND ${_build_library_var})
    set(_library_enabled ON)
  else()
    set(_library_enabled OFF)
  endif()

  if (NOT _library_enabled)
    return()
  endif()

  # TODO copied from extend_qtc_target.
  # Instead require CMake 3.11 and use extend_qtc_target for setting SOURCES.
  # Requiring cmake 3.11 is necessary because before that add_library requires
  # at least one source file.
  if (_arg_SOURCES_PREFIX)
    foreach(source IN LISTS _arg_SOURCES)
      list(APPEND prefixed_sources "${_arg_SOURCES_PREFIX}/${source}")
    endforeach()
    if (NOT IS_ABSOLUTE ${_arg_SOURCES_PREFIX})
      set(_arg_SOURCES_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/${_arg_SOURCES_PREFIX}")
    endif()
    set(_arg_SOURCES ${prefixed_sources})
  endif()

  compare_sources_with_existing_disk_files(${name} "${_arg_SOURCES}")

  set(library_type SHARED)
  if (_arg_STATIC)
    set(library_type STATIC)
  endif()
  if (_arg_OBJECT)
    set(library_type OBJECT)
  endif()

  add_library(${name} ${library_type} ${_arg_SOURCES})
  add_library(QtCreator::${name} ALIAS ${name})
  set_public_headers(${name} "${_arg_SOURCES}")

  # TODO remove, see above
  if (_arg_SOURCES_PREFIX)
    target_include_directories(${name} PRIVATE $<BUILD_INTERFACE:${_arg_SOURCES_PREFIX}>)
  endif()

  if (${name} MATCHES "^[^0-9-]+$")
    string(TOUPPER "${name}_LIBRARY" EXPORT_SYMBOL)
  endif()

  if (WITH_TESTS)
    set(TEST_DEFINES WITH_TESTS SRCDIR="${CMAKE_CURRENT_SOURCE_DIR}")
  endif()

  extend_qtc_target(${name}
    INCLUDES ${_arg_INCLUDES}
    PUBLIC_INCLUDES ${_arg_PUBLIC_INCLUDES}
    DEFINES ${EXPORT_SYMBOL} ${default_defines_copy} ${_arg_DEFINES} ${TEST_DEFINES}
    PUBLIC_DEFINES ${_arg_PUBLIC_DEFINES}
    DEPENDS ${_arg_DEPENDS} ${IMPLICIT_DEPENDS}
    PUBLIC_DEPENDS ${_arg_PUBLIC_DEPENDS}
    EXPLICIT_MOC ${_arg_EXPLICIT_MOC}
    SKIP_AUTOMOC ${_arg_SKIP_AUTOMOC}
    EXTRA_TRANSLATIONS ${_arg_EXTRA_TRANSLATIONS}
  )

  # everything is different with SOURCES_PREFIX
  if (NOT _arg_SOURCES_PREFIX)
    get_filename_component(public_build_interface_dir "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
    file(RELATIVE_PATH include_dir_relative_path ${PROJECT_SOURCE_DIR} "${CMAKE_CURRENT_SOURCE_DIR}/..")
    target_include_directories(${name}
      PRIVATE
        "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>"
      PUBLIC
        "$<BUILD_INTERFACE:${public_build_interface_dir}>"
        "$<INSTALL_INTERFACE:include/${include_dir_relative_path}>"
    )
  endif()

  set(skip_translation OFF)
  if (_arg_SKIP_TRANSLATION)
    set(skip_translation ON)
  endif()

  set(_DESTINATION "${IDE_BIN_PATH}")
  if (_arg_DESTINATION)
    set(_DESTINATION "${_arg_DESTINATION}")
  endif()

  qtc_output_binary_dir(_output_binary_dir)
  set_target_properties(${name} PROPERTIES
    SOURCES_DIR "${CMAKE_CURRENT_SOURCE_DIR}"
    VERSION "${IDE_VERSION}"
    SOVERSION "${PROJECT_VERSION_MAJOR}"
    MACHO_CURRENT_VERSION ${IDE_VERSION}
    MACHO_COMPATIBILITY_VERSION ${IDE_VERSION_COMPAT}
    CXX_EXTENSIONS OFF
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
    BUILD_RPATH "${_LIB_RPATH}"
    INSTALL_RPATH "${_LIB_RPATH}"
    RUNTIME_OUTPUT_DIRECTORY "${_output_binary_dir}/${_DESTINATION}"
    LIBRARY_OUTPUT_DIRECTORY "${_output_binary_dir}/${IDE_LIBRARY_PATH}"
    ARCHIVE_OUTPUT_DIRECTORY "${_output_binary_dir}/${IDE_LIBRARY_PATH}"
    ${_arg_PROPERTIES}
  )
  enable_pch(${name})

  if (WIN32 AND library_type STREQUAL "SHARED" AND NOT _arg_UNVERSIONED)
    # Match qmake naming scheme e.g. Library4.dll
    set_target_properties(${name} PROPERTIES
      SUFFIX "${PROJECT_VERSION_MAJOR}${CMAKE_SHARED_LIBRARY_SUFFIX}"
      PREFIX ""
    )
  endif()

  unset(NAMELINK_OPTION)
  if (library_type STREQUAL "SHARED")
    set(NAMELINK_OPTION NAMELINK_SKIP)
  endif()

  unset(COMPONENT_OPTION)
  if (_arg_COMPONENT)
    set(COMPONENT_OPTION "COMPONENT" "${_arg_COMPONENT}")
  endif()

  install(TARGETS ${name}
    EXPORT QtCreator
    RUNTIME
      DESTINATION "${_DESTINATION}"
      ${COMPONENT_OPTION}
      OPTIONAL
    LIBRARY
      DESTINATION "${IDE_LIBRARY_PATH}"
      ${NAMELINK_OPTION}
      ${COMPONENT_OPTION}
      OPTIONAL
    OBJECTS
      DESTINATION "${IDE_LIBRARY_PATH}"
      COMPONENT Devel EXCLUDE_FROM_ALL
    ARCHIVE
      DESTINATION "${IDE_LIBRARY_PATH}"
      COMPONENT Devel EXCLUDE_FROM_ALL
      OPTIONAL
  )

  if (library_type STREQUAL "SHARED")
    set(target_prefix ${CMAKE_SHARED_LIBRARY_PREFIX})
    if (WIN32)
      set(target_suffix ${PROJECT_VERSION_MAJOR}${CMAKE_SHARED_LIBRARY_SUFFIX})
      set(target_prefix "")
    elseif(APPLE)
      set(target_suffix .${PROJECT_VERSION_MAJOR}${CMAKE_SHARED_LIBRARY_SUFFIX})
    else()
      set(target_suffix ${CMAKE_SHARED_LIBRARY_SUFFIX}.${PROJECT_VERSION_MAJOR})
    endif()
    set(lib_dir "${IDE_LIBRARY_PATH}")
    if (WIN32)
      set(lib_dir "${_DESTINATION}")
    endif()
    update_cached_list(__QTC_INSTALLED_LIBRARIES
      "${lib_dir}/${target_prefix}${name}${target_suffix}")
  endif()

  if (NAMELINK_OPTION)
    install(TARGETS ${name}
      LIBRARY
        DESTINATION "${IDE_LIBRARY_PATH}"
        NAMELINK_ONLY
        COMPONENT Devel EXCLUDE_FROM_ALL
      OPTIONAL
    )
  endif()
endfunction(add_qtc_library)

function(add_qtc_plugin target_name)
  cmake_parse_arguments(_arg
    "EXPERIMENTAL;SKIP_DEBUG_CMAKE_FILE_CHECK;SKIP_INSTALL;INTERNAL_ONLY;SKIP_TRANSLATION;EXPORT"
    "VERSION;COMPAT_VERSION;PLUGIN_JSON_IN;PLUGIN_PATH;PLUGIN_NAME;OUTPUT_NAME;BUILD_DEFAULT"
    "CONDITION;DEPENDS;PUBLIC_DEPENDS;DEFINES;PUBLIC_DEFINES;INCLUDES;PUBLIC_INCLUDES;SOURCES;EXPLICIT_MOC;SKIP_AUTOMOC;EXTRA_TRANSLATIONS;PLUGIN_DEPENDS;PLUGIN_RECOMMENDS;PROPERTIES"
    ${ARGN}
  )

  if (${_arg_UNPARSED_ARGUMENTS})
    message(FATAL_ERROR "add_qtc_plugin had unparsed arguments")
  endif()

  update_cached_list(__QTC_PLUGINS "${target_name}")

  set(name ${target_name})
  if (_arg_PLUGIN_NAME)
    set(name ${_arg_PLUGIN_NAME})
  endif()

  condition_info(_extra_text _arg_CONDITION)
  if (NOT _arg_CONDITION)
    set(_arg_CONDITION ON)
  endif()

  string(TOUPPER "BUILD_PLUGIN_${target_name}" _build_plugin_var)
  if (DEFINED _arg_BUILD_DEFAULT)
    set(_build_plugin_default ${_arg_BUILD_DEFAULT})
  else()
    set(_build_plugin_default ${BUILD_PLUGINS_BY_DEFAULT})
  endif()
  if (DEFINED ENV{QTC_${_build_plugin_var}})
    set(_build_plugin_default "$ENV{QTC_${_build_plugin_var}}")
  endif()
  if (_arg_INTERNAL_ONLY)
    set(${_build_plugin_var} "${_build_plugin_default}")
  else()
    set(${_build_plugin_var} "${_build_plugin_default}" CACHE BOOL "Build plugin ${name}.")
  endif()

  if ((${_arg_CONDITION}) AND ${_build_plugin_var})
    set(_plugin_enabled ON)
  else()
    set(_plugin_enabled OFF)
  endif()

  if (NOT _arg_INTERNAL_ONLY)
    add_feature_info("Plugin ${name}" _plugin_enabled "${_extra_text}")
  endif()
  if (NOT _plugin_enabled)
    return()
  endif()

  ### Generate plugin.json file:
  if (NOT _arg_VERSION)
    set(_arg_VERSION ${IDE_VERSION})
  endif()
  if (NOT _arg_COMPAT_VERSION)
    set(_arg_COMPAT_VERSION ${_arg_VERSION})
  endif()

  if (NOT _arg_SKIP_DEBUG_CMAKE_FILE_CHECK)
    compare_sources_with_existing_disk_files(${target_name} "${_arg_SOURCES}")
  endif()

  # Generate dependency list:
  find_dependent_plugins(_DEP_PLUGINS ${_arg_PLUGIN_DEPENDS})

  set(_arg_DEPENDENCY_STRING "\"Dependencies\" : [\n")
  foreach(i IN LISTS _DEP_PLUGINS)
    if (i MATCHES "^QtCreator::")
      set(_v ${IDE_VERSION})
      string(REPLACE "QtCreator::" "" i ${i})
    else()
      get_property(_v TARGET "${i}" PROPERTY _arg_VERSION)
    endif()
    string(APPEND _arg_DEPENDENCY_STRING
      "        { \"Name\" : \"${i}\", \"Version\" : \"${_v}\" }"
    )
  endforeach(i)
  string(REPLACE "}        {" "},\n        {"
    _arg_DEPENDENCY_STRING "${_arg_DEPENDENCY_STRING}"
  )
  foreach(i IN LISTS ${_arg_RECOMMENDS})
    if (i MATCHES "^QtCreator::")
      set(_v ${IDE_VERSION})
      string(REPLACE "QtCreator::" "" i ${i})
    else()
      get_property(_v TARGET "${i}" PROPERTY _arg_VERSION)
    endif()
    string(APPEND _arg_DEPENDENCY_STRING
      "        { \"Name\" : \"${i}\", \"Version\" : \"${_v}\", \"Type\" : \"optional\" }"
    )
  endforeach(i)
  string(APPEND _arg_DEPENDENCY_STRING "\n    ]")
  if (_arg_EXPERIMENTAL)
    string(APPEND _arg_DEPENDENCY_STRING ",\n    \"Experimental\" : true")
  endif()

  set(IDE_PLUGIN_DEPENDENCY_STRING ${_arg_DEPENDENCY_STRING})

  ### Configure plugin.json file:
  if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${name}.json.in")
    file(READ "${name}.json.in" plugin_json_in)
    string(REPLACE "\\\"" "\"" plugin_json_in ${plugin_json_in})
    string(REPLACE "\\'" "'" plugin_json_in ${plugin_json_in})
    string(REPLACE "$$QTCREATOR_VERSION" "\${IDE_VERSION}" plugin_json_in ${plugin_json_in})
    string(REPLACE "$$QTCREATOR_COMPAT_VERSION" "\${IDE_VERSION_COMPAT}" plugin_json_in ${plugin_json_in})
    string(REPLACE "$$QTCREATOR_COPYRIGHT_YEAR" "\${IDE_COPYRIGHT_YEAR}" plugin_json_in ${plugin_json_in})
    string(REPLACE "$$QTC_PLUGIN_REVISION" "\${QTC_PLUGIN_REVISION}" plugin_json_in ${plugin_json_in})
    string(REPLACE "$$dependencyList" "\${IDE_PLUGIN_DEPENDENCY_STRING}" plugin_json_in ${plugin_json_in})
    if(_arg_PLUGIN_JSON_IN)
        #e.g. UPDATEINFO_EXPERIMENTAL_STR=true
        string(REGEX REPLACE "=.*$" "" json_key ${_arg_PLUGIN_JSON_IN})
        string(REGEX REPLACE "^.*=" "" json_value ${_arg_PLUGIN_JSON_IN})
        string(REPLACE "$$${json_key}" "${json_value}" plugin_json_in ${plugin_json_in})
    endif()
    string(CONFIGURE "${plugin_json_in}" plugin_json)
    file(GENERATE
      OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${name}.json"
      CONTENT "${plugin_json}")
  endif()

  add_library(${target_name} SHARED ${_arg_SOURCES})
  add_library(QtCreator::${target_name} ALIAS ${target_name})
  set_public_headers(${target_name} "${_arg_SOURCES}")

  ### Generate EXPORT_SYMBOL
  string(TOUPPER "${name}_LIBRARY" EXPORT_SYMBOL)

  if (WITH_TESTS)
    set(TEST_DEFINES WITH_TESTS SRCDIR="${CMAKE_CURRENT_SOURCE_DIR}")
  endif()

  extend_qtc_target(${target_name}
    INCLUDES ${_arg_INCLUDES}
    PUBLIC_INCLUDES ${_arg_PUBLIC_INCLUDES}
    DEFINES ${EXPORT_SYMBOL} ${DEFAULT_DEFINES} ${_arg_DEFINES} ${TEST_DEFINES}
    PUBLIC_DEFINES ${_arg_PUBLIC_DEFINES}
    DEPENDS ${_arg_DEPENDS} ${_DEP_PLUGINS} ${IMPLICIT_DEPENDS}
    PUBLIC_DEPENDS ${_arg_PUBLIC_DEPENDS}
    EXPLICIT_MOC ${_arg_EXPLICIT_MOC}
    SKIP_AUTOMOC ${_arg_SKIP_AUTOMOC}
    EXTRA_TRANSLATIONS ${_arg_EXTRA_TRANSLATIONS}
  )

  get_filename_component(public_build_interface_dir "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
  file(RELATIVE_PATH include_dir_relative_path ${PROJECT_SOURCE_DIR} "${CMAKE_CURRENT_SOURCE_DIR}/..")
  target_include_directories(${target_name}
    PRIVATE
      "${CMAKE_CURRENT_BINARY_DIR}"
      "${CMAKE_BINARY_DIR}/src"
      "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>"
    PUBLIC
      "$<BUILD_INTERFACE:${public_build_interface_dir}>"
      "$<INSTALL_INTERFACE:include/${include_dir_relative_path}>"
  )

  set(plugin_dir "${IDE_PLUGIN_PATH}")
  if (_arg_PLUGIN_PATH)
    set(plugin_dir "${_arg_PLUGIN_PATH}")
  endif()

  set(skip_translation OFF)
  if (_arg_SKIP_TRANSLATION)
    set(skip_translation ON)
  endif()

  qtc_output_binary_dir(_output_binary_dir)
  set_target_properties(${target_name} PROPERTIES
    SOURCES_DIR "${CMAKE_CURRENT_SOURCE_DIR}"
    MACHO_CURRENT_VERSION ${IDE_VERSION}
    MACHO_COMPATIBILITY_VERSION ${IDE_VERSION_COMPAT}
    CXX_EXTENSIONS OFF
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
    _arg_DEPENDS "${_arg_PLUGIN_DEPENDS}"
    _arg_VERSION "${_arg_VERSION}"
    BUILD_RPATH "${_PLUGIN_RPATH}"
    INSTALL_RPATH "${_PLUGIN_RPATH}"
    LIBRARY_OUTPUT_DIRECTORY "${_output_binary_dir}/${plugin_dir}"
    ARCHIVE_OUTPUT_DIRECTORY "${_output_binary_dir}/${plugin_dir}"
    RUNTIME_OUTPUT_DIRECTORY "${_output_binary_dir}/${plugin_dir}"
    OUTPUT_NAME "${name}"
    QT_SKIP_TRANSLATION "${skip_translation}"
    ${_arg_PROPERTIES}
  )

  if (WIN32)
    # Match qmake naming scheme e.g. Plugin4.dll
    set_target_properties(${target_name} PROPERTIES
      SUFFIX "${PROJECT_VERSION_MAJOR}${CMAKE_SHARED_LIBRARY_SUFFIX}"
      PREFIX ""
    )
  endif()
  enable_pch(${target_name})

  if (NOT _arg_SKIP_INSTALL)
    if (_arg_EXPORT)
      set(export QtCreator${target_name})
    else()
      set(export QtCreator)
    endif()

    install(TARGETS ${target_name}
      EXPORT ${export}
      RUNTIME DESTINATION "${plugin_dir}" OPTIONAL
      LIBRARY DESTINATION "${plugin_dir}" OPTIONAL
      ARCHIVE
        DESTINATION "${plugin_dir}"
        COMPONENT Devel EXCLUDE_FROM_ALL
        OPTIONAL
    )

    if (_arg_EXPORT)
      # export of external plugins
      install(EXPORT ${export}
        FILE ${export}Targets.cmake
        DESTINATION lib/cmake/${export}
        COMPONENT Devel EXCLUDE_FROM_ALL
        NAMESPACE QtCreator::
      )
      include(CMakePackageConfigHelpers)
      configure_package_config_file(${_THIS_MODULE_BASE_DIR}/Config.cmake.in
        "${CMAKE_BINARY_DIR}/cmake/${export}Config.cmake"
        INSTALL_DESTINATION lib/cmake/${export}
      )
      install(
        FILES ${CMAKE_BINARY_DIR}/cmake/${export}Config.cmake
        DESTINATION lib/cmake/${export}
        COMPONENT Devel EXCLUDE_FROM_ALL
      )
      export(EXPORT ${export}
        NAMESPACE QtCreator::
        FILE ${CMAKE_BINARY_DIR}/cmake/${export}Targets.cmake
      )
    endif()
    get_target_property(target_suffix ${target_name} SUFFIX)
    get_target_property(target_prefix ${target_name} PREFIX)
    if (target_suffix STREQUAL "target_suffix-NOTFOUND")
      set(target_suffix ${CMAKE_SHARED_LIBRARY_SUFFIX})
    endif()
    if (target_prefix STREQUAL "target_prefix-NOTFOUND")
      set(target_prefix ${CMAKE_SHARED_LIBRARY_PREFIX})
    endif()
    update_cached_list(__QTC_INSTALLED_PLUGINS
      "${plugin_dir}/${target_prefix}${target_name}${target_suffix}")
  endif()
endfunction()

function(extend_qtc_plugin target_name)
  qtc_plugin_enabled(_plugin_enabled ${target_name})
  if (NOT _plugin_enabled)
    return()
  endif()

  extend_qtc_target(${target_name} ${ARGN})
endfunction()

function(extend_qtc_library target_name)
  qtc_library_enabled(_library_enabled ${target_name})
  if (NOT _library_enabled)
    return()
  endif()

  extend_qtc_target(${target_name} ${ARGN})
endfunction()

function(extend_qtc_test target_name)
  if (NOT (target_name IN_LIST __QTC_TESTS))
    message(FATAL_ERROR "extend_qtc_test: Unknown test target \"${name}\"")
  endif()
  extend_qtc_target(${target_name} ${ARGN})
endfunction()

function(add_qtc_executable name)
  cmake_parse_arguments(_arg "SKIP_INSTALL;SKIP_TRANSLATION;ALLOW_ASCII_CASTS"
    "DESTINATION;COMPONENT;BUILD_DEFAULT"
    "CONDITION;DEPENDS;DEFINES;INCLUDES;SOURCES;EXPLICIT_MOC;SKIP_AUTOMOC;EXTRA_TRANSLATIONS;PROPERTIES" ${ARGN})

  if (${_arg_UNPARSED_ARGUMENTS})
    message(FATAL_ERROR "add_qtc_executable had unparsed arguments!")
  endif()

  set(default_defines_copy ${DEFAULT_DEFINES})
  if (_arg_ALLOW_ASCII_CASTS)
    list(REMOVE_ITEM default_defines_copy QT_NO_CAST_TO_ASCII QT_RESTRICTED_CAST_FROM_ASCII)
  endif()

  update_cached_list(__QTC_EXECUTABLES "${name}")

  if (NOT _arg_CONDITION)
    set(_arg_CONDITION ON)
  endif()

  string(TOUPPER "BUILD_EXECUTABLE_${name}" _build_executable_var)
  if (DEFINED _arg_BUILD_DEFAULT)
    set(_build_executable_default ${_arg_BUILD_DEFAULT})
  else()
    set(_build_executable_default ${BUILD_EXECUTABLES_BY_DEFAULT})
  endif()
  if (DEFINED ENV{QTC_${_build_executable_var}})
    set(_build_executable_default "$ENV{QTC_${_build_executable_var}}")
  endif()
  set(${_build_executable_var} "${_build_executable_default}" CACHE BOOL "Build executable ${name}.")

  if ((${_arg_CONDITION}) AND ${_build_executable_var})
    set(_executable_enabled ON)
  else()
    set(_executable_enabled OFF)
  endif()
  if (NOT _executable_enabled)
    return()
  endif()

  set(_DESTINATION "${IDE_LIBEXEC_PATH}")
  if (_arg_DESTINATION)
    set(_DESTINATION "${_arg_DESTINATION}")
  endif()

  set(_EXECUTABLE_PATH "${_DESTINATION}")
  if (APPLE)
    # path of executable might be inside app bundle instead of DESTINATION directly
    cmake_parse_arguments(_prop "" "MACOSX_BUNDLE;OUTPUT_NAME" "" "${_arg_PROPERTIES}")
    if (_prop_MACOSX_BUNDLE)
      set(_BUNDLE_NAME "${name}")
      if (_prop_OUTPUT_NAME)
        set(_BUNDLE_NAME "${_prop_OUTPUT_NAME}")
      endif()
      set(_BUNDLE_CONTENTS_PATH "${_DESTINATION}/${_BUNDLE_NAME}.app/Contents")
      set(_EXECUTABLE_PATH "${_BUNDLE_CONTENTS_PATH}/MacOS")
      set(_EXECUTABLE_FILE_PATH "${_EXECUTABLE_PATH}/${_BUNDLE_NAME}")
      set(_BUNDLE_INFO_PLIST "${_BUNDLE_CONTENTS_PATH}/Info.plist")
    endif()
  endif()

  add_executable("${name}" ${_arg_SOURCES})

  extend_qtc_target("${name}"
    INCLUDES "${CMAKE_BINARY_DIR}/src" ${_arg_INCLUDES}
    DEFINES ${default_defines_copy} ${TEST_DEFINES} ${_arg_DEFINES}
    DEPENDS ${_arg_DEPENDS} ${IMPLICIT_DEPENDS}
    EXPLICIT_MOC ${_arg_EXPLICIT_MOC}
    SKIP_AUTOMOC ${_arg_SKIP_AUTOMOC}
    EXTRA_TRANSLATIONS ${_arg_EXTRA_TRANSLATIONS}
  )

  set(skip_translation OFF)
  if (_arg_SKIP_TRANSLATION)
    set(skip_translation ON)
  endif()

  file(RELATIVE_PATH relative_lib_path "/${_EXECUTABLE_PATH}" "/${IDE_LIBRARY_PATH}")

  set(build_rpath "${_RPATH_BASE}/${relative_lib_path}")
  set(install_rpath "${_RPATH_BASE}/${relative_lib_path}")
  if (NOT WIN32 AND NOT APPLE)
    file(RELATIVE_PATH relative_qt_path "/${_EXECUTABLE_PATH}" "/${IDE_LIBRARY_BASE_PATH}/Qt/lib")
    file(RELATIVE_PATH relative_plugins_path "/${_EXECUTABLE_PATH}" "/${IDE_PLUGIN_PATH}")
    set(install_rpath "${install_rpath};${_RPATH_BASE}/${relative_qt_path};${_RPATH_BASE}/${relative_plugins_path}")
  endif()

  qtc_output_binary_dir(_output_binary_dir)
  set_target_properties("${name}" PROPERTIES
    BUILD_RPATH "${build_rpath}"
    INSTALL_RPATH "${install_rpath}"
    RUNTIME_OUTPUT_DIRECTORY "${_output_binary_dir}/${_DESTINATION}"
    QT_SKIP_TRANSLATION "${skip_translation}"
    CXX_EXTENSIONS OFF
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
    ${_arg_PROPERTIES}
  )
  enable_pch(${name})

  if (NOT _arg_SKIP_INSTALL)
    unset(COMPONENT_OPTION)
    if (_arg_COMPONENT)
      set(COMPONENT_OPTION "COMPONENT" "${_arg_COMPONENT}")
    endif()

    # work around the issue that CMake simply copies the bundle directory
    # when installing app bundles, which copies things that it should not
    # like static libraries, executables with SKIP_INSTALL, clang resources
    # and dSYM directories
    if (APPLE AND _EXECUTABLE_FILE_PATH AND _BUNDLE_INFO_PLIST)
      install(
        PROGRAMS "${_output_binary_dir}/${_EXECUTABLE_FILE_PATH}"
        DESTINATION "${_EXECUTABLE_PATH}"
        ${COMPONENT_OPTION}
        OPTIONAL
      )
      install(
        FILES "${_output_binary_dir}/${_BUNDLE_INFO_PLIST}"
        DESTINATION "${_BUNDLE_CONTENTS_PATH}"
        ${COMPONENT_OPTION}
        OPTIONAL
      )
      # Remove build-rpaths. That is BUILD_RPATH and the ones added because we
      # don't use SKIP_BUILD_RPATH
      set(_rpaths_to_remove ${build_rpath})
      get_target_property(_linked_libs ${name} LINK_LIBRARIES)
      foreach(_lib ${_linked_libs})
        get_target_property(_target_type ${_lib} TYPE)
        if (_target_type STREQUAL "SHARED_LIBRARY")
          get_target_property(_location ${_lib} LIBRARY_OUTPUT_DIRECTORY)
          if (_location)
            get_filename_component(_abs_location ${_location} ABSOLUTE)
            list(APPEND _rpaths_to_remove "${_abs_location}")
          else()
            get_target_property(_location ${_lib} LOCATION)
            get_target_property(_is_framework ${_lib} FRAMEWORK)
            if (_is_framework)
              set(_location ${_location}/../..)
            endif()
            get_filename_component(_abs_location ${_location} ABSOLUTE)
            list(APPEND _rpaths_to_remove "${_abs_location}")
          endif()
        endif()
      endforeach()
      list(REMOVE_DUPLICATES _rpaths_to_remove)
      set(_code)
      foreach(_rpath ${_rpaths_to_remove})
        set(_code "${_code}
          execute_process(COMMAND \"${CMAKE_INSTALL_NAME_TOOL}\"
            -delete_rpath \"${_rpath}\"
            \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${_EXECUTABLE_FILE_PATH}\")"
        )
      endforeach()
      foreach(_rpath ${install_rpath})
        set(_code "${_code}
          execute_process(COMMAND \"${CMAKE_INSTALL_NAME_TOOL}\"
            -add_rpath \"${_rpath}\"
            \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${_EXECUTABLE_FILE_PATH}\")"
        )
      endforeach()
      install(CODE "${_code}")
    else()
      install(TARGETS ${name}
        DESTINATION "${_DESTINATION}"
        ${COMPONENT_OPTION}
        OPTIONAL
      )
    endif()

    update_cached_list(__QTC_INSTALLED_EXECUTABLES
      "${_DESTINATION}/${name}${CMAKE_EXECUTABLE_SUFFIX}")

    install(CODE "
      function(create_qt_conf location base_dir)
        get_filename_component(install_prefix \"\${CMAKE_INSTALL_PREFIX}\" ABSOLUTE)
        file(RELATIVE_PATH qt_conf_binaries
          \"\${install_prefix}/\${location}\"
          \"\${install_prefix}/\${base_dir}\"
        )
        if (NOT qt_conf_binaries)
          set(qt_conf_binaries .)
        endif()
        file(RELATIVE_PATH qt_conf_plugins
          \"\${install_prefix}/\${base_dir}\"
          \"\${install_prefix}/${QT_DEST_PLUGIN_PATH}\"
        )
        file(RELATIVE_PATH qt_conf_qml
          \"\${install_prefix}/\${base_dir}\"
          \"\${install_prefix}/${QT_DEST_QML_PATH}\"
        )
        file(WRITE \"\${CMAKE_INSTALL_PREFIX}/\${location}/qt.conf\"
          \"[Paths]\n\"
          \"Plugins=\${qt_conf_plugins}\n\"
          \"Qml2Imports=\${qt_conf_qml}\n\"
        )
        # For Apple for Qt Creator do not add a Prefix
        if (NOT APPLE OR NOT qt_conf_binaries STREQUAL \"../\")
          file(APPEND \"\${CMAKE_INSTALL_PREFIX}/\${location}/qt.conf\"
            \"Prefix=\${qt_conf_binaries}\n\"
          )
        endif()
        if (WIN32 OR APPLE)
          file(RELATIVE_PATH qt_binaries
            \"\${install_prefix}/\${base_dir}\"
            \"\${install_prefix}/${IDE_BIN_PATH}\"
          )
          if (NOT qt_binaries)
            set(qt_binaries .)
          endif()
          file(APPEND \"\${CMAKE_INSTALL_PREFIX}/\${location}/qt.conf\"
            \"# Needed by QtCreator for qtdiag\n\"
            \"Binaries=\${qt_binaries}\n\")
        endif()
      endfunction()
      if(APPLE)
        create_qt_conf(\"${_EXECUTABLE_PATH}\" \"${IDE_DATA_PATH}/..\")
      elseif (WIN32)
        create_qt_conf(\"${_EXECUTABLE_PATH}\" \"${IDE_APP_PATH}\")
      else()
        create_qt_conf(\"${_EXECUTABLE_PATH}\" \"${IDE_LIBRARY_BASE_PATH}/Qt\")
      endif()
      "
      COMPONENT Dependencies
      EXCLUDE_FROM_ALL
     )

  endif()
endfunction()

function(extend_qtc_executable name)
  if (NOT (name IN_LIST __QTC_EXECUTABLES))
    message(FATAL_ERROR "extend_qtc_executable: Unknown executable target \"${name}\"")
  endif()
  if (TARGET ${name})
    extend_qtc_target(${name} ${ARGN})
  endif()
endfunction()

function(add_qtc_test name)
  cmake_parse_arguments(_arg "GTEST" "TIMEOUT" "DEFINES;DEPENDS;INCLUDES;SOURCES;EXPLICIT_MOC;SKIP_AUTOMOC" ${ARGN})

  foreach(dependency ${_arg_DEPENDS})
    if (NOT TARGET ${dependency} AND NOT _arg_GTEST)
      if (WITH_DEBUG_CMAKE)
        message(STATUS  "'${dependency}' is not a target")
      endif()
      return()
    endif()
  endforeach()

  if ($_arg_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "add_qtc_test had unparsed arguments!")
  endif()

  update_cached_list(__QTC_TESTS "${name}")

  set(TEST_DEFINES SRCDIR="${CMAKE_CURRENT_SOURCE_DIR}")

  # relax cast requirements for tests
  set(default_defines_copy ${DEFAULT_DEFINES})
  list(REMOVE_ITEM default_defines_copy QT_NO_CAST_TO_ASCII QT_RESTRICTED_CAST_FROM_ASCII)

  file(RELATIVE_PATH _RPATH "/${IDE_BIN_PATH}" "/${IDE_LIBRARY_PATH}")

  add_executable(${name} ${_arg_SOURCES})

  extend_qtc_target(${name}
    DEPENDS ${_arg_DEPENDS} ${IMPLICIT_DEPENDS}
    INCLUDES "${CMAKE_BINARY_DIR}/src" ${_arg_INCLUDES}
    DEFINES ${_arg_DEFINES} ${TEST_DEFINES} ${default_defines_copy}
    EXPLICIT_MOC ${_arg_EXPLICIT_MOC}
    SKIP_AUTOMOC ${_arg_SKIP_AUTOMOC}
  )

  set_target_properties(${name} PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
    BUILD_RPATH "${_RPATH_BASE}/${_RPATH}"
    INSTALL_RPATH "${_RPATH_BASE}/${_RPATH}"
  )
  enable_pch(${name})

  if (NOT _arg_GTEST)
    add_test(NAME ${name} COMMAND ${name})
    if (DEFINED _arg_TIMEOUT)
      set(timeout_option TIMEOUT ${_arg_TIMEOUT})
    else()
      set(timeout_option)
    endif()
    finalize_test_setup(${name} ${timeout_option})
  endif()
endfunction()

function(finalize_qtc_gtest test_name exclude_sources_regex)
  if (NOT TARGET ${test_name})
    return()
  endif()
  get_target_property(test_sources ${test_name} SOURCES)
  if (exclude_sources_regex)
    list(FILTER test_sources EXCLUDE REGEX "${exclude_sources_regex}")
  endif()
  include(GoogleTest)
  gtest_add_tests(TARGET ${test_name} SOURCES ${test_sources} TEST_LIST test_list)

  foreach(test IN LISTS test_list)
    finalize_test_setup(${test})
  endforeach()
endfunction()

function(qtc_copy_to_builddir custom_target_name)
  cmake_parse_arguments(_arg "CREATE_SUBDIRS" "DESTINATION" "FILES;DIRECTORIES" ${ARGN})
  set(timestampFiles)

  qtc_output_binary_dir(_output_binary_dir)

  foreach(srcFile ${_arg_FILES})
    string(MAKE_C_IDENTIFIER "${srcFile}" destinationTimestampFilePart)
    set(destinationTimestampFileName "${CMAKE_CURRENT_BINARY_DIR}/.${destinationTimestampFilePart}_timestamp")
    list(APPEND timestampFiles "${destinationTimestampFileName}")

    if (IS_ABSOLUTE "${srcFile}")
      set(srcPath "")
    else()
      get_filename_component(srcPath "${srcFile}" DIRECTORY)
    endif()

    add_custom_command(OUTPUT "${destinationTimestampFileName}"
      COMMAND "${CMAKE_COMMAND}" -E make_directory "${_output_binary_dir}/${_arg_DESTINATION}/${srcPath}"
      COMMAND "${CMAKE_COMMAND}" -E copy "${srcFile}" "${_output_binary_dir}/${_arg_DESTINATION}/${srcPath}"
      COMMAND "${CMAKE_COMMAND}" -E touch "${destinationTimestampFileName}"
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
      COMMENT "Copy ${srcFile} into build directory"
      DEPENDS "${srcFile}"
      VERBATIM
    )
  endforeach()

  foreach(srcDirectory ${_arg_DIRECTORIES})
    string(MAKE_C_IDENTIFIER "${srcDirectory}" destinationTimestampFilePart)
    set(destinationTimestampFileName "${CMAKE_CURRENT_BINARY_DIR}/.${destinationTimestampFilePart}_timestamp")
    list(APPEND timestampFiles "${destinationTimestampFileName}")
    set(destinationDirectory "${_output_binary_dir}/${_arg_DESTINATION}")

    if(_arg_CREATE_SUBDIRS)
      set(destinationDirectory "${destinationDirectory}/${srcDirectory}")
    endif()

    file(GLOB_RECURSE filesToCopy "${srcDirectory}/*")
    add_custom_command(OUTPUT "${destinationTimestampFileName}"
      COMMAND "${CMAKE_COMMAND}" -E copy_directory "${srcDirectory}" "${destinationDirectory}"
      COMMAND "${CMAKE_COMMAND}" -E touch "${destinationTimestampFileName}"
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
      COMMENT "Copy ${srcDirectory}/ into build directory"
      DEPENDS ${filesToCopy}
      VERBATIM
    )
  endforeach()

  add_custom_target("${custom_target_name}" ALL DEPENDS ${timestampFiles})
endfunction()

function(qtc_add_resources target resourceName)
  cmake_parse_arguments(rcc "" "PREFIX;LANG;BASE" "FILES;OPTIONS" ${ARGN})

  string(REPLACE "/" "_" resourceName ${resourceName})
  string(REPLACE "." "_" resourceName ${resourceName})

  # Apply base to all files
  if (rcc_BASE)
    foreach(file IN LISTS rcc_FILES)
      set(resource_file "${rcc_BASE}/${file}")
      file(TO_CMAKE_PATH ${resource_file} resource_file)
      list(APPEND resource_files ${resource_file})
    endforeach()
  else()
      set(resource_files ${rcc_FILES})
  endif()

  set(newResourceName ${resourceName})
  set(resources ${resource_files})

  set(generatedResourceFile "${CMAKE_CURRENT_BINARY_DIR}/.rcc/generated_${newResourceName}.qrc")
  set(generatedSourceCode "${CMAKE_CURRENT_BINARY_DIR}/.rcc/qrc_${newResourceName}.cpp")

  # Generate .qrc file:

  # <RCC><qresource ...>
  set(qrcContents "<RCC>\n  <qresource")
  if (rcc_PREFIX)
      string(APPEND qrcContents " prefix=\"${rcc_PREFIX}\"")
  endif()
  if (rcc_LANG)
      string(APPEND qrcContents " lang=\"${rcc_LANG}\"")
  endif()
  string(APPEND qrcContents ">\n")

  set(resource_dependencies)
  foreach(file IN LISTS resources)
    set(file_resource_path ${file})

    if (NOT IS_ABSOLUTE ${file})
        set(file "${CMAKE_CURRENT_SOURCE_DIR}/${file}")
    endif()

    ### FIXME: escape file paths to be XML conform
    # <file ...>...</file>
    string(APPEND qrcContents "    <file alias=\"${file_resource_path}\">")
    string(APPEND qrcContents "${file}</file>\n")
    list(APPEND files "${file}")
    list(APPEND resource_dependencies ${file})
    target_sources(${target} PRIVATE "${file}")
    set_property(SOURCE "${file}" PROPERTY HEADER_FILE_ONLY ON)
  endforeach()

  # </qresource></RCC>
  string(APPEND qrcContents "  </qresource>\n</RCC>\n")

  file(WRITE "${generatedResourceFile}.in" "${qrcContents}")
  configure_file("${generatedResourceFile}.in" "${generatedResourceFile}")

  set_property(TARGET ${target} APPEND PROPERTY _qt_generated_qrc_files "${generatedResourceFile}")

  set(rccArgs --name "${newResourceName}"
      --output "${generatedSourceCode}" "${generatedResourceFile}")
  if(rcc_OPTIONS)
      list(APPEND rccArgs ${rcc_OPTIONS})
  endif()

  # Process .qrc file:
  add_custom_command(OUTPUT "${generatedSourceCode}"
                     COMMAND Qt5::rcc ${rccArgs}
                     DEPENDS
                      ${resource_dependencies}
                      ${generatedResourceFile}
                      "Qt5::rcc"
                     COMMENT "RCC ${newResourceName}"
                     VERBATIM)

  target_sources(${target} PRIVATE "${generatedSourceCode}")
  set_property(SOURCE "${generatedSourceCode}" PROPERTY SKIP_AUTOGEN ON)
endfunction()

function(qtc_add_public_header header)
  if (NOT IS_ABSOLUTE ${header})
    set(header "${CMAKE_CURRENT_SOURCE_DIR}/${header}")
  endif()

  get_filename_component(source_dir ${header} DIRECTORY)
  file(RELATIVE_PATH include_dir_relative_path ${PROJECT_SOURCE_DIR} ${source_dir})

  install(
    FILES ${header}
    DESTINATION "include/${include_dir_relative_path}"
    COMPONENT Devel EXCLUDE_FROM_ALL
  )
endfunction()
