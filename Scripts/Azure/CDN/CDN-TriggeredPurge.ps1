


#Obtiene los CDN URL Path de aquellos Blob que se modificaron luego de cierta fecha en un Container de Storage Account
function Get-ContainerModifiedBlobs($StorageAccount_Context,$StorageAccount_Container_Name,$Date_Treshold_Hours,$Debug=$False){
    #Obtiene fecha limite, desde la cual considerar otras fechas "superiores". El calculo es con la fecha de hoy, restando X cantidad de horas
    $Trigger_Date=(Get-Date).AddHours(-$Date_Treshold_Hours)

    if ($Debug){Write-Warning "Trabajando sobre container '$StorageAccount_Container_Name' y fechas posteriores a '$Trigger_Date'."}

    #Lista el contenido Blob del container (simil a LS o DIR) y lo guarda en una variable.
    $Blob_Content=Get-AzStorageBlob -Context $StorageAccount_Context -Container $StorageAccount_Container_Name

    #Conteo de archivos en el contenedor
    $Blob_File_Count=$Blob_Content.count
    #Arma una lista vacia para archivos modificados
    $CDN_Content_URLPaths=@()


    #Iteracion por cada objeto de la lista, comparando fecha de modificacion con fecha limite
    foreach ($BlobFile in $Blob_Content){
        #Guarda datos del objeto, como el nombre del archivo y la fecha de modificacion
        $BlobFile_Name=$BlobFile.Name
        $BlobFile_ModifiedDate=$BlobFile.LastModified.DateTime #La fecha es un objeto nesteado en otro, por lo que se suscribe dos veces
        
        #Verifica si la fecha de modificacion es posterior a la fecha limite
        if ($BlobFile_ModifiedDate -gt $Trigger_Date){
            #Compone el path URL
            $CDN_Content_URLPath="/$StorageAccount_Container_Name/$BlobFile_Name"
            #Agrega el path a la lista
            $CDN_Content_URLPaths+=$CDN_Content_URLPath

            #CASO DEBUG: Escribe por consola los datos del archivo encontrado
            if ($Debug){Write-Warning "Se encontraron cambios posteriores a $Trigger_Date >> Archivo '$BlobFile_Name' ($CDN_Content_URLPath) modificado con fecha '$BlobFile_ModifiedDate'."}
        }
    }

    #Si no se encontraron archivos, devuelve boolean Falso
    if ($CDN_Content_URLPaths.count -eq 0){$CDN_Content_URLPaths=$False;if ($Debug){Write-Warning "No se encontraron cambios sobre container '$StorageAccount_Container_Name'."}}

    Return $CDN_Content_URLPaths #Retorno
}

function Get-StorageAccountModifiedBlobs($StorageAccount_Context,$StorageAccount_Container_Name,$Date_Treshold_Hours,$Debug=$False){
    #Obtiene fecha limite, desde la cual considerar otras fechas "superiores". El calculo es con la fecha de hoy, restando X cantidad de horas
    $Trigger_Date=(Get-Date).AddHours(-$Date_Treshold_Hours)

    #Arma una lista vacia para archivos modificados
    $CDN_Content_URLPaths=@()

    #Identifica el modo: Un container particular o todos  
    if ($StorageAccount_Container_Name -in ("",$null,$false,"/","*")){#Modo 1: Wildcard, todos los containers (iteraciones ciclicas)
        if ($Debug){Write-Warning "Trabajando en modo Wildcard (sobre todos los Containers) y exceoptuando los que empiezan con $."}
            #Obtiene containers dentro del Storage Account
            $Containers=(Get-AzStorageContainer -Context $StorageAccount_Context).name 
            #Conteo de contenedores
            $Containers_Count=$Containers.count        
            #Iteracion por cada objeto de la lista, ejecutando funcion para validar si hay cambios y obteniendo pahts de archivos donde haya
            foreach ($Container in $Containers){
                #Filtra los contenedores Web nativos, ya que el caracter "$" genera problemas en la peticion API.
                if (-not($Container.StartsWith("$"))){
                    $CDN_Content_URLPaths_ThisContainer=Get-ContainerModifiedBlobs -StorageAccount_Context $StorageAccount_Context -StorageAccount_Container_Name $Container -Date_Treshold_Hours $Date_Treshold_Hours -Debug $Debug
                    #Verifica si realmente hubo cambios
                    if (-not($CDN_Content_URLPaths_ThisContainer -eq $False)){
                        #Concatena las listas de Paths
                        $CDN_Content_URLPaths+=$CDN_Content_URLPaths_ThisContainer
                    } 
                }
            }
    }Else{ #Modo 2: Single, un unico container
        #Ejecuta funcion para validar si hay cambios y obtiene pahts de archivos donde haya
        $CDN_Content_URLPaths=Get-ContainerModifiedBlobs -StorageAccount_Context $StorageAccount_Context -StorageAccount_Container_Name $StorageAccount_Container_Name -Date_Treshold_Hours $Date_Treshold_Hours -Debug $Debug
    }

    #Si no se encontraron archivos, devuelve boolean Falso
    if ($CDN_Content_URLPaths.count -eq 0){$CDN_Content_URLPaths=$False}

    Return $CDN_Content_URLPaths #Retorno
}

