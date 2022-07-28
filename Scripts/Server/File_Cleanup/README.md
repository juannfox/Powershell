# File Cleanup
Authored by Juan Fox - 2022.
MIT License (view GIT root's LICENSE file).

## About
This **Powershell** script automates the cleanup of files modificated within a treshold time window, wether they are log files, backup files or just any file that can be tracked through it's extension.
		
To do so, it queries a target path for files matching the extension and modification date, performing a one-by-one deletion, excluding those that are whitelisted.

It is meant to be run on a schedule either by Task Scheduler (Windows) or Crontab (Linux).
## Usage
### Windows

    .\Scripts\Server\File_Cleanup.ps1 -Treshold_Days 7 -Target_Path .\TestDir `
     -Target_Extension .log -Exclude "exclusion1.log,exclusion2.log"

### Linux

    pwsh
    ./Scripts/Server/File_Cleanup.ps1 -Treshold_Days 7 -Target_Path TestDir `
     -Target_Extension .log -Exclude "exclusion1.log,exclusion2.log"

## Requirements
You might need to enable **Powershell** script execution within your **Windows** system (as admin):

	Set-ExecutionPolicy Bypass

## Dependancies
None

## Platforms

 - **Powershell 7** in both *Windows* and *Linux*
