# NBN Cloud: marca do cliente desktop.
# Fork do ownCloud Desktop 6.0.x (GPLv2), https://github.com/NBN-PATRIC/nbn-cloud-desktop
# O THEME.cmake inclui este arquivo sozinho quando existe a pasta branding/ na raiz.

set( APPLICATION_NAME       "NBN Cloud" )
set( APPLICATION_SHORTNAME  "NBNCloud" )
set( APPLICATION_EXECUTABLE "nbncloud" )
set( APPLICATION_DOMAIN     "nbntelecom.com.br" )
set( APPLICATION_VENDOR     "NBN Telecom" )
set( APPLICATION_UPDATE_URL "" CACHE STRING "URL for updater" )
set( APPLICATION_ICON_NAME  "nbncloud" )
set( APPLICATION_VIRTUALFILE_SUFFIX "nbncloud" CACHE STRING "Virtual file suffix (not including the .)")

set( LINUX_PACKAGE_SHORTNAME "nbncloud" )

set( THEME_CLASS            "NbnCloudTheme" )
set( THEME_INCLUDE          "${OEM_THEME_DIR}/nbncloudtheme.h" )
set( APPLICATION_REV_DOMAIN "br.com.nbntelecom.cloud.desktop" )
set( WIN_SETUP_BITMAP_PATH  "${CMAKE_SOURCE_DIR}/admin/win/nsi" )
set( MAC_INSTALLER_BACKGROUND_FILE "${CMAKE_SOURCE_DIR}/admin/osx/installer-background.png" CACHE STRING "The MacOSX installer background image")

# Atualização automática desligada por enquanto: o instalador novo é distribuído pela NBN.
set( WITHOUT_AUTO_UPDATER ON )

option( WITH_CRASHREPORTER "Build crashreporter" OFF )
set( CRASHREPORTER_SUBMIT_URL "" CACHE STRING "URL for crash reporter" )
