#Authored by Juan Fox. 

#Parameters for execution.
Param(
    [Parameter(Mandatory=$false)]
    [String] $Treshold_Days=15,
    [Parameter(Mandatory=$false)]
    [String] $Target_Path=(Get-Location).path,
    [Parameter(Mandatory=$false)]
    [String] $Target_Extension=".log",
    [Parameter(Mandatory=$false)]
    [String] $Exclude="",
    [Parameter(Mandatory=$false)]
    [String] $Log_Path=(Get-Location).path, #Global
    [Parameter(Mandatory=$false)]
    [String] $Log_Filename="Log_Cleanup.log"  #Global
)


#Acts as a custom logger. Writes the message to STDOUT and also logs it to the log file.
function Log_Message($Message){
    Write-Host $Message #Stdout
    Add-Content -Path "$Log_Path\$Log_Filename" -Value $Message #Writes a line to the log file.
}

#The actual steps to perform on each path. This is were you can customize or even call an external script (&yourScriptPath $FileName).
function Perform_Tasks($File_Name){
    Log_Message "Deleting <$File_Name>." #Logs the line
    Remove-Item $File_Name -Force #Deletes the file.
}

#Main function with operational steps.
function Main($Target_Path,$Treshold_Days,$Target_Extension,$Exclude){
	#Log header.
	if (test-path "$Log_Path\$Log_Filename"){Clear-Content "$Log_Path\$Log_Filename" -Force} #If it does exist, it erases the log file content.
    $Date=Get-Date
    $Hostname=$env:COMPUTERNAME
    Log_Message "Working on <$Hostname>, Date: <$Date>, Path: <$Target_Path>, Treshold: <$Treshold_Days> days."

	#Exclusions list, turned into an array for each CSV item.
	$Exclude_List=$Exclude -split ","
	Log_Message "Excluding files: $Exclude."

    #Operations
    $Deleted_Count=0
    $Treshold_Date=(Get-Date).AddDays(-1*$Treshold_Days) #Gets the current date and substracts the amount of treshold days.
	$File_List = Get-ChildItem -Path $Target_Path -Force #Fetches file list within the path.
	#Loop over each file (object) in the list
    foreach ($Object in $File_List){
        if (($Object.Extension -eq $Target_Extension)-and($Object.PSIsContainer -eq $false)-and(-not($Object.Name -in $Exclude_List))){ #Filters out folders/files within the exclusion scope
            if ($Object.LastWriteTime -lt $Treshold_Date){ #Identifies files modified before the treshold date
                $File_Name=$Object.Name
                Perform_Tasks "$Target_Path\$File_Name" #Performs the desired tasks within an external function
                $Deleted_Count=$Deleted_Count+1
            }
        }
    }
    if ($Deleted_Count -eq "0"){Log_Message "No files were found with modification date prvious to $Treshold_Date."}
}

#Script init
Main $Target_Path $Treshold_Days $Target_Extension $Exclude