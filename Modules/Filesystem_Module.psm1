<#
This module provides useful functions to work with Windows filesystem.
#>

#Extracts the file or folder name from a full path.
function Get-FileNameFromPath($Full_Path){
    $File_Name=$null

    #Removes trailing "\" if present
    $Full_Path=$Full_Path.TrimEnd("\")

    #Array splitting by character "\". The use of double back-slashes is to escape the special char.
    $Path_Array=$Full_Path -split "\\"

    #Verifies if the path is actually longer than one directory
    $PathHasMultipleFolders=$Path_Array.count -gt 1
    if ($PathHasMultipleFolders){
        #The folder name would be on the latest index of the array (which uses a 0-based index)
        $File_Name=$Path_Array[$Path_Array.count - 1]
    }else{
        #If a simple directory was passed as argument.
        $File_Name=$Full_Path
    }
    #Returns the folder name or $null if the path is invalid.
    Return $File_Name
}


#Extracts the absolute path of a file or folder.
function Get-PathFromFile($Full_Path){
    $Absolute_Path=""
    #Array splitting by character "\". The use of double back-slashes is to escape the special char.
    $Path_Array=$Full_Path -split "\\"

    #Verifies if the path is actually longer than one directory
    $PathHasMultipleFolders=$Path_Array.count -gt 1
    if ($PathHasMultipleFolders){
        #The path is formed by every element but the latest one in the array (which uses a 0-based index)
        #So this is a structured loop within 0 and size-2.
        for (($i=0);($i -lt ($Path_Array.count-1));($i++)){
            $Absolute_Path+=$Path_Array[$i]+"\"
        }
    }else{
        $Absolute_Path="$Full_Path\"
    }
    #Returns the folder path or $null if the path is invalid.
    Return $Absolute_Path
}
