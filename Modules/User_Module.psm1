<#
    Authored by Juan Fox in 2021
    This module provides a set of useful functions and warapper-functions to work with Active Directory and Azure Active Directory (AD and AAD) in an easy way.
#>


function User_AAD_Get_UserObjectId ($Filter_Name,$Filter_Value){
    <#
        Safely gets Azure Active Directory Object ID from a filter property set (i.e. full name or email).
        Parameters:
            - Filter_Name: The name of the property/attribute of the user to use as filter.
            - Filter_Value: The value of the filter property/attribute.
        Return: ObjectId of the user if found, $Null if not found.
    #>
    $Return_ObjectId=$Null

    #Gets AAD object
    $User_Object=Get-AzureADUser -Filter "$Filter_Name eq '$Filter_Value'" -ErrorAction SilentlyContinue

    #Stores data
    $User_Count=$User_Object.count
    $User_DisplayName=$User_Object.DisplayName
    $User_ObjectId=$User_Object.ObjectId

    #Verifies that object is unique and valid
    if (($User_Object -Is [object])-And($User_Count -eq "1")){
        Write-Output "Trabajando con $User_DisplayName ($User_ObjectId)."
        $Return_ObjectId=$User_ObjectId #Success
    }else{
        Write-Output "Object is invalid or multiple."
    }
    Return $Return_ObjectId
}


function User_AD_Get_CloudRelatedObject($DistinguishedName){
    <#
        Gets ObjectId of an AAD user object, filtering by local Active Directory Distinguished Name (DN). This only works on hybrid setups with an AD-Connect working to
        synchronize on-premises users to AAD.
        Parameters:
            - DistinguishedName: Distinguished Name of the related on-premises AD user.
        Return: ObjectId of the user if found, $Null if not found.
    #>
    $ObjectId=$null
    $AADUser_Object=$null

    if (-not($null -eq $DistinguishedName)){
        #Gets all AAD objects and filter them by extended property holding the DN of the AD object sync.
        $AADUser_Object=Get-AzureADUser -All $true -ErrorAction SilentlyContinue | Where-Object {$_.ExtensionProperty.onPremisesDistinguishedName -eq "$DistinguishedName"}

        #Stores data
        $ObjectId=$AADUser_Object.ObjectId
    }

    #Verifies that object is unique and valid
    if (($AADUser_Object -isnot [object])-Or($AADUser_Object.count -ne "1")){
        $ObjectId=$null #If error
    }

    Return $ObjectId
}

function User_AD_Get_UserObject ($SAMAccountName){
    <#
        Gets an on-premises AD user's object by its SAMAccountName.
         Parameters:
            - SAMAccountName: SAMAccountName (username) of the user.
        Return: Object of the user if found, $Null if not found.
    #>
    $Return_Object=$False #Initial value
    $AD_User_Object=$null
    #Obtains the user object
    try{
        $AD_User_Object=Get-ADUser -Identity $SAMAccountName -Properties *
    }catch{
        $AD_User_Object=$False
    }
    #Verifies that object is unique and valid
    if (($AD_User_Object -is [Object])-And($AD_User_Object.SAMAccountName -eq $SAMAccountName)){
        $Return_Object=$AD_User_Object #Stores the object
    }
    Return $Return_Object
}

function User_Input_User($Message){
    <#
        Interactively asks for input to fetch an AD-OnPremises user object based on SAMAccountName (Username) and allows for retries.
        Parameters:
            - Message: Message to show previouis to the input.
        Return: Object of the user when found.
    #>
    $Return_Object=$False #Initial value
    #User input
    Write-Output $Message
    $User_Input=Read-Host "Enter username to fetch"

    #Gets the user object
    $AD_User_Object=User_AD_Get_UserObject -Samaccountname $User_Input
    #Verifies that object is unique and valid
    if (($AD_User_Object -is [Object])-And($AD_User_Object.samaccountname -eq $User_Input)){
        $Name=$AD_User_Object.Name
    	Write-Output "Detected user: <$Name>. Ok to continue?"
		$Choice = Read-Host "Enter y/n"
		if ($Choice -eq 'y'){
            $Return_Object=$AD_User_Object #Stores the object
        }
    }else{
        Write-Output "User $User_Input not found in AD. Try again..."
        $Return_Object=User_Input_User -Message $Message #Recursive self-call
    }
    Return $Return_Object #Only return when successful
}

