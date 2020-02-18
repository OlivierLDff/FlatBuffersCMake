include(CMakeParseArguments)

function(add_fbs_target TARGET SOURCES)

    set(FBS_OPTIONS VERBOSE
        RC_SCHEMAS
        )
    set(FBS_ONE_VALUE_ARG
        GENERATED_INCLUDE_DIR
        BINARY_SCHEMA_DIR
        COPY_TEXT_SCHEMA_DIR
        )
    set(FBS_MULTI_VALUE_ARG
        DEPENDENCIES
        FLATC_ARGUMENTS
        INCLUDE_DIR
        )
     # parse the function arguments
    cmake_parse_arguments(ARGFBS "${FBS_OPTIONS}" "${FBS_ONE_VALUE_ARG}" "${FBS_MULTI_VALUE_ARG}" ${ARGN})

    set(FBS_TARGET ${TARGET})
    set(FBS_SRCS ${SOURCES})
    set(FBS_VERBOSE ${ARGFBS_VERBOSE})
    set(FBS_RC_SCHEMAS ${ARGFBS_RC_SCHEMAS})
    set(FBS_GENERATED_INCLUDE_DIR ${ARGFBS_GENERATED_INCLUDE_DIR})
    set(FBS_BINARY_SCHEMA_DIR ${ARGFBS_BINARY_SCHEMA_DIR})
    set(FBS_COPY_TEXT_SCHEMA_DIR ${ARGFBS_COPY_TEXT_SCHEMA_DIR})
    set(FBS_DEPENDENCIES ${ARGFBS_DEPENDENCIES})
    set(FBS_FLATC_ARGUMENTS ${ARGFBS_FLATC_ARGUMENTS})
    set(FBS_INCLUDE_DIR ${ARGFBS_INCLUDE_DIR})

    # Print verbose parameters for easy debugging
    if(FBS_VERBOSE)

        message(STATUS "Add Flat Buffers generated target : ${TARGET}")
        message(STATUS "FBS_TARGET                : ${FBS_TARGET}")
        message(STATUS "FBS_SRCS                  : ${FBS_SRCS}")
        message(STATUS "FBS_VERBOSE               : ${FBS_VERBOSE}")
        message(STATUS "FBS_RC_SCHEMAS          : ${FBS_RC_SCHEMAS}")
        message(STATUS "FBS_GENERATED_INCLUDE_DIR : ${FBS_GENERATED_INCLUDE_DIR}")
        message(STATUS "FBS_BINARY_SCHEMA_DIR     : ${FBS_BINARY_SCHEMA_DIR}")
        message(STATUS "FBS_COPY_TEXT_SCHEMA_DIR  : ${FBS_COPY_TEXT_SCHEMA_DIR}")
        message(STATUS "FBS_DEPENDENCIES          : ${FBS_DEPENDENCIES}")
        message(STATUS "FBS_FLATC_ARGUMENTS       : ${FBS_FLATC_ARGUMENTS}")
        message(STATUS "FBS_INCLUDE_DIR           : ${FBS_INCLUDE_DIR}")

    endif(FBS_VERBOSE)

    # ALl the generated created by this function
    set(ALL_GENERATED_FILES "")
    set(INCLUDE_PARAMS "")

    if(FBS_RC_SCHEMAS)
        if(NOT TARGET flat2h)
            if(FBS_VERBOSE)
                message(STATUS "Create flat2h from ${FLATBUFFERS_CMAKE_ROOT}/src/flat2h.cpp")
            endif()
            add_executable(flat2h ${FLATBUFFERS_CMAKE_ROOT}/src/flat2h.cpp)
            set_target_properties(flat2h
                PROPERTIES FOLDER ${FBS_FOLDER_PREFIX})
            if(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
                target_compile_definitions(flat2h PRIVATE -D_CRT_SECURE_NO_WARNINGS)
            endif()
        endif()
    endif()

    # Generate the include file param
    # The form is -I path/to/dir1 -I path/to/dir2 etc...
    foreach (INCLUDE_DIR ${FBS_INCLUDE_DIR})

        set(INCLUDE_PARAMS -I ${INCLUDE_DIR} ${INCLUDE_PARAMS})

    endforeach()

    foreach(SRC ${FBS_SRCS})

        # Isolate filename to create the generated filename
        get_filename_component(FILENAME ${SRC} NAME_WE)

        # We check that we have an output directory before generating a rule
        if (NOT ${FBS_GENERATED_INCLUDE_DIR} STREQUAL "")

            # Name of the output generated file
            set(GENERATED_INCLUDE ${FBS_GENERATED_INCLUDE_DIR}/${FILENAME}_generated.h)

            # Add the rule for each files
            message(STATUS "Add rule to build ${FILENAME}_generated.h from ${SRC}")
            add_custom_command(
                OUTPUT ${GENERATED_INCLUDE}
                COMMAND flatc ${FBS_FLATC_ARGUMENTS}
                -o ${FBS_GENERATED_INCLUDE_DIR}
                ${INCLUDE_PARAMS}
                -c ${SRC}
                DEPENDS flatc ${SRC} ${FBS_DEPENDENCIES}
                COMMENT "Generate ${GENERATED_INCLUDE} from ${SRC}"
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
            list(APPEND ALL_GENERATED_FILES ${GENERATED_INCLUDE})

            if(FBS_RC_SCHEMAS)

                # Name of the output generated file
                set(GENERATED_RC ${FBS_GENERATED_INCLUDE_DIR}/${FILENAME}_rc.h)

                message(STATUS "Add rule to build ${GENERATED_RC} from ${SRC}")
                add_custom_command(
                    OUTPUT ${GENERATED_RC}
                    COMMAND flat2h
                    -i ${SRC}
                    -o ${GENERATED_RC}
                    DEPENDS flat2h ${SRC} ${FBS_DEPENDENCIES}
                    COMMENT "Generate ${GENERATED_RC} from ${SRC}"
                    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
                list(APPEND ALL_GENERATED_FILES ${GENERATED_RC})
            endif()

        endif() # (NOT ${FBS_GENERATED_INCLUDE_DIR} STREQUAL "")

        # Should we also build bfbs
        if (NOT ${FBS_BINARY_SCHEMA_DIR} STREQUAL "")

            # Name of the output binary buffer file
            set(BINARY_SCHEMA ${FBS_BINARY_SCHEMA_DIR}/${FILENAME}.bfbs)
            message(STATUS "Add rule to build ${FILENAME}.bfbs from ${SRC}")
            add_custom_command(
                OUTPUT ${BINARY_SCHEMA}
                COMMAND flatc -b --schema
                -o ${FBS_BINARY_SCHEMA_DIR}
                ${INCLUDE_PARAMS}
                ${SRC}
                DEPENDS ${FLATC_TARGET} ${SRC} ${FBS_DEPENDENCIES}
                COMMENT "Generate ${FILENAME}.bfbs in ${FBS_GENERATED_INCLUDE_DIR} from ${SRC}"
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
            list(APPEND ALL_GENERATED_FILES ${BINARY_SCHEMA})

        endif() # (NOT ${FBS_BINARY_SCHEMA_DIR} STREQUAL "")

        if (NOT ${FBS_COPY_TEXT_SCHEMA_DIR} STREQUAL "")

            # Name of the output binary buffer file
            set(COPY_SCHEMA ${FBS_COPY_TEXT_SCHEMA_DIR}/${FILENAME}.fbs)
            message(STATUS "Add rule to copy ${FILENAME}.fbs")
            add_custom_command(
                OUTPUT ${COPY_SCHEMA}
                COMMAND ${CMAKE_COMMAND} -E copy ${SRC} ${COPY_SCHEMA}
                DEPENDS ${FLATC_TARGET} ${SRC} ${FBS_DEPENDENCIES}
                COMMENT "Copy file ${SRC} to ${COPY_SCHEMA}"
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
            list(APPEND ALL_GENERATED_FILES ${COPY_SCHEMA})
        endif() # (NOT ${FBS_COPY_TEXT_SCHEMA_DIR} STREQUAL "")

    endforeach() # SRC ${FBS_SRCS}

    if(FBS_VERBOSE)
        message(STATUS "${FBS_TARGET} generated files : ${ALL_GENERATED_FILES}")
    endif(FBS_VERBOSE)

    add_custom_target(${FBS_TARGET}
        DEPENDS flatc ${ALL_GENERATED_FILES} ${FBS_DEPENDENCIES}
    )


endfunction()
