Param
(

)
Process
{
	.\Package\Package-SP.ps1
	.\CreateSite.ps1 -UrlWebApplication "http://enmarchaweb" -OwnerAlias "ENMARCHA\sp_admin" -PathWsp "C:\WSP\" -PathConfiguration "C:\TFS\Main\Enmarcha.SharePoint.PowerShell\Proyecto\" -Force -ConfigurationRelative
}