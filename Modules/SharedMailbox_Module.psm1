<#
Modulo que brinda funciones de operaciones con Shared Mailboxes de Exchange.
Requiere que exista una sesion de Powershell contra Exchange importada.
#>


#Transfiere los permisos de un usuario sobre buzones compartidos a otro.
function Transfer-SharedMailboxPermissions($Source_Identity,$Identity,$Debug){
    $Success=$false

    #Verifica que la identidad no sea nula
    if (-not(($Identity -eq $null)-or($Source_Identity -eq $null))){
        #Obtiene los mailbox compartidos
        $SharedMailboxes=Get-Mailbox -RecipientTypeDetails SharedMailbox

        #Si obtuvo mailboxes
        if ($SharedMailboxes){

            #Identifica los permisos de buzon que tiene el usuario
            $MailboxPermissions= $SharedMailboxes | Get-MailboxPermission -User $Source_Identity
            #Boolean para guardar el estado de las asignaciones
            $MailboxPermissionsTransfered=$true
            #Si existen permisos
            if ($MailboxPermissions){
                #Recorre la lista de permisos
                foreach ($MailboxPermission in $MailboxPermissions){
                    #Agrega el permiso al usuario
                    Add-MailboxPermission -Identity ($MailboxPermission.identity) -AccessRights ($MailboxPermission.accessrights) -User $Identity -AutoMapping $true -Confirm:$false | Out-Null
                    #Verifica si hubo errores
                    if (-not($?)){
                        #Si hubo errores, corta el ciclo
                        $MailboxPermissionsTransfered=$false
                        Break
                    }
                }  
            }else{
                if ($Debug){Write-Host "No se encontraron permisos de buzon."}
            }

            #Identifica los permisos de envio que tiene el usuario
            $RecipientPermissions= $SharedMailboxes | Get-RecipientPermission -Trustee $Source_Identity
            #Boolean para guardar el estado de las asignaciones
            $RecipientPermissionsTransfered=$true
            #Si existen permisos
            if ($RecipientPermissions){
                #Recorre la lista de permisos
                foreach ($RecipientPermission in $RecipientPermissions){
                    #Agrega el permiso al usuario
                    Add-RecipientPermission -Identity ($RecipientPermission.identity) -AccessRights ($RecipientPermission.accessrights) -Trustee $Identity -Confirm:$false | Out-Null
                    #Verifica si hubo errores
                    if (-not($?)){
                        #Si hubo errores, corta el ciclo
                        $RecipientPermissionsTransfered=$false
                        Break
                    }
                }
            }else{
                if ($Debug){Write-Host "No se encontraron permisos de envio."}
            }

            #Verifica el exito de ambas operaciones
            if ($MailboxPermissionsTransfered -and $RecipientPermissionsTransfered){
                $Success=$true
                if ($Debug){Write-Host "Permisos de buzones y envio transferidos."}
            }else{
                $Success=$false
                if ($Debug){Write-Host "Ocurrieron errores al transferir permisos de buzones y envio."}
            }

        }else{
            if ($Debug){Write-Host "Error al obtener buzones de correo y sus permisos."}
            $Success=$false
        }
       
    }else{
        $Success=$false
        if ($Debug){Write-Host "Se recibio una identidad nula."}
    }
    Return $Success
}

#Quita los permisos de un buzon compartido de un usuario
function Remove-SharedMailboxPermissions($Identity,$Debug){
    $Success=$false

    #Verifica que la identidad no sea nula
    if (-not($Identity -eq $null)){

        #Obtiene los mailbox compartidos
        $SharedMailboxes=if (-not($SharedMailboxes)){Get-Mailbox -RecipientTypeDetails SharedMailbox}

        #Si obtuvo mailboxes
        if ($SharedMailboxes){

            #Identifica los permisos de buzon que tiene el usuario
            $MailboxPermissions= $SharedMailboxes | Get-MailboxPermission -User $Identity
            #Boolean para guardar el estado de las asignaciones
            $MailboxPermissionsRemoved=$true
            #Si existen permisos
            if ($MailboxPermissions){
                #Recorre la lista de permisos
                foreach ($MailboxPermission in $MailboxPermissions){
                    #Agrega el permiso al usuario
                    Remove-MailboxPermission -Identity ($MailboxPermission.identity) -AccessRights ($MailboxPermission.accessrights) -User $Identity -Confirm:$false #| Out-Null
                    #Verifica si hubo errores
                    if (-not($?)){
                        #Si hubo errores, corta el ciclo
                        $MailboxPermissionsRemoved=$false
                        Break
                    }
                }  
            }else{
                if ($Debug){Write-Host "No se encontraron permisos de buzon."}
            }
        
            #Identifica los permisos de envio que tiene el usuario
            $RecipientPermissions= $SharedMailboxes | Get-RecipientPermission -Trustee $Identity
            #Boolean para guardar el estado de las asignaciones
            $RecipientPermissionsRemoved=$true
            #Si existen permisos
            if ($RecipientPermissions){
                #Recorre la lista de permisos
                foreach ($RecipientPermission in $RecipientPermissions){
                    #Agrega el permiso al usuario
                    Remove-RecipientPermission -Identity ($RecipientPermission.identity) -AccessRights ($RecipientPermission.accessrights) -Trustee $Identity -Confirm:$false | Out-Null
                    #Verifica si hubo errores
                    if (-not($?)){
                        #Si hubo errores, corta el ciclo
                        $RecipientPermissionsRemoved=$false
                        Break
                    }
                }
            }else{
                if ($Debug){Write-Host "No se encontraron permisos de envio."}
            }

            #Verifica el exito de ambas operaciones
            if ($MailboxPermissionsRemoved -and $RecipientPermissionsRemoved){
                $Success=$true
                if ($Debug){Write-Host "Permisos de buzones y envio removidos."}
            }else{
                if ($Debug){Write-Host "Ocurrieron errores al remover permisos de buzones y envio."}
                $Success=$false
            }

        }else{
            if ($Debug){Write-Host "Error al obtener buzones de correo y sus permisos."}
            $Success=$false
        }
    }else{
        $Success=$false
        if ($Debug){Write-Host "Se recibio una identidad nula."}
    }

    Return $Success
}


function Get-SharedMailboxPermissions($Identity,$Debug){
	$MailboxPermissions=$false

	#Verifica que la identidad no sea nula
	if (-not($Identity -eq $null)){

		#Obtiene los mailbox compartidos
		$SharedMailboxes=if (-not($SharedMailboxes)){Get-Mailbox -RecipientTypeDetails SharedMailbox}

		#Si obtuvo mailboxes
		if ($SharedMailboxes){

			#Identifica los permisos de buzon que tiene el usuario
			$MailboxPermissions= $SharedMailboxes | Get-MailboxPermission -User $Identity
			#Si existen permisos
			if ($MailboxPermissions){
				#Los imprime
				$MailboxPermissions
			}else{
				if ($Debug){Write-Host "No se encontraron permisos de buzon."}
			}

			#Identifica los permisos de envio que tiene el usuario
			$RecipientPermissions= $SharedMailboxes | Get-RecipientPermission -Trustee $Identity
			#Si existen permisos
			if ($RecipientPermissions){
				$RecipientPermissions
			}else{
				if ($Debug){Write-Host "No se encontraron permisos de envio."}
			}

		}else{
			if ($Debug){Write-Host "Error al obtener buzones de correo y sus permisos."}
			$MailboxPermissions=$false
		}
	}else{
		$MailboxPermissions=$false
		if ($Debug){Write-Host "Se recibio una identidad nula."}
	}
	Return $MailboxPermissions
}
