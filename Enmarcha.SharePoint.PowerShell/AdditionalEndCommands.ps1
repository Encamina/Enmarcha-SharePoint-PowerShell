Param
(
    [Parameter(Mandatory=$true)]
    [string]$UrlWebApplication
)
Process
{
    Write-Host -ForegroundColor Yellow "Ejecutando comandos adicionales"

    $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }     
    
	# Agregar aquí comandos adicionales que se quiere que se ejecuten justo al final de cada despliegue
}