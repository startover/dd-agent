<xsl:stylesheet version="1.0"
            xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
            xmlns:msxsl="urn:schemas-microsoft-com:xslt"
            exclude-result-prefixes="msxsl"
            xmlns:wix="http://schemas.microsoft.com/wix/2006/wi"
            xmlns:my="my:my">

    <xsl:output method="xml" indent="yes" />

    <xsl:strip-space elements="*"/>

    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="wix:Component[wix:File[@Source='$(var.InstallFilesBins)\ddagent.exe']]">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" />
            <wix:ServiceInstall Id="ServiceInstaller" DisplayName="OneAPM Agent" Description="Send metrics to OneAPM" Name="OneAPMAgent" ErrorControl="ignore" Start="auto" Type="ownProcess" Vital="yes" Interactive="no" Account="LocalSystem">
                <wix:ServiceDependency Id="winmgmt" />
            </wix:ServiceInstall>
            <wix:ServiceControl Id="StartService" Name="OneAPMAgent" Start="install" Stop="both" Remove="uninstall" Wait="no" />
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>