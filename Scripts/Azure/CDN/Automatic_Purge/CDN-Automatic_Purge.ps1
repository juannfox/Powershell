<#
	Author:
		Juan Fox - 2022
	About:
		This script automates the cache purge on an Azure CDN Profile with a Storage Account blob backend, which is known
		to cause issues in certain regions (due to cache living up to 48hs).
		
		To do so, it queries the backend Storage Account (SA) for files that have been modified within a set treshold time
		window and then connects to the CDN profile to perform the cache purge on those particular files.

		It is meant to be run on a schedule from within an Azure Automation Account task (AACC), so scheduling is outside it's
		scope of responsibilities. It also does not log or persist to any external component, other than AACC's console.
	Important:
		This script depends on AZ Powershell module and is meant to be run within an Azure Automation Account
		with System Managed Identity authentication to ARM and proper authorization on both the CDN profile (write is necessary)
		and the Storage Account (read is enough), some AACC set variables and lastly valid email permissions and parameters 
		(addresses, credentials and a public internet server with SSL).
	Platform:
		Windows Powershell 5.1.
		Could potentially be run in Powershell 7, as long as the "AZ Powershell" module dependancy supports it.
#>

function Get-ContainerModifiedBlobs($StorageAccount_Context,$StorageAccount_Container_Name,$Date_Treshold_Hours,$Debug=$False){
	<#
		Identifies those blob files within a Storage Account Container that have been modified after a treshold time window.
		-Parameters:
			$StorageAccount_Context: A custom Microsoft Azure object containing information necessary to identify the target Storage Account.
			$StorageAccount_Container_Name: The name of the target container/s within the SA. This needs to be specific and accurate.
			$Date_Treshold_Hours: Amount of hours to look back for changes.
			$Debug: Wether to increase verbosity for debugging.
		-Outputs: A list of URL Paths (CDN-side identifiers for the Storage Account files) for the modified files -if found- or $false.
	#>
	
	#Calculates the treshold date in a Powershell compatible format (object).
    $Trigger_Date=(Get-Date).AddHours(-$Date_Treshold_Hours)

    if ($Debug){Write-Warning "Working on container '$StorageAccount_Container_Name' with dates later than '$Trigger_Date'."}

    #Lists the Blob container content (similar to 'ls', 'dir' or 'Get-Child-Item') and stores it within a variable
    $Blob_Content=Get-AzStorageBlob -Context $StorageAccount_Context -Container $StorageAccount_Container_Name
	$Blob_File_Count = $Blob_Content.count
	
	#Emtpy list for URL Paths.
    $CDN_Content_URLPaths=@()

    #Looop through every item in the list, comparing it's modification date with the treshold date.
    foreach ($BlobFile in $Blob_Content){
        #Stores important object properties
        $BlobFile_Name=$BlobFile.Name
        $BlobFile_ModifiedDate=$BlobFile.LastModified.DateTime #Date is a nested object
        
        #Compares the date
        if ($BlobFile_ModifiedDate -gt $Trigger_Date){
            #Composes the URL Path for the Storage Account with a CDN format.
            $CDN_Content_URLPath="/$StorageAccount_Container_Name/$BlobFile_Name"
            #Adds the path to the list
            $CDN_Content_URLPaths+=$CDN_Content_URLPath

            if ($Debug){Write-Warning "Changes later than $Trigger_Date found >> File '$BlobFile_Name' ($CDN_Content_URLPath) modified on '$BlobFile_ModifiedDate'."}
        }
    }
	
	#Verifies if no changes have been found and -in that case- it turns the return value into $false.
    if ($CDN_Content_URLPaths.count -eq 0){$CDN_Content_URLPaths=$False;if ($Debug){Write-Warning "No changes found within container '$StorageAccount_Container_Name'."}}

    Return $CDN_Content_URLPaths
}

