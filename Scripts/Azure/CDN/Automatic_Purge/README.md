# Azure CDN automatic cache purge
Authored by Juan Fox - 2022.
MIT License (view GIT root's LICENSE file).

## About
This **Powershell** script automates the *cache* purge on an **Azure CDN** Profile with a **Storage Account** blob backend, which is known to cause issues in certain regions (due to *cache* living up to 48hs).
		
To do so, it *queries the backend Storage Account (SA) for files that have been modified within a set treshold time window and then connects to the CDN profile to perform the cache purge on those particular files*.

It is meant to be run on a schedule from within an **Azure Automation Account** task (AACC), so scheduling is outside it's scope of responsibilities. It also does not log or persist to any external component, other than AACC's console.
## Usage
Create an AACC *runbook* and add the contents of this file. Make sure to use a supported **Powershell** version (avoid betas) and include the **AZ Powershell module**.
Also create the necessary variables/credentials with your values -names do need to match or be updated within the script- and give the AACC *System Managed Identity* proper permissions on both the CDN and the SA.
Test the script:

 1. Upload a file (ideally a simple HTML) to the SA
 2. Access the file through the CDN URL (NOT the SA URL directly!), which will cache the file
 3. Perform a change in the SA file that would be visible in a web browser
 4. Access the file again (through the CDN URL) and see that you are viewing the *previous* version
 5. Run the script -with debug on- from the AACC and watch is console outputs
 6. The outputs should indicate that changes have been found within a file in the container
 7. Access the file again (through the CDN URL) and see that you are viewing the *latest* version

Now you can schedule this runbook as you please.

## Requirements
This script is meant to be run within an **Azure Automation Account** with *System Managed Identity* authentication to **ARM** and proper authorization on both the **CDN** profile (write is necessary) and the **Storage Account** (read is enough), some AACC set variables and lastly valid email permissions and parameters (addresses, credentials and a public internet server with SSL).

## Dependancies

 - **AZ Powershell module**: https://docs.microsoft.com/en-us/powershell/azure/https://docs.microsoft.com/en-us/powershell/azure/

## Platforms

 - Windows Powershell 5.1.
 - Powershell 7, provided the **AZ Powershell module** is mantained to support it.
