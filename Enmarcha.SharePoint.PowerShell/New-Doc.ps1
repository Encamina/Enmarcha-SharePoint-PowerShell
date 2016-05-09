Param
(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [Microsoft.SharePoint.SPWeb]$Web,

    [Parameter(Mandatory=$true)]
    [Microsoft.SharePoint.SPList]$List
)
Process
{
    $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

    $currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Import-Module "$currentPath\EnmarchaFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

    [xml]$manifest = Get-Content "$Path\manifest.xml"

    $folder = $List.RootFolder

    $localFile = Get-ChildItem -Path $Path | ? { $_.Name -ne "manifest.xml" } | Select-Object -First 1
    $stream = $localFile.OpenRead()
    $newFile = $folder.Files.Add($folder.Url + "/" + $localFile.Name, $stream, $true, "", $false)    
	$stream.Close()

    $listItem = $newFile.Item
    
    if ($listItem -ne $null)
    {
        $listItem["ContentTypeId"] = (Get-SPContentTypeByName -Web $Web -LCID $manifest.Document.ContentType.LCID -Name $manifest.Document.ContentType.Name).Id
    
        $manifest.Document.Fields.Field | % {
            Write-Host "{" $_.Name"} " -NoNewline
            Set-ListItemFieldValue -ListItem $listItem -FieldName $_.Name -Item $_ -UpdateListItem:$false
        }
        $listItem.Update()
    }
	
	Write-Host "Hecho"
}