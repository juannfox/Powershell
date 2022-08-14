<#
    Modulo que trabaja con las licencias de Azure AD (que tambien reflejan las de Office 365)
#>


#Establece la zona de uso de un usuario, necesaria para las licencias
function Set_UsageLocation ($User_ObjectId,$Usage_Location="AR"){
    $Assigned=$False
    #Establece zona de uso, para que se pueda aplicar la licencia
    Write-Host "Estableciendo zona de uso $Usage_Location."
    Set-AzureADUser -ObjectId $User_ObjectId -UsageLocation $Usage_Location
    Start-Sleep 5

    #Valida asignacion de zona de uso
    if ((Get-AzureADUser -ObjectId $User_ObjectId).UsageLocation -eq $Usage_Location){
        $Assigned=$True
    }else{
        Write-Error "Hubo un error al establecer zona de uso $Usage_Location."
    }
    Return $Assigned
}

#Asigna una licencia especifica a un usuario
function Set_License ($User_ObjectId, $SkuId){
    $Assigned=$False
    #Asigna zona de uso
    $UsageLocation_Set=Set_UsageLocation -User_ObjectId $User_ObjectId -Usage_Location $Usage_Location
    if ($UsageLocation_Set){ #Verifica asignacion
        #Crea una lista de licencias en formato adecuado
        $Licenses_Object = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
        #Arma una licencia vacia
        $License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense 
        $License.SkuId = $SkuId #Carga el SKUID
        $Licenses_Object.AddLicenses = $License #Carga la licencia en el objeto de lista de licencias

        #Asigna la licencia
        Write-Host "Asignando licencia $SkuId."
        Set-AzureADUserLicense -ObjectId $User_ObjectId -AssignedLicenses $Licenses_Object -ErrorAction SilentlyContinue -ErrorVariable Script_Last_Error
        Start-Sleep 5

        #Valida asignación de licencia
        $User_SkuIDs=(Get-AzureADUser -ObjectId $User_ObjectId).AssignedLicenses.SkuId
        if ($SkuID -in $User_SkuIDs){
            $Assigned=$True   
        }else{
            Write-Error "Hubo un error al asignar la licencia $SkuId."
        }
    }

    Return $Assigned
}


#Quita una licencia especifica de las licencias asignadas a un usuario

function Remove_License ($User_ObjectId, $SkuId,$Debug){
    $Removed=$False
    $Assigned_Licenses_Before=((Get-AzureADUser -ObjectId $User_ObjectId).AssignedLicenses).count
    if ($Debug){Write-Host "Quitando licencia <"+$SkuId+"> de usuario <"+$User_ObjectId+">."}

    #Crea una lista de licencias en formato adecuado
    $Licenses_Object = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
    #Arma una licencia vacia
    $License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense 
    $Licenses_Object.AddLicenses = $License #Carga la licencia en el objeto de lista de licencias

    #Asigna la licencia
    Start-Sleep 5

    #Crea una licencia e indica que SKUID eliminar
    $License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
    $License.RemoveLicenses = $SkuId
    #Remueve la licencia
    Set-AzureADUserLicense -ObjectId $User_ObjectId -AssignedLicenses $License

    #Espera y busca el cambio, para ver si tomo efecto
    $WaitTime=15
    $TimeElapsed=0
    While((-not($Removed))-and($TimeElapsed -lt $WaitTime)){
        #Verifica si se elimino
        $Assigned_Licenses_After=(Get-AzureADUser -ObjectId $User_ObjectId).AssignedLicenses
        if (($Assigned_Licenses_Before-$Assigned_Licenses_After.count) -eq 1){
            $Removed=$True
        }else{
            Start-Sleep 1
            $TimeElapsed+=1
        }
    }

    if ($Debug){Write-Host "Resultado de quitar licencia: "+$Removed+"."}
    
    Return $Removed
}