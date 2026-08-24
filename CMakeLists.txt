# =============================================================================
# DES/26 -- DynamicElastomerSolver 2026
#
# Elastomer bilesenler icin 2B nonlineer sonlu elemanlar cozucusu.
# Bu dosya YALNIZCA Fortran hesaplama cekirdegini kurar; C++ mesh katmani
# ve Python orkestrasyonu sonraki fazlarda eklenecektir.
#
# NOT: Bu dosya ASCII tutulmustur -- tek istisna, asagidaki UTF-8 notunda
# ornek olarak alintilanan Turkce karakterlerdir. Kaynak kod yorumlari ise
# tam Turkcedir; gerekcesi icin ayni nota bakiniz.
# =============================================================================
cmake_minimum_required(VERSION 3.20)

project(DES26
    VERSION 0.0.1
    DESCRIPTION "DynamicElastomerSolver 2026 -- nonlinear FE core for elastomers"
    LANGUAGES Fortran)

# --- Cikti duzeni ------------------------------------------------------------
set(CMAKE_Fortran_MODULE_DIRECTORY "${CMAKE_BINARY_DIR}/mod")

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Yapi turu" FORCE)
endif()

# -----------------------------------------------------------------------------
# Derleyici bayraklari
#
# UTF-8 HAKKINDA: gfortran, kaynak dosyalardaki UTF-8 baytlarini yorum
# satirlarinda sorunsuz gecirir; ek bir bayrak GEREKMEZ. gfortran'in
# -finput-charset secenegi yalnizca C/C++/ObjC icin gecerlidir ve Fortran'a
# verilirse su uyariyi uretir:
#
#   Warning: command-line option '-finput-charset=UTF-8' is valid for
#            C/C++/ObjC/ObjC++ but not for Fortran
#
# Bu yuzden bilincli olarak EKLENMEMISTIR. gfortran 16.2 ile
# -std=f2018 -Wall -Wextra altinda "ç ğ ı ö ş ü" karakterleri tek bir uyari
# bile uretmeden derlenir. Turkce karakterler yalnizca YORUMLARDA kullanilir;
# tanimlayicilar ve karakter sabitleri ASCII kalir.
# -----------------------------------------------------------------------------
add_library(des_flags INTERFACE)

if(CMAKE_Fortran_COMPILER_ID STREQUAL "GNU")
    target_compile_options(des_flags INTERFACE
        -std=f2018 -Wall -Wextra -fimplicit-none
        $<$<CONFIG:Debug>:-O0>
        $<$<CONFIG:Debug>:-g>
        $<$<CONFIG:Debug>:-fcheck=all>
        $<$<CONFIG:Debug>:-fbacktrace>
        $<$<CONFIG:Release>:-O2>)

    # -ffpe-trap her platformda desteklenmez (ozellikle macOS/arm64).
    # Destekleniyorsa Debug'a eklenir; degilse sessizce atlanir.
    include(CheckFortranCompilerFlag)
    check_fortran_compiler_flag("-ffpe-trap=invalid,zero,overflow" DES_HAS_FPE_TRAP)
    if(DES_HAS_FPE_TRAP)
        target_compile_options(des_flags INTERFACE
            $<$<CONFIG:Debug>:-ffpe-trap=invalid,zero,overflow>)
    endif()

elseif(CMAKE_Fortran_COMPILER_ID MATCHES "Intel")
    target_compile_options(des_flags INTERFACE
        $<$<CONFIG:Debug>:-O0>
        $<$<CONFIG:Debug>:-g>
        $<$<CONFIG:Debug>:-check all>
        $<$<CONFIG:Debug>:-traceback>
        $<$<CONFIG:Release>:-O2>)
endif()

# -----------------------------------------------------------------------------
# Hesaplama cekirdegi
#
# Katman 4 (analiz) ve katman 5 (sayisal temel). Bu kutuphane dosya acmaz,
# yazdirmaz, durmaz -- bkz. CLAUDE.md.
# -----------------------------------------------------------------------------
add_library(des_core STATIC
    src/des_kinds.f90
    src/des_tensor.f90
    src/des_material.f90
    src/des_mat_neohookean.f90
    src/des_mesh.f90
    src/des_sparse.f90
    src/des_element.f90
    src/des_elem_axi_q4.f90)

target_link_libraries(des_core PUBLIC des_flags)
target_include_directories(des_core PUBLIC "${CMAKE_Fortran_MODULE_DIRECTORY}")

# --- Gecici duman testi surucusu ---------------------------------------------
add_executable(des26 app/main.f90)
target_link_libraries(des26 PRIVATE des_core)

# -----------------------------------------------------------------------------
# Dogrulama testleri
# -----------------------------------------------------------------------------
include(CTest)
enable_testing()

add_library(des_test_support STATIC test/test_support.f90)
target_link_libraries(des_test_support PUBLIC des_core)

function(des_add_test name)
    add_executable(${name} test/${name}.f90)
    target_link_libraries(${name} PRIVATE des_test_support)
    add_test(NAME ${name} COMMAND ${name})
endfunction()

des_add_test(check_material_tangent)
des_add_test(check_uniaxial)
des_add_test(check_stability)
des_add_test(check_contract)
des_add_test(check_element_contract)
des_add_test(check_elem_axi_q4)
