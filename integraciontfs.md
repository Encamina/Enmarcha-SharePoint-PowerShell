# Integrar Enmarcha SharePoint PowerShell con el sistema de integración continua en Team Foundation 2015/ VSTO con las Build vNext#

### Resumen ###
Este ejemplo como se pude integrar nuestros desarrollos en SharePoint en un ciclo de integración Continua.

### Funciona con ###
-  SharePoint 2013 on-premises

### Prerequisitos ###
Visual Studio 2013 o superior 


### Version history ###
Version  | Fecha | Comentarios
---------| -----| --------
1.0  | Mayo 09 2016 | Initial release

### Disclaimer ###
**THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.**

----------
## Prerequisitos ##
Para el correcto funcionamiento el agente de compilación y la máquina donde va a estar el servidor de integración debe de tener habilitado la ejecución de PowerShell Remoto. En caso contrario revisar este [artículo] (https://blogs.msdn.microsoft.com/sharepointdev/2011/11/17/deploying-wsps-as-part-of-an-automated-build-chris-obrien/)

## ESCENARIO ##
Dado la carpeta [Proyecto] (https://github.com/Encamina/Enmarcha-SharePoint-PowerShell/tree/master/Enmarcha.SharePoint.PowerShell/Proyecto/) que se encuentra en la solución inicial. Vamos a realizar un proceso de integración de la solución dentro un ciclo de integración continua. 

El primer paso es que tenemos una función llamada [CreateSite](https://github.com/Encamina/Enmarcha-SharePoint-PowerShell/blob/master/Enmarcha.SharePoint.PowerShell/CreateSite.ps1)
esta función tiene los siguientes parametros:
-urlWebApplication --> Url de nuestra colección de Sitio.
-ownerAlias Usuario --> Administrador de dicha colección de sitios
-PathConfiguration --> Ubicación de donde estan los ficheros de ejecución
-PathWsp --> Ubicación donde estan los ficheros .WSP de la solución 
-Force --> Este parametro elimina la colección del sitio en el supuesto de que exista
-ConfigurationRelative --> Indica si recorre todas las carpetas a nivel raiz o no. Este parametro es debido a que en nuestro caso al seguir una métodologia Agile y separar cada entregable por Sprint, es posible que se necesite restaurar nuestro desarrollo en algún punto de la aplicación o bien realizar una instalación de todos los sprints de la aplicación.

Este script tambien lo ejecuta cada miembro del equipo en su maquina local para integrarse el resto de desarrollos con ellos.
Un ejemplo seria 
```PowerShell
. ./CreateSite.ps1 -UrlWebApplication https://contoso.com -OwnerAlias contoso\adriandiaz -PathWsp $dropLocation -PathConfiguration "$print1" -Force -ConfigurationRelative
```
### TFS /VST Online  ###

1.- En la parte del Proyecto disponemos de una opción Build 

![alt text](https://github.com/Encamina/Enmarcha-SharePoint-PowerShell/blob/master/content/images/Build.PNG "Build")

2.- Añadimos una nueva definición de la Build.

3.- Sobre esta definición seleccionamos la opción de ejecutar un PowerShell de forma remota. 

![alt text](https://github.com/Encamina/Enmarcha-SharePoint-PowerShell/blob/master/content/images/PowerShellRemoto.PNG "Build")

4.- Indicaremos la maquina en las que se va a ejecutar 

![alt text](https://github.com/Encamina/Enmarcha-SharePoint-PowerShell/blob/master/content/images/RunPowerShell.PNG "Build")

5.- Seleccionamos el Script que se va a ejecutar(hay que indicar el Path UNC) 

![alt text](https://github.com/Encamina/Enmarcha-SharePoint-PowerShell/blob/master/content/images/RunDeployment.PNG "Build")


