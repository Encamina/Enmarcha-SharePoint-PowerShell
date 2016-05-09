function Package-SP
{
    param
    (
        [parameter(Mandatory=$false)]            
        [ValidateNotNullOrEmpty()]             
        [String] $Configuration = "Debug",  
             
        [parameter(Mandatory=$false)]
        [String] $ProjectFile,

        [parameter(Mandatory=$false)]
        [String] $ProjectWsp
    )
    process
    {
        $MsBuild = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\msbuild.exe"
        $Configuration = "Debug"
        $deployFolder = "C:\WSP\"
        $BuildLog = "c:\deploy\log.txt"

        $BuildArgs = @{            
            FilePath = $MsBuild            
            ArgumentList = "`"$ProjectFile`"", "/t:rebuild", "/t:package", ("/p:Configuration=" + $Configuration), "/p:VisualStudioVersion=12.0"            
            RedirectStandardOutput = $BuildLog            
            Wait = $true                      
        }

        Write-Host "Empaquetando proyecto"
        Start-Process @BuildArgs
 
        Write-Host "Copiando los paquetes WSP a la carpeta destino"
        Copy-Item -Confirm:$false -Path "$ProjectWsp" -Destination "$deployFolder"
        Write-Host " - hecho."
    }
}

$projectRoot = "C:\TFS\Main"

$ProjectList=IMPORT-CSV "C:\TFS\Main\Enmarcha.SharePoint.PowerShell\Package\projects.csv"

foreach ($line in $ProjectList) {
    write-host " Proyecto $($line.project) WSP $($line.wsp)"
    $projectFile = $projectRoot + $line.project
    $projectWsp = $projectRoot + $line.wsp

    Package-SP -ProjectFile $projectFile -ProjectWsp $projectWsp
}