function Send-Automacc_Email($Body,$Subject){
    #Obtiene credencial de mail que debe existir en los recursos del AUTOMACC
    $Credential=Get-AutomationPSCredential -Name 'EOL_EMAIL_SENDER'

    #Parametros de mensaje
    $To=Get-AutomationVariable -Name SMTP_To_Address
    $From=Get-AutomationVariable -Name SMTP_Send_Address

    #Salida de parametros
    Write-Warning "Ejecutando comando:"
    Write-Warning "Send-MailMessage -From $From -to $To -Body $Body -Subject $Subject -SmtpServer outlook.office365.com -Credential $Credential -UseSsl"

    #Envia mail de prueba
    Send-MailMessage -From $From -to $To -Body $Body -Subject $Subject -SmtpServer outlook.office365.com -Credential $Credential -UseSsl
}

function Main ($StorageAccount,$CDNProfile){
    $Success=$false

    #Conexion via System Managed Identity contra Azure PAA
    Disable-AzContextAutosave -Scope Process #Deshabilita herencia de contexto
    $AzureContext = (Connect-AzAccount -Identity).context #Conecta y guarda el contexto
    $AzureContext = Set-AzContext -SubscriptionName $StorageAccount["Subscription"] -DefaultProfile $AzureContext #Selecciona el contexto

    #Obtiene llave SAS para conectarse a Storage Account
    #$StorageAccount_AccessKey=((Get-AzStorageAccountKey -ResourceGroupName $StorageAccount["ResourceGroup"] -AccountName $StorageAccount["Name"])[0]).Value

    #Arma un objeto de contexto de conexion al Storage Account, proveyendo nombre de SA y credenciales de acceso
    $StorageAccount_Context=New-AzStorageContext -StorageAccountName $StorageAccount["Name"] #-StorageAccountKey $StorageAccount_AccessKey

    #Ejecuta funcion que busca cambios en el/los containers (sobre sus archivos blob) y compone una lista de URL Paths de los mismos
    $CDN_Content_URLPaths=Get-StorageAccountModifiedBlobs -StorageAccount_Context $StorageAccount_Context -StorageAccount_Container_Name $StorageAccount["Container"] -Date_Treshold_Hours $Date_Treshold_Hours -Debug $Debug

    #Purga el contenido CDN
    if (-not($CDN_Content_URLPaths -eq $False)){ #Si se encontraron archivos con cambios
        if ($Debug){Write-Warning "Trabajando sobre perfil CDN '$CDN_Name' y endpoint '$CDN_EndpointName'."}
        $CDN_Content_URLPaths_Count=$CDN_Content_URLPaths.count
        Write-Warning "Purgando $CDN_Content_URLPaths_Count archivos sobre perfil CDN '$CDN_Name'..."
        $Error_Count_Lastest=$Error.count
        #Funcion de modulo AZ que purga todos los miembros de una coleccion o lista enviada como parametro, sobre el CDN indicado 
        Unpublish-AzCdnEndpointContent -ResourceGroupName $CDNProfile["ResourceGroup"] -ProfileName $CDNProfile["Name"] -EndpointName $CDNProfile["EndpointName"] -PurgeContent $CDN_Content_URLPaths
        if ($Debug){
            $CDNProfile_Name=$CDNProfile["Name"]
            $CDNProfile_RG=$CDNProfile["ResourceGroup"]
            $CDNProfile_EP=$CDNProfile["EndpointName"]
            $CDN_Content_URLPaths_CSV=""
            foreach ($i in $CDN_Content_URLPaths){$CDN_Content_URLPaths_CSV+=",$i"}
            Write-Warning "Unpublish-AzCdnEndpointContent -ResourceGroupName $CDNProfile_RG -ProfileName $CDNProfile_Name -EndpointName $CDNProfile_EP -PurgeContent $CDN_Content_URLPaths_CSV."
        }
        if ($Error.count -gt $Error_Count_Lastest){
            Write-Error "Se encontraron errores al purgar contenido de perfil CDN '$CDN_Name'."
            Send-Automacc_Email -Subject "Errores al purgar cache de CDN de forma automatica" -Body "Se encontro un error al purgar el cache de CDN de forma automatica; esta tarea corre sobre un Automation Account.`nEsta falla no es critica, pero puede implicar que los cambios aplicados en el Storage Account asociado demoren hasta 48hs en visualizarse desde el CDN y afectar el ritmo del negocio. `n`nPuede obtener mas detalles al respecto en el articulo https://lamercantil.atlassian.net/wiki/spaces/TI/pages/1879834632/Purga+autom+tica+de+cach."
        }else{
            Write-Warning "Purga exitosa sobre perfil CDN '$CDN_Name'."
            $Success=$True
        }
    }else{ #Si no se encontraron cambios
        Write-Warning "No se encontraron cambios sobre perfil CDN '$CDN_Name'; omitiendo purga de archivos."
        $Success=$True
    }

    Return $Success
}

