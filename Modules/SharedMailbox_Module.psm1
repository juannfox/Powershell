<#
    Authored by Juan Fox in 2021.
    This module provides functions to easily operate with Shared Mailboxes from Exchange.
    Pre-requisites: An Exchange session with it's PS module must be imported before.
    Comment: This does need some DRY-ness, but it works.
#>

function Copy-SharedMailboxPermission($Source_Identity,$Identity,$Debug){
    <#
        Transfers an users Shared-Mailbox permissions to another. This would mean that if an user has full access to a mailbox, then the other
        one would end up having the same permission level.
        Works on two different aspects:
            - Mailbox permissions: The actual mailbox that holds the emails and Exchange functionalities.
            - Recipient permissions: The sender address for the mailbox.
        This might take a good while to finish, specially on a big Exchange setup.
        Parameters:
            - Source_Identity: The identity (meaning an Exchange object) of the source user.
            - Identity: The identity (meaning an Exchange Object) of the target user.
            - Debug: Wether to enable verbose output.
        Return: Boolean for success.
    #>
    $Success=$false

    #Verifies that the identities aren'tt null
    if (-not(($null -eq $Identity)-or($null -eq $Source_Identity))){
        #Gets all Shared Mailboxes (objects)
        $SharedMailboxes=Get-Mailbox -RecipientTypeDetails SharedMailbox

        #With the shared mailboxes -if not null-
        if ($SharedMailboxes){

            #Identifies mailbox permissions for the source user
            $MailboxPermissions= $SharedMailboxes | Get-MailboxPermission -User $Source_Identity
            #Boolean for further use
            $MailboxPermissionsTransfered=$true
            #If permissions exist
            if ($MailboxPermissions){
                #Iteration over permissions
                foreach ($MailboxPermission in $MailboxPermissions){
                    #Adds the current permission to the target user
                    Add-MailboxPermission -Identity ($MailboxPermission.identity) -AccessRights ($MailboxPermission.accessrights) -User $Identity -AutoMapping $true -Confirm:$false | Out-Null
                    #Verifies success
                    if (-not($?)){
                        #On error, break the loop
                        $MailboxPermissionsTransfered=$false
                        Break
                    }
                }
            }else{
                if ($Debug){Write-Output "No mailbox permissions found."}
            }

            #Identifies recipient permissions for the source user
            $RecipientPermissions= $SharedMailboxes | Get-RecipientPermission -Trustee $Source_Identity
            #Boolean for future use
            $RecipientPermissionsTransfered=$true
            #If permissions found
            if ($RecipientPermissions){
                #Iterates over permissions
                foreach ($RecipientPermission in $RecipientPermissions){
                    #Adds the current permission to the target user
                    Add-RecipientPermission -Identity ($RecipientPermission.identity) -AccessRights ($RecipientPermission.accessrights) -Trustee $Identity -Confirm:$false | Out-Null
                    #Verifies success
                    if (-not($?)){
                        #On error, break the loop
                        $RecipientPermissionsTransfered=$false
                        Break
                    }
                }
            }else{
                if ($Debug){Write-Output "No recipient permissions found."}
            }

            #Verifies success
            if ($MailboxPermissionsTransfered -and $RecipientPermissionsTransfered){
                $Success=$true
                if ($Debug){Write-Output "Recipient and Mailbox permissions transfered."}
            }else{
                $Success=$false
                if ($Debug){Write-Output "Errors occured when transfering permissions."}
            }

        }else{
            if ($Debug){Write-Output "Errors occured when fetching Shared Mailboxes.."}
            $Success=$false
        }

    }else{
        $Success=$false
        if ($Debug){Write-Output "One of the identities was null."}
    }
    Return $Success
}

