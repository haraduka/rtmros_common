#cmake_minimum_required(VERSION 2.4.6) ## this file is included from rtmbuild.cmake and cmake_minimum_required is defined in that file

# generate msg/srv files from idl, this will be called in rtmbuild_init
macro(rtmbuild_genbridge_init)
  message("[rtmbuild_genbridge_init] Generating bridge compornents from idl")
  rtmbuild_get_idls(_idllist)
  if(NOT _idllist)
    message_warn("[rtmbuild_genbridge_init] WARNING: rtmbuild_genbridge() was called, but no .idl files ware found")
  else(NOT _idllist)
    file(MAKE_DIRECTORY ${PROJECT_SOURCE_DIR}/msg)
    file(MAKE_DIRECTORY ${PROJECT_SOURCE_DIR}/srv)
  endif(NOT _idllist)

  execute_process(COMMAND ${_openrtm_aist_pkg_dir}/bin/rtm-config --cflags OUTPUT_VARIABLE _rtm_include_dir OUTPUT_STRIP_TRAILING_WHITESPACE)
  execute_process(COMMAND sh -c "echo ${_rtm_include_dir} | sed 's/^-[^I]\\S*//g' | sed 's/\ -[^I]\\S*//g' | sed 's/-I//g'" OUTPUT_VARIABLE _rtm_include_dir OUTPUT_STRIP_TRAILING_WHITESPACE)
  set(_include_dirs "${_rtm_include_dir} ${_openhrp3_pkg_dir}/share/OpenHRP-3.1/idl")

  set(_autogen "")
  foreach(_idl ${_idllist})
    message("[rtmbuild_genbridge_init] Generate msgs/srvs from ${_idl}")
    message("[rtmbuild_genbridge_init] ${_rtmbuild_pkg_dir}/scripts/idl2srv.py --filenames -i ${PROJECT_SOURCE_DIR}/idl/${_idl} --include-dirs=\"${_include_dirs}\"")
    execute_process(COMMAND ${_rtmbuild_pkg_dir}/scripts/idl2srv.py --filenames -i ${PROJECT_SOURCE_DIR}/idl/${_idl} --include-dirs="${_include_dirs}" OUTPUT_VARIABLE _autogen_files OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(_autogen_files)
      string(REPLACE "\n" ";" _autogen_files  ${_autogen_files})
      # remove already generated msg(_autogen) from _autogen_files
      foreach(_autogen_file ${_autogen_files})
	list(FIND _autogen ${_autogen_file} _found_autogen_file)
	if(${_found_autogen_file} GREATER -1)
	  list(REMOVE_ITEM _autogen_files ${_autogen_file})
	  message("[rtmbuild_genbridge_init] remove already generated file ${_autogen_file}")
	endif(${_found_autogen_file} GREATER -1)
      endforeach(_autogen_file ${_autogen_files})

      # check if idl or idl2srv servicebridge.cmake are newer than generated files
      set(_remove_autogen_files 0)
      foreach(_autogen_file ${_autogen_files})
        if(${PROJECT_SOURCE_DIR}/idl/${_idl} IS_NEWER_THAN ${_autogen_file} OR
           ${rtmbuild_PACKAGE_PATH}/scripts/idl2srv.py IS_NEWER_THAN ${_autogen_file} OR
           ${rtmbuild_PACKAGE_PATH}/cmake/servicebridge.cmake IS_NEWER_THAN ${_autogen_file})
         set(_remove_autogen_files 1)
       endif()
      endforeach(_autogen_file ${_autogen_files})
      if(_remove_autogen_files)
	message("[rtmbuild_genbridge_init] idl or idl2srv or cervicebridge.cmake is newer than generated fils")
	message("[rtmbuild_genbridge_init] remove ${_autogen_files}")
        file(REMOVE ${_autogen_files})
      endif()

      list(APPEND _autogen ${_autogen_files})
      get_filename_component(_project_name ${CMAKE_SOURCE_DIR} NAME)
      execute_process(COMMAND ${_rtmbuild_pkg_dir}/scripts/idl2srv.py -i ${PROJECT_SOURCE_DIR}/idl/${_idl} --include-dirs=${_include_dirs} --tmpdir=/tmp/idl2srv/${_project_name})
    endif(_autogen_files)
    set(_generated_msgs_from_idl "")
  endforeach(_idl)

  if(_autogen)
    # Also set up to clean the generated msg/srv/cpp/h files
    get_directory_property(_old_clean_files ADDITIONAL_MAKE_CLEAN_FILES)
    list(APPEND _old_clean_files ${_autogen})
    set_directory_properties(PROPERTIES ADDITIONAL_MAKE_CLEAN_FILES "${_old_clean_files}")
  endif(_autogen)
endmacro(rtmbuild_genbridge_init)

macro(rtmbuild_genbridge)
  rosbuild_genmsg()
  rosbuild_gensrv()
  rtmbuild_get_idls(_idllist)
  # rm tmp/idl2srv
  add_custom_command(OUTPUT /_tmp/idl2srv
    COMMAND rm -fr /tmp/idl2srv/${_project} DEPENDS ${_autogen})
  add_dependencies(rtmbuild_genbridge RTMBUILD_rm_idl2srv)
  add_custom_target(RTMBUILD_rm_idl2srv ALL DEPENDS /_tmp/idl2srv ${rtmbuild_PACKAGE_PATH}/scripts/idl2srv.py ${rtmbuild_PACKAGE_PATH}/cmake/servicebridge.cmake)
  #
  foreach(_idl ${_idllist})
    execute_process(COMMAND ${_rtmbuild_pkg_dir}/scripts/idl2srv.py --interfaces -i ${PROJECT_SOURCE_DIR}/idl/${_idl} --include-dirs="${_include_dirs}" OUTPUT_VARIABLE _interface
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(_interface)
      string(REPLACE "\n" ";" _interface ${_interface})
      foreach(_comp ${_interface})
	message("[rtmbuild_genbridge] ${_idl} -> ${_comp}ROSBridgeComp")
	rtmbuild_add_executable("${_comp}ROSBridgeComp" "src_gen/${_comp}ROSBridge.cpp" "src_gen/${_comp}ROSBridgeComp.cpp")
      endforeach(_comp)
    endif(_interface)
  endforeach(_idl)
  get_directory_property(_old_clean_files ADDITIONAL_MAKE_CLEAN_FILES)
  list(APPEND _old_clean_files ${PROJECT_SOURCE_DIR}/src_gen)
  set_directory_properties(PROPERTIES ADDITIONAL_MAKE_CLEAN_FILES "${_old_clean_files}")
endmacro(rtmbuild_genbridge)
