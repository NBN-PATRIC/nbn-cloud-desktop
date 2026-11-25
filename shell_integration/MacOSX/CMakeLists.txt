if(APPLE)
set(OC_OEM_SHARE_ICNS "${CMAKE_BINARY_DIR}/src/gui/${APPLICATION_ICON_NAME}.icns")

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(XCODE_CONFIG "Debug")
else()
    set(XCODE_CONFIG "Release")
endif()

# The bundle identifier and application group need to have compatible values with the client
# to be able to open a Mach port across the extension's sandbox boundary.
# Pass the info through the xcodebuild command line and make sure that the project uses
# those user-defined settings to build the plist.
add_custom_target( mac_overlayplugin ALL
    xcodebuild -project ${CMAKE_SOURCE_DIR}/shell_integration/MacOSX/OwnCloudFinderSync/OwnCloudFinderSync.xcodeproj
        -target FinderSyncExt -configuration "${XCODE_CONFIG}" "SYMROOT=${CMAKE_CURRENT_BINARY_DIR}"
        "OC_OEM_SHARE_ICNS=${OC_OEM_SHARE_ICNS}"
        "OC_APPLICATION_NAME=${APPLICATION_NAME}"
        "OC_APPLICATION_REV_DOMAIN=${APPLICATION_REV_DOMAIN}"
        "OC_SOCKETAPI_TEAM_IDENTIFIER_PREFIX=${SOCKETAPI_TEAM_IDENTIFIER_PREFIX}"
    COMMENT building Mac Overlay icons
    VERBATIM)
add_dependencies(mac_overlayplugin owncloud) # for the ownCloud.icns to be generated
add_custom_command(TARGET mac_overlayplugin POST_BUILD COMMAND ${CMAKE_COMMAND}
    ARGS -E copy_directory "${CMAKE_CURRENT_BINARY_DIR}/${XCODE_CONFIG}/FinderSyncExt.appex" "$<TARGET_FILE_DIR:owncloud>/../PlugIns/FinderSyncExt.appex" MAIN_DEPENDENCY "${mac_overlayplugin}")

# NBN Cloud: extensão File Provider (arquivos virtuais no Finder), em NBNCloudFileProvider/. Precisa do xcodegen e
# do NextcloudFileProviderKit em _externo/NextcloudFileProviderKit (o CI baixa num commit fixo e aplica
# NBNCloudFileProvider/patches/aplicar.py). Sem eles, o app sai sem arquivos virtuais no macOS.
set(NBN_FP_DIR "${CMAKE_SOURCE_DIR}/shell_integration/MacOSX/NBNCloudFileProvider")
set(NBN_FP_DD "${CMAKE_CURRENT_BINARY_DIR}/nbn-fileprovider")
find_program(XCODEGEN_EXECUTABLE xcodegen)
if(XCODEGEN_EXECUTABLE AND EXISTS "${CMAKE_SOURCE_DIR}/_externo/NextcloudFileProviderKit/Package.swift")
    add_custom_target(nbn_fileprovider ALL
        COMMAND "${XCODEGEN_EXECUTABLE}" generate --spec "${NBN_FP_DIR}/project.yml"
        COMMAND xcodebuild -project "${NBN_FP_DIR}/NBNCloudFileProvider.xcodeproj" -scheme NBNCloudFileProviderExt
            -configuration Release -derivedDataPath "${NBN_FP_DD}" -destination generic/platform=macOS
            "ARCHS=arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- "NBN_FP_HOST_ID=${APPLICATION_REV_DOMAIN}" build
        WORKING_DIRECTORY "${NBN_FP_DIR}"
        COMMENT "NBN Cloud: extensão File Provider"
        VERBATIM)
    add_dependencies(nbn_fileprovider owncloud)
    # ditto preserva os links simbólicos do framework (copy_directory os desfaria e quebraria a assinatura)
    add_custom_command(TARGET nbn_fileprovider POST_BUILD
        COMMAND rm -rf "$<TARGET_FILE_DIR:owncloud>/../PlugIns/NBNCloudFileProviderExt.appex"
        COMMAND ditto "${NBN_FP_DD}/Build/Products/Release/NBNCloudFileProviderExt.appex" "$<TARGET_FILE_DIR:owncloud>/../PlugIns/NBNCloudFileProviderExt.appex"
        COMMAND rm -rf "$<TARGET_FILE_DIR:owncloud>/../Frameworks/RealmSwift.framework"
        COMMAND ditto "${NBN_FP_DD}/Build/Products/Release/PackageFrameworks/RealmSwift.framework" "$<TARGET_FILE_DIR:owncloud>/../Frameworks/RealmSwift.framework"
        VERBATIM)
    message(STATUS "NBN Cloud: extensão File Provider entra no app")
else()
    message(STATUS "NBN Cloud: sem xcodegen ou sem o NextcloudFileProviderKit, app sem arquivos virtuais no macOS")
endif()

endif()

