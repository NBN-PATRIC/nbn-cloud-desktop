/*
 * NBN Cloud: arquivos virtuais no macOS pela extensão File Provider (shell_integration/MacOSX/NBNCloudFileProvider).
 *
 * Só o teste de disponibilidade, sem código Objective-C, para o tema (libsync) e o assistente (newwizard) usarem.
 * A integração em si fica em src/gui/macOS/nbnfileprovider_mac.mm.
 *
 * Baseado no ownCloud Desktop (GPLv2 ou posterior). Este arquivo segue a mesma licença.
 */
#pragma once

#include <QCoreApplication>
#include <QFileInfo>
#include <QOperatingSystemVersion>
#include <QString>

namespace OCC {

  /// Nome do pacote da extensão dentro de NBN Cloud.app/Contents/PlugIns.
  inline QString nbnMacFileProviderExtensionName()
  {
    return QStringLiteral("NBNCloudFileProviderExt.appex");
  }

  /// Verdadeiro no macOS 13 ou mais novo quando o app traz a extensão File Provider.
  inline bool nbnMacFileProviderAvailable()
  {
#ifdef Q_OS_MACOS
    if (QOperatingSystemVersion::current() < QOperatingSystemVersion::MacOSVentura) {
        return false;
    }
    return QFileInfo::exists(QCoreApplication::applicationDirPath() + QStringLiteral("/../PlugIns/") + nbnMacFileProviderExtensionName());
#else
    return false;
#endif
  }

} // namespace OCC
