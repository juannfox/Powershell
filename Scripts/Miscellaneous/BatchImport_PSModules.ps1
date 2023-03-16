<#
	Authored by Juan Fox in 2021.
	Batch import Powershell modules (supports local/relative modules)
#>

Param(
    [Parameter(Mandatory=$True)]
    [System.Array] $Modules_List,
    [Parameter(Mandatory=$False)]
    [Boolean] $Debug_Mode
)

#Globals
$MSG_Color_Operator="Cyan"
$MSG_Color_Error="Red"

function Modules_Import($Modules_List)
{
	<#
		Batch import Powershell modules (supports local/relative modules)
	#>
    $Success=$True
    #One by one import
    foreach ($Module in $Modules_List){
        if ($Debug_Mode){Write-Host "Importing module $Module."}
        #Actual import
        Import-Module $Module -NoClobber -DisableNameChecking
        #Remove any hints of a local module (path symbols like . or /) to have the raw module name only
        $Module=($Module.replace(".\Modules\","")).replace(".psm1","")
		#Verify success
        if (-not((Get-Module -Name $Module).name -eq $Module)){
            Write-Host "Error occurred when importing module $Module. Ensure it is installed or present in the right path." -ForegroundColor $MSG_Color_Error
            $Success=$False #Errors only
        }
    }
    Return $Success
}


#Script init
Modules_Import -Modules_List $Modules_List