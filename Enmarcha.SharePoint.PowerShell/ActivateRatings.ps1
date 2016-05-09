Param
(
    
    [Parameter(Mandatory=$true)]
    [string]$UrlWeb = $(Read-Host -Prompt "Web Url")
)

Add-PSSnapin "Microsoft.SharePoint.PowerShell" -ErrorAction SilentlyContinue
 
$web=Get-SPWeb $UrlWeb;
$list=$web.Lists["Páginas"];
if($list -ne $null)
{
 Write-Host $list.Title " no es null";
 $assembly=[System.Reflection.Assembly]::Load("Microsoft.SharePoint.Portal, Version=15.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c")
 $reputationHelper =$assembly.GetType("Microsoft.SharePoint.Portal.ReputationHelper");
 
$bindings = @("EnableReputation", "NonPublic", "Static");
 [System.Reflection.BindingFlags]$flags = [System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::NonPublic;
 
 $methodInfo = $reputationHelper.GetMethod("EnableReputation", $flags);
 
#For enabling Ratings
 $values = @($list, "Ratings", $false);
 
#OR for enabling Likes
 #$values = @($list, "Likes", $false);
 
$methodInfo.Invoke($null, @($values));
 
 #For disable Rating or Likes
 <#$methodInfo = $reputationHelper.GetMethod("DisableReputation", $flags);
 $disableValues = @($list);
 $methodInfo.Invoke($null, @($disableValues));#>
}