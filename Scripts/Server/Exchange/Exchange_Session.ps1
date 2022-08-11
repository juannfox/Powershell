<#
	Author:
		Juan Fox - 2022
	About:
		This script establishes a Remote Powershell Session with an Exchange server and imports the Exchange modules.
	Requirements:
		This works for Microsoft Exchangeversions 2013-2019.
	Platform:
		Windows Powershell 5.1 or Powershell 7
#>

Param(
    [Parameter(Mandatory=$False)]
    [String] $Server_FQDN="",
    [Parameter(Mandatory=$False)]
    [PSCredential] $Credential=$null
)

function Get-ExchangeSession($Server_FQDN, $Credential)
{
	<#
		Establishes a remote PSSession with an Exchange server and adds the Exchange modules.
		Parameters: - Server_FQDN: The destination server's Fully-Qualified-Domain-Name.
					- Credential: A valid PSCredential to authenticate against the server (must have sufficient permissions).
		Returns: Nothing
	#>

	try
	{
		#Establishes the sesion
		$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$Server_FQDN/PowerShell/" -Authentication Kerberos -Credential $Credential
		Import-PSSession $Session -DisableNameChecking
	}
	catch
	{
		Write-Error "Could not establish a Remote Powershell Session with <$Server_FQDN>."
	}
	
}

function Assert-Parameters()
{
	<#
		Validates input parameters or asks for manual input.
	#>
	
	if ($Server_FQDN -eq "")
	{
		$Server_FQDN = Read-Host "Server FQDN must be defined. Please enter it"
	}
	if ($null -eq $Credential)
	{
		$Credential = Get-Credential -Message "Username/Password must be entered to use as credentials. Please enter them"
	}
}

#Script init
Assert-Parameters #Validate parameters
Get-ExchangeSession -Server_FQDN $Server_FQDN -Credential $Credential #Import the sesion