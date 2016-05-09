# ENMARCHA SharePoint PowerShell - Open Source

ENMARCHA SharePoint PowerShell se compone de una carpeta donde se define qué características tendrá el sitio desplegado, y de un conjunto de scripts que lo implementarán.

## Scripts de despliegue
El conjunto de scripts que aportan la funcionalidad necesaria para realizar el despliegue son los siguientes:
-	ActivateRatings.ps1. Funcionalidad para activar y configurar las valoraciones de elementos
-	AdditionalEndCommands.ps1. Script donde se encontrarán acciones que se deberán ejecutar al final de todo el despliegue
-	ContentTypeFunctions.psm1. Funcionalidad para crear, modificar, eliminar y configurar tipos de contenido
-	ContentTypeXmlFunctions.psm1. Script que lee los ficheros XML que definen tipos de contenido y llama a las funciones que se requieran del script anterior
-	CreateSite.ps1. Script principal que llama a las funciones del resto de scripts para crear y configurar el entorno
-	Deploy-Solution.ps1. Funcionalidad para desplegar paquetes WSP en el entorno SharePoint
-	Deploy-UserSolution.ps1. Funcionalidad para desplegar paquetes Sandbox a la galería de soluciones de una colección de sitios
-	EnmarchaFunctions.psm1. Conjunto de funcionalidades Core sobre el que se basan el resto de scripts
-	GroupFunctions.psm1. Funcionalidad para crear y configurar grupos de SharePoint
-	Lookups.ps1. Funcionalidad para crear y configurar columnas de Lookup
-	New-AssetsLib.ps1.  Funcionalidad para crear y configurar bibliotecas de activos
-	New-Doc.ps1. Funcionalidad para agregar documentos a una biblioteca
-	New-DocLib.ps1. Funcionalidad para crear y configurar bibliotecas de documentos
-	New-DocLibPaginas.ps1. Funcionalidad para configurar bibliotecas de páginas
-	New-ImgLib.ps1. Funcionalidad para crear y configurar bibliotecas de imágenes
-	New-List.ps1. Funcionalidad para crear y configurar listas personalizadas
-	New-ListItem.ps1. Funcionalidad para crear y configurar elementos dentro de listas
-	New-Navigation.ps1. Funcionalidad para crear y configurar la navegación de la colección de sitios
-	New-Page.ps1. Funcionalidad para crear y configurar páginas
-	New-Site.ps1. Funcionalidad para crear y configurar una colección de sitios
-	New-Web.ps1. Funcionalidad para crear y configurar un sitio
-	ProvisioningSiteColumns.ps1. Funcionalidad para crear y configurar columnas de sitio
-	SearchFunctions.psm1. Scripts para configurar la funcionalidad de búsqueda
-	SecurityFunctions.psm1. Scripts para configurar la seguridad de los sitios
-	SecurityXmlFunctions.psm1. Scripts para leer los XML de configuración de la seguridad y llamar a las funciones del script anterior
-	TaxonomyCustomProperties.ps1. Funcionalidad para crear y configurar propiedades personalizadas en la taxonomía
-	TaxonomyFunctions.psm1. Funcionalidad para crear y configurar la taxonomía

##Definición del sitio
La definición y configuración de la colección de sitios que se va a desplegar, y su entorno, se especifica en la carpeta Project de la siguiente manera:
-	Carpeta(s) DOCLIB-[nombrecarpeta]. Las carpetas con esta nomenclatura definen la creación y configuración de una biblioteca de documentos. La configuración de la biblioteca se encuentra en un fichero manifest.xml que se encuentra en su interior, donde se puede especificar el nombre, URL, tipos de contenido que utiliza, versionado, etc.
Adicionalmente se puede agregar documentos durante el despliegue si se crean sub carpetas con la nomenclatura DOC-[nombrefichero], y se incluye en su contenido el fichero que se deplegará y otro fichero manifest.xml donde poder configurar el título del fichero, tipo de contenido que utiliza, etc.
-	Carpeta(s) LIST-[nombrelista]. Las carpetas con esta nomenclatura definen la creación y configuración de una lista personalizada. La configuración de la lista se encuentra en un fichero manifest.xml que se encuentra en su interior, donde se puede especificar el nombre, URL, tipos de contenido que utiliza, versionado, etc.
Adicionalmente se puede agregar elementos de lista durante el despliegue si se crean sub carpetas con la nomenclatura ITEM-[nombreelemento], y se incluye en su contenido un fichero manifest.xml donde poder configurar el título del elemento, tipo de contenido que utiliza, valores para el resto de columnas, etc.
-	Carpeta Lookup. Contiene un fichero CSV donde poder especificar la configuración de los campos Lookup que se van a crear
-	Carpeta Search. Contiene un fichero CSV donde poder especificar la configuración de las propiedades administradas que se van a crear
-	Carpeta Taxonomy. Contiene fichero(s) CSV donde poder especificar la configuración de los conjuntos de términos que se van a crear. Se agregará un fichero CSV por conjunto de términos. Cada fichero, además de especificar la configuración del propio conjunto de términos, también podrá agregar términos
-	Carpeta Templates. Contiene una subcarpeta Site donde poder agregar plantillas de sitio en formato WSP que el script desplegará en la colección de sitios
-	Carpeta UsersAndGroups. Contiene tres scripts con funcionalidad relacionada con la creación, actualización, eliminación y configuración de grupos de SharePoint y usuarios. También contiene los siguientes tres ficheros CSV:
*	Groups.csv. Define los grupos de SharePoint que se van a crear junto con sus permisos
*	UserProperties.csv. Permite definir propiedades que se crearán en los perfiles de los usuarios
*	Users.csv. Permite agregar usuarios a grupos de sharePoint
-	Carpeta(s) WEB-[nombresubsitio]. Las carpetas con esta nomenclatura definen la creación y configuración de sub-sitios. La configuración del sitio se encuentra en un fichero manifest.xml que se encuentra en su interior, donde se puede especificar el nombre, URL, plantilla que utiliza, permisos, idioma, qué características de sitio se activarán, etc.
Estas carpetas pueden contener a su vez más carpetas de tipo DOCLIB-, LIST- y WEB- para crear listas, bibliotecas y sub-sitios en el sitio recién creado
-	Fichero ContentTypes-Columns.xml. Fichero XML que permite la creación, actualización y borrado de columnas de sitio. Para cada columna se podrá configurar su nombre interno, nombre para mostrar, tipo, tamaño máximo, si es multivaluado, grupo al que pertenece, si es oculta, etc.
-	Fichero(s) ContentTypes-v01.00-[nombretipodecontenido].xml. Fichero XML que permite la creación, actualización y borrado de un tipo de contenido. Este tipo de contenido se le podrá configurar su ID, nombre interno, nombre para mostrar, tipo de contenido del que hereda, grupo al que pertenece, columnas de sitio que utiliza y si estas son requeridas (aunque en la definición esta columna no sea requerida), etc.
-	Fichero manifest.xml. Define la configuración del sitio raíz donde se podrá especificar su nombre y descripción, plantilla que utiliza, idioma, logo, configuración de auditoría y de búsquedas, qué características de colección de sitios, y de sitio, se activarán, etc.
