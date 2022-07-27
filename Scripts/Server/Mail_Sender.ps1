#Authored by Juan fox.

#Parameters - Also global variables
Param(
    [Parameter(Mandatory=$false)]
    [String] $PSChar=":",
    [Parameter(Mandatory=$true)]
    [String] $Param_Subject,
    [Parameter(Mandatory=$true)]
    [String] $Param_Body,
    [Parameter(Mandatory=$true)]
    [String] $Param_SmtpServer,
    [Parameter(Mandatory=$false)]
    [String] $Param_Port="25",
    [Parameter(Mandatory=$true)]
    [String] $Param_From,
    [Parameter(Mandatory=$true)]
    [String] $Param_To,
    [Parameter(Mandatory=$false)]
    [String] $Log_Path=".\",
    [Parameter(Mandatory=$false)]
    [String] $Log_File="Mail_Sender.log"
)

#Acts as a custom logger which both writes to stdout and logs to a file.
function Log-Message ($Message){
    Write-Host $Message
    Add-Content "$Log_Path\$Log_File" $Message
}

#Generate a log header
function Log_Heading(){
	#Clear the log file content if it exists already
    if (Test-Path "$Log_Path\$Log_File"){Clear-Content "$Log_Path\$Log_File"}
	#Fetches local data
	$Date=Get-Date
    $Hostname=$env:COMPUTERNAME

	#Leaves two blank lines and inputs the header
	Log-Message "`n`n<Message event. Date: $Date>"
}

#Generate a log closure
function Log_Closing(){
    Log-Message "<End of event>"
}

#Main function
function Main(){
	$Return_Value=$False
	Log_Heading
	
	#Logging
    $Parameters_Text="SMTP Server: <${Param_SmtpServer}:${Param_Port}> / From: <$Param_From> / To: <$Param_To> / Subject: <$Param_Subject>"
    Log-Message "Parameters:"
    Log-Message $Parameters_Text

    Try{
		#Actual message sending action 	
        Send-MailMessage -SmtpServer $Param_SmtpServer -Port $Param_Port -From $Param_From -To $Param_To -Subject $Param_Subject -Body $Param_Body
		Log-Message "Message sent."
		$Return_Value=$True
    }Catch{

        Log-Message "Error sending message."
        Log-Message "$Error"
    }
	
	Log_Closing
	Return $Return_Value
}

#Script init
$RC= if (Main) { 0 }else { 1 }
Exit $RC 