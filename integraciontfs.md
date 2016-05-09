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

1.- Abrimos la solución Enmarcha.Samples.sln con Visual Studio 2013/ Visual Studio 2015

2.- Restauramos los paquetes Nuget de la Solución

3.- Abrimos el fichero Program.cs e introducimos la url de nuestro sitio de SharePoint que esta asignada en la constante urlSharePointOnpremise:
```C#
 const string urlSharePointOnpremise = "urlsiteSharePoint";
```
4.- Para crear la lista utilizaremos el método extensor [CreateList](https://github.com/Encamina/Enmarcha-SharePoint/blob/master/Enmarcha.SharePoint/Extensors/List.cs)
```C#
  var createList= web.CreateList(listName, "List of Employed of my Company", TypeList.GenericList, false,
                        typeof (Employed));
```
Esto crea una lista y le añade los campos, cada una de las propiedades que hay en la clase [Employed.cs](https://github.com/Encamina/Enmarcha-SharePoint/blob/master/Samples/Enmarcha.Samples.ManageData/Model/Employed.cs). 
Para saber que tipo de Columnas de SharePoint son necesarios a cada propiedad le asignamos unos Atributos donde se condigura estos valores:
```C#
 [Enmarcha(AddPrefeix = false, Create = false, Type = TypeField.Text)]
        public string ID { get; set; }
        [Enmarcha(AddPrefeix = false, Create = true, Type = TypeField.Text, DisplayName = "Fist Name")]
        public string Name { get; set; }
        [Enmarcha(AddPrefeix = false, Create = true, Type = TypeField.Text, DisplayName = "Last Name")]
        public string LastName { get; set; }
        [Enmarcha(AddPrefeix = false, Create = true, Type = TypeField.DateTime, DisplayName = "Date of Born")]
        public DateTime DateBorn { get; set; }
        [Enmarcha(AddPrefeix = false, Create = true, Type = TypeField.Choice, DisplayName = "Job",Choice= new []{"Developer","Designer"})]
        public string Job { get; set; }
        [Enmarcha(AddPrefeix = false, Create = true, Type = TypeField.Text, DisplayName = "Country")]
        public string Country { get; set; }
        [Enmarcha(AddPrefeix = false, Create = true, Type = TypeField.User, DisplayName = "Boss Primary")]
        public IList<UserSP> Boss { get; set; }
```
Los Atributos que se pueden añadir a cada propiedad estan dentro de la Clase [EnmarchaAttribute.cs]https://github.com/Encamina/Enmarcha-SharePoint/blob/master/Enmarcha.SharePoint/Attribute/EnmarchaAttribute.cs)
AddPrefeix-> Le añada un prefijo cuando crea el campo de forma que se evita que coincida con algun campo ya declarado
Create -> Indica si esta propiedad hay que crearla o no.
Type -> Tipo de SharePoint con el que representa esta propiedad

5.-A continuación, inicialicaremos la clase SharePointRepository, los parametros que son necesarios son:

. SPweb

. Log (Enmarcha por defecto trae un Log que graba en los [logs de SharePoint](https://github.com/Encamina/Enmarcha-SharePoint/blob/master/Enmarcha.SharePoint/Entities/Logs/LogManager.cs) pero se puede utilizar cualquier Log siemple que se implemente la interfaz [ILog](https://github.com/Encamina/Enmarcha-SharePoint/blob/master/Enmarcha.SharePoint.Abstract/Interfaces/Artefacts/ILog.cs)

```C#
var  logger = new LogManager().GetLogger(new System.Diagnostics.StackTrace().GetFrame(0)); ;
var repository= new SharePointRepository<Employed>(web,logger,listName,10);
```

6.- Ahora para insertar un elemento sobre la lista de SharePoint Employed, tendremos en primer lugar crear una elemento basado en la clase Employed y a continuación pasarle ese elemento al metodo "Insert" de nuestro repositorio de SharePoint. de 
```C#
  var employed = new Employed
                {
                    Country = "Spain",
                    DateBorn = new DateTime(1981, 5, 10),
                    Job = "Sofware Architect",
                    LastName = "Diaz Cervera",
                    Name = "Adrian"
                };
var  resultInsert= repository.Insert(employed);
```
7.- Para realizar una modificación sobre un elemento hay que pasarle los datos que se quierean modificar y el identificador del elemento que vamos actualizar
```C#
  var firstEmployed= new Employed { Job = "Sofware Architect Lead"};
  var updateOperation= repository.Save(Convert.ToInt32(resultInsert), firstEmployed);
```

8.- Eliminar un elemento
```C#
var resultBool = repository.Delete(resultInsert);
```

9.- Como hacer Hacer consultas sobre las listas, se pueden hacer de dos formas pasando la Caml Query de forma directa:
```C#
 var queryCaml = @"<Where>
                                      <Eq>
                                         <FieldRef Name='Name' />
                                         <Value Type='Text'>Adrian</Value>
                                      </Eq>
                                   </Where>";
 var queryCollection = repository.Query(queryCaml, 1);
```
o bien podemos utilizar un [generador de consultas](https://github.com/Encamina/Enmarcha-SharePoint/blob/master/Enmarcha.SharePoint/Entities/Data/Query.cs) que esta dentro de Enmarcha
```C#
var query = new Query().Where().Field("Name",string.Empty).Operator(TypeOperators.Eq).Value("Text","Adrian");
  queryCollection = repository.Query(query, 1);
```

