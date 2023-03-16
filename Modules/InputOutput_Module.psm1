<#
    Authored by Juan Fox in 2021
    This module provides functions for input-output operations from a Powershell console.
#>

function Backup-PSCredential([PSCredential]$Credential,$Path){
    <#
        Stores an encripted password in a local file. Can only be decrypted by the same user importing it back into the console.
        Parameters:
            - Credential: The PSCredential object to store.
            - Path: The path for the encrypted output file.
        Returns: The file path or $False if error.
    #>
    $Name_Suffix=Get-Random -Maximum 99999999 -Minimum 11111111
    $Name_Prefix="pscrdenc"
    $File_Extension=""
    $FilePath=$Env:Temp
    if ($null -eq $Path){
        $Path=$FilePath+"\"+$Name_Prefix+$Name_Suffix+$File_Extension
    }
    $Credential | Export-CliXml -Path $Path
    if (-not(($?)-and(Test-Path $Path))){$Path=$False}
    Return $Path
}

function Restore-PSCredential($Path){
    <#
        Restores an encripted password from a local file (stored using Backup-PSCredential commandlet).
        Parameters:
            - Path: The path for the encrypted credential file.
        Returns: The PSCredential object or $null if error.
    #>
    $Credential=$null
    if (Test-Path $Path){
        $Credential = Import-CliXml -Path $Path
        if (-not($?)){$Credential=$null}
    }
    Return $Credential
}

function Get-CapitalizedString($StringValue){
    <#
        Capitalizes a string, meaning it turns the first letter of each word into upper-case.
        Parameters:
            - StringValue: The input string.
        Returns: The processed string or the original if error.
    #>
    $NewStringValue=$null

    #Verifies that the input is a string.
    if ($StringValue -is [String]){
        #Cleans leading and trailing spaces.
        $StringValue=($StringValue.Trimstart(" ")).TrimEnd(" ")
        #Creates an array based on spaces
        $Array=$StringValue -split " "
        #Word to word iteration
        foreach ($Word in $Array){
            #Convert to lower
            $Word=$Word.tolower()
            #Capitalize the first letter
            $FirstLetter=($Word.substring(0,1)).toupper()
            #Actual remplacement in the word
            $Word=$FirstLetter+$Word.remove(0,1)

            #Concatenates the word into the return string
            $NewStringValue+="$Word "
        }
    }

    #The processed string or the original if error.
    if ($null -eq $NewStringValue){$NewStringValue=$StringValue}
    Return $NewStringValue
}

function Read-HostMultiLine($Message,$Clear=$true){
    <#
        Allows for multi-line user input in console.
        Parameters:
            - Message: The message to show for the prompt (can be omitted to use default).
            - Clear: Wether to clear the screen after input (defaults to true).
        Returns: The user input
    #>
    $MultiLine=$null #Empty string for the multi-line content
    $Auxiliar=$null #Axuiliary sring
    #If the message is null, it shows a default value:
    if ($null -eq $Message){$Message="Enter multi-line input and press [ENTER]:"}
    #Shows input message
    Write-Output $Message

    #Loop until the last line is null
    do {
        #User input and store into an auxiliary variable
        Read-Host | Set-Variable Auxiliar
        #Adds the line content into the multi-line content and separates it with the new-line character
        Set-Variable -Name MultiLine -Value ($MultiLine+"`n"+$Auxiliar)
    }while($Auxiliar)

    #Clears the screen, if enabled
    if ($Clear){Clear}

    #Trims leading and trailing whitespaces
    $MultiLine = $MultiLine.trim()
    Return $MultiLine
}

function Replace_Ilegal_Characters($String){
    <#
        #Replaces ilegal characters in a string.
        Parameters:
            - String: The input string
        Returns: Processed string or the original if error or non found.
    #>
    #A map with ilegal characters and their replacements
    $CharacterDictionary=@{"á"="a";"é"="e";"í"="i";"ó"="o";"ü"="u";"ñ"="n";"-"="";"_"="";"."="";","="";"*"="";"#"="";"'"=""}

    #Verifies that the string is not null
    $StringIsNotNull=(-not($null -eq $String))
    #Verifica that the variable is a string
    $VariableIsString=$String -is [String]

    #Verifies that the parameter is string and not null
    if ($VariableIsString -and $StringIsNotNull){
        #Searches for each character in the list and -if found- replaces it with it's replacement.
        foreach ($Key in $CharacterDictionary.Keys){
            $Char_Replace=$Key #Character to replace
            $Char_New=$CharacterDictionary[$Key] #Replacing character
            $String=$String.replace($Char_Replace,$Char_New) #Actual replacement
        }
    }

    Return $String
}

function Wait-Progess($Wait){
    <#
        #Waits for a period of time (in seconds) and shows a progress bar, with a 1 second step.
        Parameters:
            - Wait: Wait time in seconds.
        Returns: Nothing
    #>
    for ($i = 0; $i -le $Wait; $i++ ){
        $Percentage=($i*100)/$Wait
        Write-Progress -Activity "Task in progress." -Status ("Time elapsed: $i/"+$Wait+"s") -PercentComplete $Percentage
        Start-Sleep 1 | out-null
    }
}