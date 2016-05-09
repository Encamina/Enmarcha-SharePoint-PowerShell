Param
(
    [Parameter(Mandatory=$true)]
    [string]$WFPath,

    [Parameter(Mandatory=$true)]
    [string]$UrlWebApplication,

    [Parameter(Mandatory=$true)]
    [string]$ListName,

    [Parameter(Mandatory=$true)]
    [string]$WFName,

    [switch]$Force
)
Process
{
	#Nintex Web Service URL
	$WebSrvUrl= $UrlWebApplication + "/_vti_bin/nintexworkflow/workflow.asmx"
 
	$proxy=New-WebServiceProxy -Uri $WebSrvUrl -UseDefaultCredential
	$proxy.URL=$WebSrvUrl
 
	#Get the Workflow from file
	$NWFcontent = get-content $WFPath

	if ($NWFcontent -ne $null)
	{
		[void]$proxy.PublishFromNWFXml($NWFcontent, $ListName, $WFName, $true)
		write-host "Flujo de trabajo "$WFName" publicado en "$ListName
	}
}