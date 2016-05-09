Param
(    
    [Parameter(Mandatory=$true)] 
	[string]$UrlWebApplication  = "",
	[Parameter(Mandatory=$true)] 
	[string]$PathConfiguration
)
Process
{
	$templatesPath = $PathConfiguration + "\Templates\Site\"

	If (Test-Path $templatesPath) {
		Get-ChildItem -Path "$templatesPath"  | Sort-Object -Property Name | % {
			Write-Host "Agregando la solución $templatesPath$_"
			$solutionName = $_.Name
			$solutionDeployed = Get-SPUserSolution -Site $UrlWebApplication | Where-Object { $_.Name -eq $solutionName }
    
			if ($solutionDeployed -ne $null)
			{
				Write-Host "La solución ya estaba instalada. Actualizando..."
				if ($solutionDeployed -ne $null -and $solutionDeployed.Status -eq "Activated")
				{
					Uninstall-SPUserSolution -Identity $solutionName -Site $UrlWebApplication -Confirm:$false
				}

				Remove-SPUserSolution -Identity $solutionName -Site $UrlWebApplication -Confirm:$false
				Add-SPUserSolution -LiteralPath $templatesPath$solutionName -Site $UrlWebApplication
			}
			else
			{
				Add-SPUserSolution -LiteralPath $templatesPath$solutionName -Site $UrlWebApplication
			}

			Install-SPUserSolution -Identity $solutionName -Site $UrlWebApplication
		}
	}
}