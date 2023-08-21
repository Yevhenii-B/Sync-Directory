# Sync-Directory

The script synchronizes two folders on localhost: source and replica.
The script maintains a full, identical copy of source folder at replica folder using Powershell.

Synchronization is one-way.
File creation/copying/removal operations are logged to a file and to the console output.
Folder paths and log file path are provided using the command line arguments. 

To get detailed script info, run:
```
Get-Help .\Sync-Directory.ps1 -Full 
```