#####Variables globales####
###########################
#Cantidad de horas hacia atras a mirar para identificar cambios
$Date_Treshold_Hours=Get-AutomationVariable -Name "CDN-TriggeredPurge_Date_Treshold_Hours"
#Activa modo de debug que tiene salidas verbose
$Debug=Get-AutomationVariable -Name "CDN-TriggeredPurge_Debug"
#Parametros de Storage Account
$StorageAccount_Name=Get-AutomationVariable -Name "StorageAccount_Name"
$StorageAccount_ResourceGroup=Get-AutomationVariable -Name "StorageAccount_ResourceGroup"
$StorageAccount_Subscription=Get-AutomationVariable -Name "StorageAccount_Subscription"
#Nombre de Container sobre el cual operar. Si no se asigna valor -o se usan *,/,$null- se realiza la operacion sobre todos los containers
$StorageAccount_Container_Name=Get-AutomationVariable -Name "StorageAccount_Container_Name"
#Objeto Hashtable que acumula toda la informacion del SA
$StorageAccount_InformationHashtable=@{"Name"=$StorageAccount_Name;"ResourceGroup"=$StorageAccount_ResourceGroup;"Subscription"=$StorageAccount_Subscription;"Container"=$StorageAccount_Container_Name}
#Parametros de perfil CDN
$CDN_Name=Get-AutomationVariable -Name "CDN_Name"
$CDN_ResourceGroup=Get-AutomationVariable -Name "CDN_ResourceGroup"
$CDN_Subscription=Get-AutomationVariable -Name "CDN_Subscription"
$CDN_EndpointName=Get-AutomationVariable -Name "CDN_EndpointName"
#Objeto Hashtable que acumula toda la informacion del CDN
$CDN_InformationHashtable=@{"Name"=$CDN_Name;"ResourceGroup"=$CDN_ResourceGroup;"Subscription"=$CDN_Subscription;"EndpointName"=$CDN_EndpointName}
###########################
###########################

####Inicio script####
#####################
Main -StorageAccount $StorageAccount_InformationHashtable -CDNProfile $CDN_InformationHashtable
#####################
#####################