function Get-StorageAccountModifiedBlobs($StorageAccount_Context, $StorageAccount_Container_Name, $Date_Treshold_Hours, $Debug = $False){
	<#
		Identifies those blob files within a Storage Account that have been modified after a treshold time window.
		-Parameters:
			$StorageAccount_Context: A custom Microsoft Azure object containing information necessary to identify the target Storage Account.
			$StorageAccount_Container_Name: The name of the target container/s within the SA. Accepts '*', '/' and '$null' as special tokens for scoping every container instead of a particular one.
			$Date_Treshold_Hours: Amount of hours to look back for changes.
			$Debug: Wether to increase verbosity for debugging.
		-Outputs: A list of URL Paths (CDN-side identifiers for the Storage Account files) for the modified files -if found- or $false.
	#>
	
	#Calculates the treshold date in a Powershell compatible format (object).
    $Trigger_Date=(Get-Date).AddHours(-$Date_Treshold_Hours)

    #Emtpy list for URL Paths.
    $CDN_Content_URLPaths=@()
	
	#Identifies wether to target every container or just a specific one. This is a necessary evil to avoid looping through the containers in a SA when only one of them is required and can be passed as a filter parameter to Azure's function.
    if ($StorageAccount_Container_Name -in ("",$null,$false,"/","*")){#Mode 1: Wildcard, loop through all containers
        if ($Debug){Write-Warning "Trabajando en modo Wildcard (sobre todos los Containers) y exceoptuando los que empiezan con $."}
            #Gets the containers that the SA holds.
            $Containers=(Get-AzStorageContainer -Context $StorageAccount_Context).name 
            $Containers_Count=$Containers.count        
            #Loop through the list
            foreach ($Container in $Containers){
				#Filters out containers starting with character "$", which belong to native web container and can cause issues in API requests.
                if (-not($Container.StartsWith("$"))){
					#Fetches the blob files modified after treshold time within the container.
                    $CDN_Content_URLPaths_ThisContainer=Get-ContainerModifiedBlobs -StorageAccount_Context $StorageAccount_Context -StorageAccount_Container_Name $Container -Date_Treshold_Hours $Date_Treshold_Hours -Debug $Debug
                    #Verifies if changes have been found
                    if (-not($CDN_Content_URLPaths_ThisContainer -eq $False)){
                        #Concatenates the paths
                        $CDN_Content_URLPaths+=$CDN_Content_URLPaths_ThisContainer
                    } 
                }
            }
    }Else{ #Mode 2: Single container
		#Fetches the blob files modified after treshold time within the container.
        $CDN_Content_URLPaths=Get-ContainerModifiedBlobs -StorageAccount_Context $StorageAccount_Context -StorageAccount_Container_Name $StorageAccount_Container_Name -Date_Treshold_Hours $Date_Treshold_Hours -Debug $Debug
    }

    #Verifies if no changes have been found and -in that case- it turns the return value into $false.
    if ($CDN_Content_URLPaths.count -eq 0){$CDN_Content_URLPaths=$False}

    Return $CDN_Content_URLPaths
}

function Send-Automacc_Email($Body,$Subject){
	<#
		Sends a email via SMTP, using globally defined parameters and authentication.
		-Parameters:
			$Body: Message body.
			$Subject: Message subject.
		-Outputs: None
	#>
	
    #Fetches a credential stored within Automation Account
    $Credential=Get-AutomationPSCredential -Name $AC_VAR_Email_Credential

    #Message parameters fetched from Automation Account variables
    $To= Get-AutomationVariable -Name $AC_VAR_Email_Recipient
	$From = Get-AutomationVariable -Name $AC_VAR_Email_Sender
	$SMTP_Server = Get-AutomationVariable -Name $AC_VAR_Email_Server

    #Output to register email action in STDOUT
    Write-Warning "Executing command:"
	Write-Warning "Send-MailMessage -From $From -to $To -Body $Body -Subject $Subject -SmtpServer $SMTP_Server -Credential $Credential -UseSsl"

    #Sends the email
	Send-MailMessage -From $From -to $To -Body $Body -Subject $Subject -SmtpServer $SMTP_Server -Credential $Credential -UseSsl
}