function Revoke-SharedMailboxPermission($Identity,$Debug){
    <#
        Removes an users Shared-Mailbox permissions (all).
        Works on two different aspects:
            - Mailbox permissions: The actual mailbox that holds the emails and Exchange functionalities.
            - Recipient permissions: The sender address for the mailbox.
        This might take a good while to finish, specially on a big Exchange setup.
        Parameters:
            - Identity: The identity (meaning an Exchange Object) of the target user.
            - Debug: Wether to enable verbose output.
        Return: Boolean for success.
    #>
    $Success=$false

    #Verifies that the identity is not null
    if (-not($null -eq $Identity)){

        #Fetches Shared Mailboxes
        $SharedMailboxes=if (-not($SharedMailboxes)){Get-Mailbox -RecipientTypeDetails SharedMailbox}

        #If mailboxes were fetched
        if ($SharedMailboxes){

            #Identifies Mailbox Permissions assigned to the user
            $MailboxPermissions= $SharedMailboxes | Get-MailboxPermission -User $Identity
            #Boolean for future usage
            $MailboxPermissionsRemoved=$true
            #If permissions were found
            if ($MailboxPermissions){
                #Iterates over permissions
                foreach ($MailboxPermission in $MailboxPermissions){
                    #Removes the permission for the user
                    Remove-MailboxPermission -Identity ($MailboxPermission.identity) -AccessRights ($MailboxPermission.accessrights) -User $Identity -Confirm:$false #| Out-Null
                    #Verifies success
                    if (-not($?)){
                        #On error, break loop
                        $MailboxPermissionsRemoved=$false
                        Break
                    }
                }
            }else{
                if ($Debug){Write-Output "No Mailbox Permissions found."}
            }

            #Identifies Recipient Permissions assigned to the user
            $RecipientPermissions= $SharedMailboxes | Get-RecipientPermission -Trustee $Identity
            #Boolean para guardar el estado de las asignaciones
            $RecipientPermissionsRemoved=$true
            #If permissions were found
            if ($RecipientPermissions){
                #Iterates over permissions
                foreach ($RecipientPermission in $RecipientPermissions){
                    #Removes the permission for the user
                    Remove-RecipientPermission -Identity ($RecipientPermission.identity) -AccessRights ($RecipientPermission.accessrights) -Trustee $Identity -Confirm:$false | Out-Null
                    #Verifies success
                    if (-not($?)){
                        #On error, break loop
                        $RecipientPermissionsRemoved=$false
                        Break
                    }
                }
            }else{
                if ($Debug){Write-Output "No Recipient Permissions found."}
            }

            #Verifies success
            if ($MailboxPermissionsRemoved -and $RecipientPermissionsRemoved){
                $Success=$true
                if ($Debug){Write-Output "Mailbox and Recipient permissions removed."}
            }else{
                if ($Debug){Write-Output "Errors occured when removing permissions."}
                $Success=$false
            }

        }else{
            if ($Debug){Write-Output "Errors occured when fetching Shared Mailboxes."}
            $Success=$false
        }
    }else{
        $Success=$false
        if ($Debug){Write-Output "One of the identities was null."}
    }

    Return $Success
}


function Get-SharedMailboxPermission($Identity,$Debug){
    <#
        Gets an users Shared-Mailbox permissions.
        Works on two different aspects:
            - Mailbox permissions: The actual mailbox that holds the emails and Exchange functionalities.
            - Recipient permissions: The sender address for the mailbox.
        This might take a good while to finish, specially on a big Exchange setup.
        Parameters:
            - Identity: The identity (meaning an Exchange Object) of the target user.
            - Debug: Wether to enable verbose output.
        Return: Boolean for success.
    #>
	$MailboxPermissions=$false

	#Verifies that the identity is not null
	if (-not($null -eq $Identity)){

		#Fetches Shared Mailboxes
		$SharedMailboxes=if (-not($SharedMailboxes)){Get-Mailbox -RecipientTypeDetails SharedMailbox}

		#Validates that mailboxes were fetched
		if ($SharedMailboxes){

			#Identifies Mailbox Permissions assigned to the user
			$MailboxPermissions= $SharedMailboxes | Get-MailboxPermission -User $Identity
			#If permissions were found
			if ($MailboxPermissions){
				#Prints them
				$MailboxPermissions
			}else{
				if ($Debug){Write-Output "No Mailbox permissions were found."}
			}

			#Identifies Recipient Permissions assigned to the user
			$RecipientPermissions= $SharedMailboxes | Get-RecipientPermission -Trustee $Identity
			if ($RecipientPermissions){
				$RecipientPermissions
			}else{
				if ($Debug){Write-Output "No Mailbox permissions were found."}
			}

		}else{
			if ($Debug){Write-Output "Error fetching Shared Mailboxes."}
			$MailboxPermissions=$false
		}
	}else{
		$MailboxPermissions=$false
		if ($Debug){Write-Output "One of the identities was null."}
	}
	Return $MailboxPermissions
}
