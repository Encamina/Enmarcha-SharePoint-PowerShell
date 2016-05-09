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
    Write-Host -ForegroundColor Yellow "Creando elemento de lista '$Path' para la lista '$List.Title'"


    $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

    $currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Import-Module "$currentPath\EnmarchaFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

    [xml]$item = Get-Content $Path

    $listItem = $List.Items.Add()
    if ($item.Item.ContentType -ne $null)
    {
        $listItem["ContentTypeId"] = (Get-SPContentTypeByName -Web $Web -LCID $item.Item.ContentType.LCID -Name $item.Item.ContentType.Name).Id
    }

    Write-Host -ForegroundColor Green "Añadiendo campos..." -NoNewline
    $item.Item.Fields.Field | % {
        Write-Host "{" $_.Name"} " -NoNewline
        Set-ListItemFieldValue -ListItem $listItem -FieldName $_.Name -Item $_ -UpdateListItem:$false
    }    

	if ($List.EnableModeration)
	{
	    Write-Host -ForegroundColor Green "Aprobación del elemento..." -NoNewline
		$listItem.ModerationInformation.Status = [Microsoft.SharePoint.SPModerationStatusType]::Approved
		$listItem.ModerationInformation.Comment = ""	 
	}

    $listItem.Update()
}