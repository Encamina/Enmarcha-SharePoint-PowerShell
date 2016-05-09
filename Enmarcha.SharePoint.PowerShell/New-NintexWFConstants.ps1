<#
.SYNOPSIS
   Creates a Nintex Workflow Constant
.DESCRIPTION
   
.PARAMETER <Name>
   Mandatory - the Name of the Constant. Keep these unique!
.PARAMETER <Description>
   Mandatory - the Description of the Constant. Use this to help other developers understand what it's used for.
.PARAMETER <Type>
   Mandatory - the Type of the Constant. Must be one of: Number, String, Date, SecureString, Credential
.PARAMETER <Scope>
   Mandatory - where the Constant is defined. Must be one of: Farm, SiteCollection, Web
.PARAMETER <Value>
   Optional - the value of the Constant. This isn't used for Credential type constants, but it's Mandatory for every other type.
.PARAMETER <Url>
   Optional - but Mandatory is the Scope is SiteCollection or Web. Defines where the Constant should live.
.PARAMETER <Sensitive>
   Optional - default value is $false.
.PARAMETER <AdminOnly>
   Optional - default value is $false.
.PARAMETER <Username>
   Optional - but Mandatory if Type is Credential.
.PARAMETER <Password>
   Optional - but Mandatory if Type is Credential.
.EXAMPLE
   #Here's an example that generates a Sensitive, Credential type constant at Web level:
   .\Create-NintexWFConstant.ps1 `
		-Name "test" `
		-Description "Example only" `
		-Scope "Web" `
		-Type "Credential" `
		-Sensitive $true `
		-Username "DOMAIN\user" `
		-Password "password123" `
		-Url "http://myfarm/sites/myweb"

	#Here's a second example that creates a Farm string type Constant:
	.\Create-NintexWFConstant.ps1 `
		-Name "test2" `
		-Description "Example only" `
		-Scope "Farm" `
		-Type "String" `
		-Value "example constant value"
#>

Param(
	[Parameter(Mandatory = $true, Position = 1)]
	[string] $Name,
	[Parameter(Mandatory = $true, Position = 2)]
	[string] $Description,
	[Parameter(Mandatory = $true, Position = 3)]
	[string] $Type,
	[Parameter(Mandatory = $true, Position = 4)]
	[string] $Scope,
	[Parameter(Mandatory = $false, Position = 5)]
	[string] $Value,
	[Parameter(Mandatory = $false, Position = 6)]
	[string] $Url,
	[Parameter(Mandatory = $false, Position = 7)]
	[bool] $Sensitive = $false,
	[Parameter(Mandatory = $false, Position = 8)]
	[bool] $AdminOnly = $false,
	[Parameter(Mandatory = $false, Position = 9)]
	[string] $Username = "",
	[Parameter(Mandatory = $false, Position = 10)]
	[string] $Password = ""
)

[System.Reflection.Assembly]::LoadWithPartialName('Nintex.Workflow') | Out-Null

$ArgsValid = $true

if ($Type -ne "Number" -and $Type -ne "String" -and $Type -ne "Date" -and $Type -ne "SecureString" -and $Type-ne "Credential")
{
	Write-Host "Error - El tipo debe ser uno de los siguientes: Number, String, Date, SecureString, Credential." -ForegroundColor Red
	$ArgsValid = $false
}

if ($Type -eq "Credential")
{
	if ($Username -eq $null -or $Username -eq "" -or $Password -eq $null -or $Password -eq "")
	{
		Write-Host "Error de credenciales - Username y Password no suministrados." -ForegroundColor Red
		$ArgsValid = $false
	}

	# Generate string for Credential
	$cred = New-Object Nintex.Workflow.CredentialValue($Username, $Password)
	$serialiser = New-Object System.Xml.Serialization.XmlSerializer($cred.GetType())
	$sb = New-Object System.Text.StringBuilder
	$sw = New-Object System.IO.StringWriter($sb)
	$serialiser.Serialize($sw, $cred)
	$Value = $sb.ToString()

}
else
{
	if ($Value -eq $null -or $Value -eq "")
	{
		Write-Host "Error - Se debe suministrar un Value para todas las constantes que sean de tipo distinto a Credential." -ForegroundColor Red
		$ArgsValid = $false
	}
}

$SiteId = [Guid]::Empty
$WebId = [Guid]::Empty

if ($Scope -eq "Farm")
{
	#Use default SiteId and WebId values
}
else
{
	if ($Scope -eq "SiteCollection")
	{
		$SiteId = (Get-SPSite $Url).Id
	}
	else
	{
		if ($Scope -eq "Web")
		{
			$Web = Get-SPWeb $Url
			$WebId = $Web.Id
			$SiteId = $Web.Site.Id
		}
		else
		{
			Write-Host "Error - Parámetro Scope no válido: debe ser Farm, SiteCollection o Web." -ForegroundColor Red
			$ArgsValid = $false
		}
	}
}


if ($ArgsValid)
{
	Write-Host ("Intentando crear la constante de flujo de trabajo " + $Name + " ... ") -NoNewline 

	$constant = New-Object Nintex.Workflow.WorkflowConstant(`
		$Name, $Description, $Value, $Sensitive, $SiteId, $WebId, $Type, $AdminOnly)

	$constant.Update()

}
