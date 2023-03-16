<#
    Authored by Juan Fox in 2021.
    This script will enable the property "MessageCopyForSentAsEnabled" on every
    Shared Mailbox from Exchange (Office 365 account with exchange, rather) in the target 
    tenant. It is meant to be run in an Azure Automation Account as a scheduled task.
#>


####Initial tasks#####
#Imports EOL module must exist in (Azure Automation Account that hosts this)
Import-Module ExchangeOnlineManagement
#Fetch the credential for administrating the target Exchange online instance
$Credential=Get-AutomationPSCredential -Name 'EOL_ADMIN'
#Connect to EOL
Connect-ExchangeOnline -Credential $Credential


####SMTP config####
#Fetch credential for sending emails via Office 365
$Credential=Get-AutomationPSCredential -Name 'EOL_EMAIL_SENDER'
#SMTP paameters
$To=Get-AutomationVariable -Name 'SMTP_To_Address'
$From=Get-AutomationVariable -Name 'SMTP_From_Address'
$Body= "Something went wrong when enabling MessageCopyForSentAsEnabled Exchange-wide."
$Subject= "Error enabling MessageCopyForSentAsEnabled on SharedMailboxes"


####Functions####

#Fetch all the shared mailboxes as objects.
function Get_SharedMailboxes(){
    $Return_Value=$False #Initial value

    #Fetch shared mailboxes
    $SharedMailboxes=Get-Mailbox -Filter "IsShared -eq '$True'"
    
    #Verify sanity
    if ($SharedMailboxes -is [Object]){ #Is an object
        if ($SharedMailboxes.count -gt 1){ #Is a list
            $Return_Value=$SharedMailboxes #Success, returns a list
        }else{
            Write-Error "Error fetching Shared mailboxes. Expected a list of objects, got a single object."
        }
    }else{
		Write-Error "Error fetching Shared mailboxes, invalid object output."
    }
    Return $SharedMailboxes
}


#Enable MessageCopyForSentAsEnabled on every shared mailbox in the parameter list
function Enable_MCFSAE_OnMailbox($SharedMailboxes){
    #MCFSAE=MessageCopyForSentAsEnabled
    #Clear error list 
    $Error.clear()

    #Initial count
    $SharedMailboxes_Count=$SharedMailboxes.count #Total shared mailboxes
    $SharedMailboxes_MCFSAE_Enabled_Count=0 #Total modified shared mailboxes
    $SharedMailboxes_MCFSAE_Disabled_Count=0 #Total disabled shared mailboxes

    #One by one enabling
    foreach ($SharedMailbox in $SharedMailboxes){
		#Store for ease of use
        $Alias=$SharedMailbox.alias
        $UPN=$SharedMailbox.UserPrincipalName

        #Filter out system/native mailboxes
        if (-not(($Alias).contains("DiscoverySearchMailbox"))){
			
			#Enable MCFSAE only if it is disabled
            if ($SharedMailbox.MessageCopyForSentAsEnabled -eq $False){
				
				#Edit the mailbox to enable MCFSAE (actual write operation)
                Set-Mailbox -Identity $UPN -MessageCopyForSentAsEnabled $True
				#Verify success by re-fetching the mailbox and verifying the status of MCFSAE
                if ((Get-Mailbox -Identity $UPN).MessageCopyForSentAsEnabled -eq $True){
                    $SharedMailboxes_MCFSAE_Enabled_Count+=1 #Add one to enabled count
                }else{
                    $SharedMailboxes_MCFSAE_Disabled_Count+=1 #Add one to disabled count
                }    
            }     
        }else{ #System/native mailboxes
            $SharedMailboxes_Count-=1 #Substract one from the total
        }

    }
    #Calculate results
    $SharedMailboxes_MCFSAE_Enabled_Difference_Count=$SharedMailboxes_Count-$SharedMailboxes_MCFSAE_Disabled_Count #Diff
    [Int]$SharedMailboxes_MCFSAE_Enabled_Percent=(($SharedMailboxes_MCFSAE_Enabled_Difference_Count*100)/$SharedMailboxes_Count) #Percentage
    #Print results
    Write-Warning "MCFSAE was enabled on $SharedMailboxes_MCFSAE_Enabled_Count shared mailboxes and $SharedMailboxes_MCFSAE_Disabled_Count could not be modified."
    Write-Warning "Then $SharedMailboxes_MCFSAE_Enabled_Difference_Count/$SharedMailboxes_Count shared mailboxes have MCFSAE active (about $SharedMailboxes_MCFSAE_Enabled_Percent%)."

    #Determine success, based on an acceptance quota
    $Success=if ($SharedMailboxes_MCFSAE_Enabled_Percent -lt 98){$False}else{$True}
    Return $Success
}

function Main (){
    $Success=$False
    #Fetch all shared mailboxes
    $SharedMailboxes=Get_SharedMailboxes
    #Validate output
    if (-not($SharedMailboxes -eq $False)){
        #Enable MessageCopyForSentAsEnabled (MCFSAE) on items within the list
        $Operation_Ok=Enable_MCFSAE_OnMailbox -SharedMailboxes $SharedMailboxes
        #Verify success
        if ($Operation_Ok){
            $Success=$True
            Write-Output "Finished successfully."
        }
    }

    #Error only
    if (-not($Success)){
        #Send an email alert via Office 365
        Send-MailMessage -From $From -to $To -Body $Body -Subject $Subject -SmtpServer outlook.office365.com -Credential $Credential -UseSsl
    }

    Return $Success #Boolean return
}


####Script init####
Main #Returns boolean

