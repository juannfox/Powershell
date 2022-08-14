<#
    Authored by Juan Fox in 2021
    This module provides functions to work with Azure AD (AAD) licenses (Office 365 licenses too).
#>

function Set_UsageLocation ($User_ObjectId,$Usage_Location="AR"){
    <#
        Sets the usage location for an AAD user, which is necessary to assign a license.
        Parameters:
            - User_ObjectId: The objectId for the target user.
            - Usage_Location: The usage-location code (Defaults to "AR" for Argentina).
        Return: Boolean for success.
    #>
    $Assigned=$False
    #Sets the usage location
    Write-Output "Establishing usage location: $Usage_Location."
    Set-AzureADUser -ObjectId $User_ObjectId -UsageLocation $Usage_Location
    Start-Sleep 5

    #Verifies success
    if ((Get-AzureADUser -ObjectId $User_ObjectId).UsageLocation -eq $Usage_Location){
        $Assigned=$True
    }else{
        Write-Error "There was an error setting usage location: $Usage_Location."
    }
    Return $Assigned
}

function Set_License ($User_ObjectId, $SkuId){
    <#
        Assigns a specific license to an user. The license is assigned as is and all the default products it contains are activated.
        Parameters:
            - User_ObjectId: The objectId for the target user.
            - SkuId: The SkuId for the license.
        Return: Boolean for success.
    #>
    $Assigned=$False
    #Sets the usage zone
    $UsageLocation_Set=Set_UsageLocation -User_ObjectId $User_ObjectId -Usage_Location $Usage_Location
    if ($UsageLocation_Set){ #Verifies if the usage location is set
        #Creates a licenses list object in the necessary format
        $Licenses_Object = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
        #Creates an empty license object in the necessary format
        $License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
        $License.SkuId = $SkuId #Loads the SkuId
        $Licenses_Object.AddLicenses = $License #Loads the license into the licenses object

        #Adds the license
        Write-Output "Adding license $SkuId."
        Set-AzureADUserLicense -ObjectId $User_ObjectId -AssignedLicenses $Licenses_Object -ErrorAction SilentlyContinue -ErrorVariable Script_Last_Error
        Start-Sleep 5

        #Verifies success
        $User_SkuIDs=(Get-AzureADUser -ObjectId $User_ObjectId).AssignedLicenses.SkuId
        if ($SkuID -in $User_SkuIDs){
            $Assigned=$True
        }else{
            Write-Error "There was an error adding license $SkuId."
        }
    }

    Return $Assigned
}

function Remove_License ($User_ObjectId, $SkuId,$Debug){
    <#
        Removes a specific license from an user.
        Parameters:
            - User_ObjectId: The objectId for the target user.
            - SkuId: The SkuId for the license.
            - Debug: Wether to enable debug for verbose output.
        Return: Boolean for success.
    #>
    $Removed=$False
    $Assigned_Licenses_Before=((Get-AzureADUser -ObjectId $User_ObjectId).AssignedLicenses).count
    if ($Debug){Write-Output "Removing license with SkuId <"+$SkuId+"> from user <"+$User_ObjectId+">."}

    #Creates a licenses list object in the necessary format
    $Licenses_Object = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
    #Creates an empty license object in the necessary format
    $License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
    $Licenses_Object.AddLicenses = $License #Loads the license

    #Creats a license object
    $License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
    #Removes the license from the object
    $License.RemoveLicenses = $SkuId
    #Removes the license
    Set-AzureADUserLicense -ObjectId $User_ObjectId -AssignedLicenses $License

    #Waits before checking for success
    $WaitTime=15
    $TimeElapsed=0
    While((-not($Removed))-and($TimeElapsed -lt $WaitTime)){
        #Verifies if the license was removed
        $Assigned_Licenses_After=(Get-AzureADUser -ObjectId $User_ObjectId).AssignedLicenses
        if (($Assigned_Licenses_Before-$Assigned_Licenses_After.count) -eq 1){
            $Removed=$True
        }else{
            Start-Sleep 1
            $TimeElapsed+=1
        }
    }

    if ($Debug){Write-Output "Result of removing the license: "+$Removed+"."}

    Return $Removed
}