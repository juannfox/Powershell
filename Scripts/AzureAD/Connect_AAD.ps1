<#
    Authored by Juan Fox in 2021.
    Wrapper for connecting with Azure AD, which avoids
    showing awful errors when the session is not connected
    and instead attempts to solve it by re-logging into
    the remote service.
#>

Param(
    [Parameter(Mandatory=$True)]
    [String] $TenantId,
    [Parameter(Mandatory=$False)]
    [String] $SuggestedUPN    
)

#Globals
$MSG_Color_Operator="Cyan"
$MSG_Color_Error="Red"


function Get_AAD_Connection($TenantId, $SuggestedUPN)
{
	<#
		Establish connection to AAD
	#>
    $Success=$True

    #Verify wether the session is already connected to AAD
    try {
        $Null_Var=Get-AzureADCurrentSessionInfo -ErrorAction SilentlyContinue

    #Catch the error if it is not connected and start the connection process
    }catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException],[Microsoft.Open.Azure.AD.CommonLibrary.GetAzureADCurrentSessionInfo]{
        Write-Host "Connecting to Azure AD." -ForegroundColor $MSG_Color_Operator
        Set-Clipboard $SuggestedUPN #Copies the UPN (optional) to the clipboard
        #Connect to AAD
        try{
            $AAD_Connection=Connect-AzureAD -TenantId $TenantId -ErrorAction SilentlyContinue
        #On failure
        }catch{
            $Success=$False
			Write-Host "Error occured when connecting to Azure AD's tenant $TenantId." -ForegroundColor $MSG_Color_Error
            #Prompt the user to retry
            $Choice=Read-Host "Would you like to try again? (Enter y/n)"
            if ($Choice -eq "y"){
                #Recursive self call
                $Success=Get_AAD_Connection
            }
        }
    }
    Return $Success
}

#Inicio
Get_AAD_Connection -TenantId $TenantId -SuggestedUPN $SuggestedUPN