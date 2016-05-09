Param
(    
    [Parameter(Mandatory=$false)] [string]$UrlWebApplication = "",
    [Parameter(Mandatory=$true)] [string]$Path,
    [Parameter(Mandatory=$true)] [string]$SolutionName,
    [Switch] $AllWebApplications,
    [Switch] $GACDeployment,
    [Switch] $Force,
    [Parameter(Mandatory=$false)] [string]$UrlWebApplicationFeatures = "",
    [Parameter(Mandatory=$false)] [string]$Features = ""
)
Process
{
    $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

    Function Add-Solution()
    {
        Write-Host "Agregando la solución $SolutionName " -ForegroundColor Green -NoNewline
        Add-SPSolution $Path$SolutionName        
        
        Write-Host "Instalando la solución $SolutionName " -ForegroundColor Green -NoNewline
        if(($AllWebApplications.IsPresent) -and ($GACDeployment.IsPresent)) { Write-Host "AllWebApplications y GACDeployment - " -NoNewline; Install-SPSolution -Identity $SolutionName -AllWebApplications -GACDeployment -Force -Confirm:$false }
        if(($AllWebApplications.IsPresent) -and (!$GACDeployment.IsPresent)) { Write-Host "AllWebApplications - " -NoNewline; Install-SPSolution -Identity $SolutionName -AllWebApplications -Force -Confirm:$false }
        if((!$AllWebApplications.IsPresent) -and ($GACDeployment.IsPresent) -and ($UrlWebApplication -eq "")) { Write-Host "GACDeployment - " -NoNewline; Install-SPSolution -Identity $SolutionName -GACDeployment -Force -Confirm:$false }
        if((!$AllWebApplications.IsPresent) -and (!$GACDeployment.IsPresent)-and ($UrlWebApplication -eq "")) { Install-SPSolution -Identity $SolutionName -Force -Confirm:$false }
        if((!$AllWebApplications.IsPresent) -and ($GACDeployment.IsPresent) -and ($UrlWebApplication -ne "")) { Write-Host "GACDeployment y una WebApplication - " -NoNewline; Install-SPSolution -Identity $SolutionName -GACDeployment -WebApplication $UrlWebApplication -Force -Confirm:$false }
        if((!$AllWebApplications.IsPresent) -and (!$GACDeployment.IsPresent)-and ($UrlWebApplication -ne "")) { Write-Host "Una WebApplication - " -NoNewline;Install-SPSolution -Identity $SolutionName -WebApplication $UrlWebApplication -Force -Confirm:$false }
        WaitForDeploymentJob $SolutionName  		

        if(($Features -ne "") -and ($UrlWebApplicationFeatures -ne ""))
        {
            Write-Host "Característica encontrada $Features" -ForegroundColor Green
            $Features.Split(';') | ForEach-Object {
                $Feature = $_.ToString()
                Write-Host "Habilitando característica $Feature " -ForegroundColor Green -NoNewline
                Enable-SPFeature -Identity $Feature -Url $UrlWebApplicationFeatures/ -Force                
            }
        }
        else
        {
            Write-Host "(No hay características para habilitar)" -ForegroundColor Green
        }
    }


    Write-Host "Preparando para agregar la solución $SolutionName"
    if((Get-SPSolution | Where-Object { $_.Name -eq $SolutionName }) -ne $null)
    {
        Write-Host "La solución $SolutionName ya está desplegada" -ForegroundColor Green
        if($Force.IsPresent)
        {
            Write-Host "Eliminando la solución $SolutionName " -ForegroundColor Green -NoNewline
            Remove-SPSolution -Identity $SolutionName -Force -Confirm:$false
			WaitForDeploymentJob $SolutionName            
            Add-Solution
        }        
    }
    else
    {
        Add-Solution
    }

    return $true
}