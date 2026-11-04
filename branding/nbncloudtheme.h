/*
 * NBN Cloud: tema da marca.
 * Incluído só pelo src/libsync/theme.cpp (THEME_INCLUDE), por isso é só cabeçalho e sem Q_OBJECT:
 * as propriedades do Theme chamam os métodos virtuais e caem nas sobrescritas daqui.
 *
 * Baseado no ownCloud Desktop (GPLv2). Este arquivo segue a mesma licença.
 */
#pragma once

#include "common/utility.h"
#include "common/version.h"
#include "resources/resources.h"
#include "theme.h"

#include <QColor>
#include <QIcon>
#include <QString>

namespace OCC {

class NbnCloudTheme : public Theme
{
public:
    NbnCloudTheme()
        : Theme()
    {
    }

    // cores do timbrado da NBN
    QColor wizardHeaderBackgroundColor() const override { return QColor(0x1F, 0x2A, 0x44); }
    QColor wizardHeaderTitleColor() const override { return Qt::white; }
    QIcon wizardHeaderLogo() const override { return Resources::themeUniversalIcon(QStringLiteral("wizard_logo")); }

    QmlButtonColor primaryButtonColor() const override
    {
        const QColor botao(0x44, 0x72, 0xC3);
        return {botao, Qt::white, botao.darker()};
    }

    QmlButtonColor secondaryButtonColor() const override { return {QColor(0xD4, 0xD3, 0xD0), Qt::black, QColor(Qt::black).lighter()}; }

    // arquivo apagado no servidor vai para a lixeira do Windows, não some de vez
    bool moveToTrashDefaultValue() const override { return true; }

    // sem página de ajuda ainda: some o item "Ajuda" do menu
    QString helpUrl() const override { return QString(); }

    // Servidor sugerido: o que vier do instalador/GPO; sem nada, o NBN Cloud corporativo.
    QString suggestedServerUrl() const override
    {
        const QString url = Theme::suggestedServerUrl();
        return url.isEmpty() ? QStringLiteral("https://cloud.nbntelecom.com.br") : url;
    }

    QString about() const override
    {
        return QStringLiteral(
            "<p>Versão %1.</p>"
            "<p>O NBN Cloud é distribuído pela NBN Telecom: <a href=\"https://www.nbntelecom.com.br\">www.nbntelecom.com.br</a></p>"
            "<p>Baseado no ownCloud Desktop, Copyright ownCloud GmbH (A Kiteworks Company) e colaboradores, "
            "licenciado sob a GNU General Public License (GPL) versão 2.0.<br/>"
            "Código-fonte desta versão: <a href=\"https://github.com/NBN-PATRIC/nbn-cloud-desktop\">github.com/NBN-PATRIC/nbn-cloud-desktop</a></p>"
            "<p><small>ownCloud é marca registrada da ownCloud GmbH. O NBN Cloud não é afiliado à ownCloud GmbH "
            "nem endossado por ela.</small></p>"
            "<p><small>%2</small></p>")
            .arg(Utility::escape(Version::displayString()), aboutVersions(Theme::VersionFormat::RichText));
    }
};

} // namespace OCC