function User_AD_Wait_Changes($User_Samaccountname,$Property_Name,$Property_TargetValue,$Time_Wait=15,$Time_Step=5){
    <#
        Waits until an AD user object shows an expected change or the wait time runs out.
        Parameters:
            - User_Samaccountname: The username of the object to watch.
            - Property_Name: The property to watch.
            - Property_TargetValue: The expected value of the property.
            - Time_Wait: The time to wait in seconds.
            - Time_Step: The time between intervals in seconds
        Return: Boolean for success.
    #>
    $User_Object,$Property_DetectedValue
    $Success,$AboveTimeLimit,$ChangesNotFound

    Do{
        #Gets the AD object
        $User_Object=Get-ADUser -Identity $User_Samaccountname -Properties ($Property_Name)
        #Gets the value of the property
        $Property_DetectedValue=$User_Object.$Property_Name
        #Compares the actual value to the desired one
        if ($Property_DetectedValue -eq $Property_TargetValue){
            $ChangesNotFound=$False #Cut condition
        }else{
            $ChangesNotFound=$True #Cut condition
            #Waits
            Start-Sleep $Time_Step | Out-Null
            #Removes the time spent
            $Time_Wait-=$Time_Step
            #Validates time condition
            $AboveTimeLimit=$Time_Wait -gt 0
        }

    }while($ChangesNotFound -and $AboveTimeLimit)

    #Returns success if changes found.
    $Success=-not $ChangesNotFound

    Return $Success
}

Function User_AD_Backup_Properties ($User_Object, $Backup_Path){
    <#
        Backs up the properties of an AD user in a plain-text file.
        Parameters:
            - User_Object: The AD object to backup.
            - Backup_Path: The path for the output file.
        Return: Boolean for success.
    #>
    $Success

    #Default path in TEMP (user level)
    if (-not(Test-Path $Backup_Path)){
        $Backup_Path=$env:TEMP
    }

    #Creates the folder if it does not exist.
	If (-Not(Test-Path ("$Backup_Path\"+$User_Object.samaccountname))){
        New-Item -Name $User_Object.samaccountname -Path $Backup_Path -ItemType Directory
    }

    #Output file name.
    $Backup_File_Path="$Backup_Path\"+$User_Object.samaccountname+"\"
    $Backup_File_Name=$User_Object.samaccountname+"-AD.bkp"

    #Verifies that the file does not exist already and creates it
    if (-not(Test-Path "$Backup_File_Path\$Backup_File_Name")){
        New-Item -Path $Backup_File_Path -ItemType File -Name $Backup_File_Name | Out-Null
    }

    #Verifies that the file exists
    if (Test-Path "$Backup_File_Path\$Backup_File_Name"){
        #Inserts header comment with the current date in MMDDYYYY format
        Add-Content -Path "$Backup_File_Path\$Backup_File_Name" -Value ('#'+(Get-Date -Format "MM/dd/yyyy"))

        #List with atributes/properties
        $PropertyList=$User_Object.PropertyNames
        #Writes each property to a file in append mode
        ForEach ($Property In $PropertyList){
            Add-Content -Path "$Backup_File_Path\$Backup_File_Name" -Value ("$Property"+":"+$User_Object.$Property)
        }

        #Verifies that content is not null
        if (-not($null -eq(Get-Content "$Backup_File_Path\$Backup_File_Name"))){
            $Success=$True
            Write-Output "User profile backuped up in <$Backup_File_Path\$Backup_File_Name>."
        }else{
            $Success=$False
        }
    }else{
        $Success=$False
    }
    Return $Success
}

function User_Transfer_ADGroups($Source_User,$Target_User,$Filter_ADGroup,$Debug){
    <#
        Transfers an AD user's groups to another -without removing the old ones-.
        Parameters:
            - Source_User: The source user (with the origin groups).
            - Target_User: The target user.
            - Filter_ADGroup: An AD group that is used as a filter for those groups to exclude. Any group that is member of this group will be ignored.
            - Debug: Wether to enable debug mode with verbose messages.
        Return: Boolean for success.
    #>
    $Success=$False
    $ADGroups_Assigned=0
    $ADGroups_Filtered=0
    $Filter_ADGroup_Members=$null

    if ($Debug){Write-Output "Transfering AD groups from user <$Source_User> to <$Target_User>."}

    #Gets filter group members (other groups) to create an excluded-list
    try{
        if ($Debug){Write-Output "Fetching filter groups from group <$Filter_ADGroup>."}
        $Filter_ADGroup_Members=Get-ADGroupMember -Identity $Filter_ADGroup
    }catch{
        Write-Output "Error fetching filter groups from <$Filter_ADGroup>"
    }

    try{
        #Gets the users the source user is member of
        $Source_User_ADGroups=(Get-ADUser $Source_User -properties memberof).memberof
        foreach ($Group in $Source_User_ADGroups){
            #Verifies if the group needs to be exlucded
            if ($Group -notin $Filter_ADGroup_Members.distinguishedname){
                #Adds the target user to the group
                if ($Debug){Write-Output "Adding group <$Group>."}
                Add-ADGroupMember -Identity $Group -Members $Target_User -ErrorAction SilentlyContinue
                if ($?){$ADGroups_Assigned+=1}
            }else{
                if ($Debug){Write-Output "Filtering group <$Group>."}
                $ADGroups_Filtered+=1
            }
        }

        #Verifies success
        if (($ADGroups_Assigned+$ADGroups_Filtered) -eq $Source_User_ADGroups.count){
            $Success=$True
        }else{
            $Success=$False
        }
    }catch{
        Write-Output "Error fetching groups the source user <$Source_User> is member of."
        $Success=$False
    }

    return $Success
}

