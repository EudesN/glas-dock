# Glasdock blur helper: a tiny QML module (org.glasdock.blur) that lets the
# widgets ask KWin to blur the desktop behind their glass, in its exact shape.
# Built and installed by ../install.sh into ~/.local/lib/qt6/qml.
cmake_minimum_required(VERSION 3.20)
project(glasdockblur LANGUAGES CXX)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Gui)
find_package(KF6WindowSystem REQUIRED)

qt_standard_project_setup(REQUIRES 6.5)
# the QML plugin must be a shared library (loaded at runtime by plasmashell)
set(BUILD_SHARED_LIBS ON)

# one target that is both the module and its (shared) plugin
qt_add_qml_module(glasdockblurplugin
    URI org.glasdock.blur
    VERSION 1.0
    PLUGIN_TARGET glasdockblurplugin
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/org/glasdock/blur
    SOURCES blurbehind.h blurbehind.cpp
)
target_link_libraries(glasdockblurplugin PRIVATE Qt6::Quick KF6::WindowSystem)
