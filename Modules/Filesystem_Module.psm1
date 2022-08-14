<#
Modulo que brinda funciones de operaciones con el Filesystem local u otros remotos.
#>


#Funcion que monta una ruta remota como un disco PSDrive local, con una credencial de otro usuario.
function New-RemotePSDrive($PSDrive_Letter,$Path,$Credential,$MountWithIP=$False){
    $Success=$False
    $Existing_PSDrive_Letter=$null
    $Existing_PSDrive_Path=$null
    $PSDrive=$null

    #Obtiene los PSDrives existentes
    $PSDrives=Get-PSDrive
    #Recorre los PSDrives
    foreach ($PSDrive in $PSDrives){
        #Si existe uno que coincide en ruta
        if ($PSDrive.root -eq $Path){
            #Guarda la letra y sale del ciclo
            $Existing_PSDrive_Letter=$PSDrive.Name
            $Existing_PSDrive_Path=$PSDrive.root
            Break
        }
    }

    #Verifica si el disco ya existe
    $PSDriveLetterTaken=-not($null -eq $Existing_PSDrive_Letter)
    $PSDrivePathMatchesExisting=$Existing_PSDrive_Path -eq $Path
    $PSDriveAlreadyExists=$PSDriveLetterTaken -and $PSDrivePathMatchesExisting

    #Si el disco no existe
    if (-not($PSDriveAlreadyExists)){
        #Si la letra esta tomada, la libera primero
        if ($PSDriveLetterTaken){Remove-RemotePSDrive $PSDrive_Letter}

        #Arma la ruta, pero con la IP en vez del hostname.Esto evita problemas con mapeos que el operador pueda tener sobre el servidor de destino (duplicados).
        if($MountWithIP){
            $Hostname=($Path.replace("\\","") -split "\\")[0] #Extra el hostname de la ruta. Ojo, la segunda "\" es un caracter de escape.imp
            if (-not ($Hostname.StartsWith("1"))){ #Verifica que no sea una IP
                $IPAddress= (Resolve-DnsName $Hostname -ErrorAction SilentlyContinue -InformationAction SilentlyContinue).ipaddress #Obtiene la IP resuelta.
                #Si se detectan mas de una IP, toma la primera.
                if ($IPAddress -is [Array]){
                    $IPAddress=$IPAddress[0]
                }
                $Path=$Path.Replace($Hostname,$IPAddress) #Reemplaza el hostname con la IP
            }    
        }

        #Monta el disco
        try{
            $PSDrive=New-PSDrive -Name $PSDrive_Letter -PSProvider FileSystem -Root $Path -Scope Global -Credential $Credential -InformationAction SilentlyContinue -ErrorAction SilentlyContinue | out-null
        }catch{
            $PSDrive=$False
        }

        #Valida exito al crear el disco
        if ($PSDrive){
            $Success=$true
        }else{
            #Si es el primer intento -o sea con hostname- se auto-invoca e intenta con IP.
            if (-not($MountWithIP)){
                Write-Host "Error al mapear Remote PSDrive <$PSDrive_Letter> con ruta <$Path>, intentando con IP."
                #Recursivo, pero corta en un ciclo.
                $Success=New-RemotePSDrive -PSDrive_Letter $PSDrive_Letter -Path $Path -Credential $Credential -MountWithIP $True
            }else{
                Write-Host "Error al mapear Remote PSDrive <$PSDrive_Letter> con ruta <$Path>."
                $Success=$False
            }
        }
    }else{ #Si el disco existe
        $Success=$True
    }

    Return $Success
}

#Funcion que elimina un montaje de PSDrive con ruta remota.
function Remove-RemotePSDrive($PSDrive_Letter,$WaitTime=15,$Step=1,$Commspec=$False){
    $DriveNotRemoved=$true

    #Acciona dependiendo de la configuracion Commspec: Powershell o CMD
    if (-not($Commspec)){
        #Intenta quitar el PSDrive
        Remove-PSDrive -LiteralName $PSDrive_Letter -PSProvider FileSystem -Force -ErrorAction SilentlyContinue -InformationAction SilentlyContinue | out-null
    }else{
        #Ejecuta borrado de unidad via CMD con comando Net Use
        $Command_Line="/Q /c net use "+$PSDrive_Letter+": /delete /y"
        Start-Process -FilePath cmd.exe -ArgumentList $Command_Line -NoNewWindow -ErrorAction SilentlyContinue -Wait | Out-Null
    }

    $TimeElapsed=0
    #Espera a que el disco no exista o se agote el tiempo.
    While ($DriveNotRemoved -and ($TimeElapsed -lt $WaitTime)){
        #Verifica si el disco existe
        $DriveNotRemoved=(Get-PSDrive -Name $PSDrive_Letter -ErrorAction SilentlyContinue)
        #Si no existe, espera un el paso y aumenta el contador
        if ($DriveNotRemoved){
            Start-Sleep $Step | Out-Null
            $TimeElapsed+=$Step
        }
    }

    #Chequea exito
    if ($DriveNotRemoved){
        Write-Host "Error al quitar Remote PSDrive <$PSDrive_Letter>."
    }
    #Retorna el opuesto booleano de DiscoNoRemovido, o sea DiscoRemovido
    Return (-not($DriveNotRemoved))
}


#Extra el nombre de la ultima carpeta de una ruta
function Get-FolderNameFromPath($Path){
    $Folder_Name=$null
    #Arma un vector o array dividiendo por caracter "\"
    $Path_Array=$Path -split "\\"

    #Verifica si realmente es una ruta valida, con subcarpetas
    $PathHasMultipleFolders=$Path_Array.count -gt 1
    if ($PathHasMultipleFolders){
        #El nombre de la carpeta esta en el ultimo elemento del array, que numera de 0 a n-1
        $Folder_Name=$Path_Array[$Path_Array.count - 1]
    }
    #Devuelve la carpeta o $null si no es valida.
    Return $Folder_Name
}

#Copia una carpeta completa a otra carpeta de destino.
function Copy-FolderContent ($Origin_Path, $Destination_Path){
    $Success=$null

    #Verifica que existen las carpetas
    $OriginIsValid=Test-Path $Origin_Path
    $DestinationIsValid=Test-Path $Destination_Path

    #Verifica si el origen es valido
    if ($OriginIsValid){
        #Verifica si el destino es valido
        if ($DestinationIsValid){
            Copy-Item -Force -Recurse -Path $Origin_Path -Destination $Destination_Path
            $Success=$?
        }else{
            #Extrae el nombre de la carpeta de la ruta
            $Folder_Name=Get-FolderNameFromPath $Destination_Path
            #Si se logro extraer el nombre
            if ($Folder_Name){
                #Quita el nombre de la carpeta de la urta
                $Destination_Path_WithoutFolder=$Destination_Path.replace("\$Folder_Name","")
                #Crea la carpeta
                New-Item -Name $Folder_Name -Path $Destination_Path_WithoutFolder -ItemType Directory | Out-Null
                #Verifica creacion
                if ($?){
                    #Copia el contenido y pasa el resultado de la operacion a la booleana success.
                    Copy-Item -Force -Recurse -Path $Origin_Path -Destination $Destination_Path | Out-Null
                    $Success=$?
                }else{
                    $Success=$false
                    Write-Error "No fue posible crear la carpeta $Folder_Name."
                }           
            }else{
                $Success=$false
                Write-Error "El destino $Destination_Path no es valido."
            }
        }
    }else{
        $Success=$false
        Write-Error "El origen $Origin_Path no es valido."
    }

    Return $Success
}
