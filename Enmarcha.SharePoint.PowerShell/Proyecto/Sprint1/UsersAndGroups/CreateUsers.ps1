Param
(
    [Parameter(Mandatory=$false)]
    [string]$UsersFile = $(Read-Host -Prompt "Users file"),
    [Parameter(Mandatory=$false)]  
    [string]$WebSiteUrl = $(Read-Host -Prompt "Web site url"),
    [switch] $Clear
)

#####################################################
# Script to insert users into groups in a web site
#####################################################

$snapin = Get-PSSnapin Microsoft.SharePoint.Powershoell -ErrorAction SilentlyContinue
if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }
#[Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint");

$currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition


Write-Host -ForegroundColor Cyan "comenzando";

Write-Host -ForegroundColor Gray "abriendo sitio web " $WebSiteUrl
$web = Get-SPWeb($WebSiteUrl);

$file = Import-Csv -Path $UsersFile -Encoding UTF8 -Delimiter ";"

foreach($row in $file)
{
    if($Clear.IsPresent) #se ha pedido limpiar
    {
        if($web.SiteGroups[$row.SPSGroup] -ne $null)
        {
            Write-host -ForegroundColor Cyan "eliminando los usuarios del grupo '"$row.SPSGroup"'..." -NoNewline
            $users = $web.SiteGroups
            $siteGroup = $web.SiteGroups[$row.SPSGroup]
            #Out-Host -InputObject $siteGroup
            foreach($user in $siteGroup.Users)
            { 
                Write-Host -ForegroundColor Yellow "{"$user.Name"} " -NoNewline
                $siteGroup.RemoveUser($user)
            }
            $web.Update()
            Write-Host -ForegroundColor Green "hecho"
        }
    }

    Write-Host -ForegroundColor Cyan "agregando el usuario o grupo '"$row.User"' al grupo '"$row.SPSGroup"' " -NoNewline
    $siteGroup = $web.SiteGroups[$row.SPSGroup]

    #Asegurar que el usuario/grupo de AD está dentro del grupo de SPS
    $spuser = $web.EnsureUser($row.User);
    $siteGroup.AddUser($spuser);

    #AddUser(loginName, email, name, notes)
    #$web.SiteGroups[$_.SPSGroup].AddUser($_.ADGroup, "", "", "");
    Write-Host -ForegroundColor Green "hecho"
}


Write-Host -ForegroundColor Green "finalizado";