function Main ($StorageAccount,$CDNProfile){
	<#
		Performs the main tasks within the script. It does so by authenticating to Azure ARM, connecting to both Storage Account (backend) and CDN, then fetching those files that
		have been modified within a treshold time window and purges them from the CDN's cache.
	
		-Parameters:
			$StorageAccount: A hashtable object containing SA properties "Name", "ResourceGroup", "Subscription" and "Container".
			$CDNProfile: A hashtable object containing CDN properties "Name", "ResourceGroup", "Subscription" and "EndpointName".
		-Output:
			Boolean value reflecting success or failure ($true or $false)
	#>
    $Success=$false
	
	#Authentication via System Managed Identity 
    Disable-AzContextAutosave -Scope Process #Disable context inheritance
    $AzureContext = (Connect-AzAccount -Identity).context #Login and save context
    $AzureContext = Set-AzContext -SubscriptionName $StorageAccount["Subscription"] -DefaultProfile $AzureContext #Select context
	
	#Creates a context object for the Storage Account connection
    $StorageAccount_Context=New-AzStorageContext -StorageAccountName $StorageAccount["Name"]
	
	#Fetches a list of URL Paths (CDN property for SA blob files) for the files that have been modified within the treshold window.
    $CDN_Content_URLPaths=Get-StorageAccountModifiedBlobs -StorageAccount_Context $StorageAccount_Context -StorageAccount_Container_Name $StorageAccount["Container"] -Date_Treshold_Hours $Date_Treshold_Hours -Debug $Debug

    #Purges the CDN content, limited to only the files that have been modified
    if (-not($CDN_Content_URLPaths -eq $False)){ #If modifications have been found
		if ($Debug) { Write-Warning "Working with CDN profile '$CDN_Name' and endpoint '$CDN_EndpointName'." }
		
        $CDN_Content_URLPaths_Count=$CDN_Content_URLPaths.count
        Write-Warning "Purging $CDN_Content_URLPaths_Count files on the CDN profile '$CDN_Name'..."
		$Error_Count_Lastest = $Error.count
		
		#Purges the file list within the CDN, using their URL Paths
		Unpublish-AzCdnEndpointContent -ResourceGroupName $CDNProfile["ResourceGroup"] -ProfileName $CDNProfile["Name"] -EndpointName $CDNProfile["EndpointName"] -PurgeContent $CDN_Content_URLPaths
		
        if ($Debug){
            $CDNProfile_Name=$CDNProfile["Name"]
            $CDNProfile_RG=$CDNProfile["ResourceGroup"]
            $CDNProfile_EP=$CDNProfile["EndpointName"]
            $CDN_Content_URLPaths_CSV=""
            foreach ($i in $CDN_Content_URLPaths){$CDN_Content_URLPaths_CSV+=",$i"}
            Write-Warning "Unpublish-AzCdnEndpointContent -ResourceGroupName $CDNProfile_RG -ProfileName $CDNProfile_Name -EndpointName $CDNProfile_EP -PurgeContent $CDN_Content_URLPaths_CSV."
		}
		
		#Verifies if errors occurred
		if ($Error.count -gt $Error_Count_Lastest){
            Write-Error "Errors occurred when purging content on the CDN profile '$CDN_Name'."
			#Triggers an email with the set global parameters
			Send-Automacc_Email -Subject "Error when purging CDN content [AZ Automation Account]" -Body "Errors found when purging CDN content in profile $CDN_Name with a scheduled task. This could potentially affect the business, as CDN cache within certain regions can take up to 48hs to be upgraded automatically."
        }else{
            Write-Warning "Successful purge within CDN profile '$CDN_Name'."
            $Success=$True
        }
    }else{ #Si no se encontraron cambios
        Write-Warning "No changes found in CDN profile '$CDN_Name' backend; skipping purge."
        $Success=$True
    }

    Return $Success
}


#####Global Variables####
###########################
#Amount of treshold hours to watch for changes
$Date_Treshold_Hours=Get-AutomationVariable -Name "CDN-TriggeredPurge_Date_Treshold_Hours"
#Debug mode for extra verbosity
$Debug=Get-AutomationVariable -Name "CDN-TriggeredPurge_Debug"
#Storage Account (SA) parameters
$StorageAccount_Name=Get-AutomationVariable -Name "StorageAccount_Name"
$StorageAccount_ResourceGroup=Get-AutomationVariable -Name "StorageAccount_ResourceGroup"
$StorageAccount_Subscription = Get-AutomationVariable -Name "StorageAccount_Subscription"
#Name of the target container within the SA. If left empty or assigned '*', '/' or '$null', then the scope becomes every container in the SA.
$StorageAccount_Container_Name=Get-AutomationVariable -Name "StorageAccount_Container_Name"
#Hashtable object that stores all the information of the SA
$StorageAccount_InformationHashtable=@{"Name"=$StorageAccount_Name;"ResourceGroup"=$StorageAccount_ResourceGroup;"Subscription"=$StorageAccount_Subscription;"Container"=$StorageAccount_Container_Name}
#CDN Profile parameters
$CDN_Name=Get-AutomationVariable -Name "CDN_Name"
$CDN_ResourceGroup=Get-AutomationVariable -Name "CDN_ResourceGroup"
$CDN_Subscription=Get-AutomationVariable -Name "CDN_Subscription"
$CDN_EndpointName=Get-AutomationVariable -Name "CDN_EndpointName"
#Hashtable object that stores all the information of the CDN
$CDN_InformationHashtable = @{ "Name" = $CDN_Name; "ResourceGroup" = $CDN_ResourceGroup; "Subscription" = $CDN_Subscription; "EndpointName" = $CDN_EndpointName }
#Email parameters. Variable names to use when fetching the actual values from within Automation Accounts variables.
$AC_VAR_Email_Credential="Email_Credential"
$AC_VAR_Email_Recipient="Email_Recipient"
$AC_VAR_Email_Sender="Email_Sender"
$AC_VAR_Email_Server="Email_Server"
###########################
###########################

####Script init####
#####################
Main -StorageAccount $StorageAccount_InformationHashtable -CDNProfile $CDN_InformationHashtable
#####################
#####################

