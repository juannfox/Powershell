<#
	Authored by Juan Fox in 2021.
    Wrapper to connect the session to Exchange Online.
#>

Param (
	[Parameter(Mandatory = $True)]
	[String]$TenantId
)

#Globals
$MSG_Color_Operator="Cyan"
$MSG_Color_Error="Red"

function Get_EOL_Connection()
{
	<#
		Connect the session to Exchange Online
	#>
    $Success=$True

    #Verify whether the sesion is already connected
    if (-not("outlook.office365.com" -in (Get-PSSession).ComputerName)){
        Write-Host "Connecting to Exchange Online." -ForegroundColor $MSG_Color_Operator
        #Connect to EOL
        try{
            $EOL_Connection=Connect-ExchangeOnline -ShowBanner:$false -ErrorAction SilentlyContinue
        #On failure
        }catch{
            $Success=$False
            Write-Host "Error connecting to Exchange Online." -ForegroundColor $MSG_Color_Error
            #Prompt the user for retry
            $Choice=Read-Host "Would you like to retry? (Enter y/n)"
            if ($Choice -eq "y"){
                #Self call (recursive)
                $Success=Get_EOL_Connection
            }
        }
    }
    Return $Success
}

#Script init
Get_EOL_Connection $TenantId
