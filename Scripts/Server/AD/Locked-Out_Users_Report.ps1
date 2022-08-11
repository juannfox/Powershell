<#
	Authored by Juan Fox in 2021.
	Generates and prints a report of total user count, locked out user list and password expired user list for a defined set of domain controllers/domains.
#>

function Get-All_Users ($Domain_Controllers)
{
	<#
		Obtains all the users (reduced objects) in all the Domain Controllers received as parameter.
	#>
    ForEach ($Domain_Controller In $Domain_Controllers){
        $Domain_Controller_Users=Get-DC_Users -Domain_Controller $Domain_Controller
        $Users=$Users+$Domain_Controller_Users
    }
    Return $Users
}

function Get-DC_Users($Domain_Controller)
{
	<#
		Obtains all the users (reduced objects) in a Domain Controller.
	#>	
    Return $Users= Get-ADUser -Filter * -Server $Domain_Controller -Properties passwordexpired,enabled,name,samaccountname,mail
}

function Get-Users_Locked_Out ($Users)
{
	<#
		Identifies those users that are Locked Out.
	#>	
    $Filtered_Items= New-Object Collections.Generic.List[Object]
    ForEach ($User In $Users){
        If ($User.Enabled -Match "False"){
            $Filtered_Items.Add($User)
        }
    }
    Return $Filtered_Items
}

function Get-Users_Password_Expired ($Users)
{
	<#
		Identifies those users whose password has expired.
	#>	
    $Filtered_Items= New-Object Collections.Generic.List[Object]
    ForEach ($User In $Users){
        If ($User.Users_Password_Expired -Match "True"){
            $Filtered_Items.Add($User)
        }
    }
    Return $Filtered_Items
}


function Get-User_Line ($User_Object)
{
	<#
		Generates a string with user information obtained from it's object.
	#>	
    $Name=$User_Object.Name
    $SAMAccountName=$User_Object.SAMAccountname
    $Email=$User_Object.mail
    Return "$SAMAccountname, $Email, $Name"
}


function Report ($Domain_Controllers)
{
	<#
		Generates and prints a report on the users on all the domain controllers, including:
		- Total user count
		- Locked-out and passowrd-expired users list with SAM-Account-Name, Name and Email.
	#>	
    $Users=Get-All_Users -Domain_Controllers $Domain_Controllers
    $Users_Locked_Out=Get-Users_Locked_Out -Users $Users
    $Users_Password_Expired=Get-Users_Password_Expired -Users $Users

    Write-Host "Total users: "($Users.Count)
    Write-Host "Locked out users :"($Users_Locked_Out.Count)
    Write-Host "Users with password expired: "($Users_Password_Expired.Count)
}


#Script init
$Domain_Controllers=Read-Host "Enter comma-separated Domain list" #User input
$Domain_Controllers=$Domain_Controllers -Split "," #Convert into array

Report $Domain_Controllers #Generate and print the report