cmake_minimum_required(VERSION 3.0)
project(f2c)

set(the_target f2c)

find_package(BISON REQUIRED)

set(gram_c ${CMAKE_CURRENT_BINARY_DIR}/gram.c)
set(tokdefs_h ${CMAKE_CURRENT_BINARY_DIR}/tokdefs.h)

bison_target(f2cparser "src/gram.y" ${gram_c}
             #COMPILE_FLAGS "-y"
             DEFINES_FILE ${tokdefs_h}
             )

set(srcs
    src/main.c
    src/init.c
    src/lex.c
    src/proc.c
    src/equiv.c
    src/data.c
    src/format.c
	src/expr.c
    src/exec.c
    src/intr.c
    src/io.c
    src/misc.c
    src/error.c
    src/mem.c
    src/names.c
	src/output.c
    src/p1output.c
    src/pread.c
    src/put.c
    src/putpcc.c
    src/vax.c
    src/formatdata.c
	src/parse_args.c
    src/niceprintf.c
    src/cds.c
    src/sysdep.c
    src/version.c
    src/gram.y
    ${BISON_f2cparser_OUTPUTS}
)
    
set(hdrs    
    src/defines.h
    src/defs.h
    src/f2c.h
    src/format.h
    src/ftypes.h
    src/iob.h
    src/machdefs.h
    src/names.h
    src/niceprintf.h
    src/output.h
    src/p1defs.h
    src/parse.h
    src/pccdefs.h
    src/sysdep.h
    src/usignal.h
)

add_executable(${the_target} ${srcs} ${hdrs})
include_directories(src)
include_directories(${CMAKE_CURRENT_BINARY_DIR})

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-parentheses")
