
#Requires -Version 7.2
[CmdletBinding()]
param (
    [Parameter(Mandatory, ValueFromPipeline,
        HelpMessage="Enter path to existing directory, e.g.: C:\SourceDirectory")]
    [ValidateScript({Test-Path -Path $_ -PathType Container}, 
        ErrorMessage = "Provide valid path to existing directory, e.g.: C:\SourceDirectory")]
    [System.IO.DirectoryInfo]
    $SourceDirectory,

    [Parameter(Mandatory,
        HelpMessage="Enter valid directory path, e.g.: C:\TargetDirectory")]
    [ValidateScript({Test-Path -Path $_ -IsValid}, 
        ErrorMessage = "Provide valid directory path, e.g.: C:\TargetDirectory")]
    [System.IO.DirectoryInfo]
    $TargetDirectory,

    [Parameter(HelpMessage="Enter valid file path, e.g.: C:\Logs\Sync-File.log")]
    [PSDefaultValue(Help="`'Sync-Files.log`' in current directory")]
    [ValidateScript({Test-Path -Path $_ -IsValid}, 
        ErrorMessage = "Provide valid file path for log, e.g.: C:\Logs\Sync-File.log")]
    [System.IO.FileInfo]
    $LogsPath = "Sync-Files $(Get-Date -Format "yyyyMMddTHHmmss").log",

    [Parameter(HelpMessage="Provide PSSession object.")]
    [System.Management.Automation.Runspaces.PSSession]
    $RemoteHostSession
)


#region Functions
function Add-LogMessage {
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $LogMessage,

        [Parameter(Mandatory=$true)]
        [string]
        $LogFile,

        [switch]
        $IsError
    )

    # Add current local date time with time zone offset from UTC
    $LogMessage = "[$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")] $LogMessage";
    if ($IsError.IsPresent) 
    {
        $LogMessage | Tee-Object -FilePath "$LogFile" -Append | Write-Error;
    }
    else 
    {
        $LogMessage | Tee-Object -FilePath "$LogFile" -Append | Write-Host;
    }

<#
.SYNOPSIS
    Adds a log message.

.DESCRIPTION
    The Add-LogMessage function adds a message to the specified file and send it to the PS console output.

.EXAMPLE
    Add-LogMessage -LogMessage "A test log message.";

.EXAMPLE
    Add-LogMessage -LogMessage "A test error message." -IsError;
#>
}
$defAddLogMessage = ${function:Add-LogMessage}.ToString();
#endregion

if (-not (Test-Path -Path $LogsPath -PathType Leaf)) 
{
    try 
    {
        New-Item -Path $LogsPath -ItemType File -ErrorAction Stop | Out-Null;
        Add-LogMessage -LogMessage "Created log file: $LogsPath" -LogFile $LogsPath;
    }
    catch 
    {
        Add-LogMessage -LogMessage "Exception while creating log file: $LogsPath`n$($_.ToString())" -LogFile $LogsPath -IsError;
    }
}
$LogsPath = Get-ChildItem -Path $LogsPath | Select-Object -ExpandProperty FullName;

# Create target directory
if (-not (Test-Path -Path $TargetDirectory)) 
{
    New-Item -Path $TargetDirectory -ItemType Directory;
}

# Collect source directory information
$sourceFiles = New-Object -TypeName "System.Collections.ArrayList";
Get-ChildItem -Path $SourceDirectory -Recurse | ForEach-Object {
    Write-Verbose -Message "Get item info: $($_.FullName)";
    $myFile = [PSCustomObject]@{
        FileName = "";
        SubDirectory = "";
        FileHash = "";
    }

    # Get source directory structure
    if ($_.GetType().Name -eq 'DirectoryInfo') 
    {
        $targetDir = Join-Path -Path $TargetDirectory -ChildPath ($_.FullName.ToString()).TrimStart((Get-Item -Path $SourceDirectory).FullName);

        # Create absent directory in the target location
        if (-not (Test-Path -Path $targetDir -PathType Container)) 
        {
            try 
            {
                New-Item -Path $targetDir -ItemType Directory -ErrorAction Stop | Out-Null;
                Add-LogMessage -LogMessage "Created directory: $targetDir" -LogFile $LogsPath;   
            }
            catch 
            {
                Add-LogMessage -LogMessage "Exception while creating directory: $targetDir`n$($_.ToString())" -LogFile $LogsPath -IsError;
            }
        }

        # Add directory information
        $myFile.FileName = "";
        $myFile.SubDirectory = ($_.FullName.ToString()).TrimStart((Get-Item -Path $SourceDirectory).FullName);
        $myFile.FileHash = "";
    }
    # Add file information
    else 
    {
        $myFile.FileName = $_.Name;
        $myFile.SubDirectory = ($_.Directory.ToString()).TrimStart((Get-Item -Path $SourceDirectory).FullName);
        $myFile.FileHash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash;
    }

    Write-Verbose -Message "Adding item info:`n$myFile";
    $sourceFiles.Add($myFile) | Out-Null; 
};


# Collect target directory information 
$targetFiles = New-Object -TypeName "System.Collections.ArrayList";
Get-ChildItem -Path $TargetDirectory -Recurse | ForEach-Object {
    Write-Verbose -Message "Get item info: $($_.FullName)";
    $myFile = [PSCustomObject]@{
        FileName = "";
        SubDirectory = "";
        FileHash = "";
    }

    # Get target directory structure
    if ($_.GetType().Name -eq 'DirectoryInfo') 
    {
        $subDir = ($_.FullName.ToString()).TrimStart((Get-Item -Path $TargetDirectory).FullName);

        # Remove obsolete directories
        if ($subDir -notin $sourceFiles.SubDirectory)
        {
            Get-ChildItem -Path $_.FullName -Recurse | Select-Object -ExpandProperty FullName | ForEach-Object{
                Add-LogMessage -LogMessage "Item to be removed: $_" -LogFile $LogsPath;
            }
            
            try 
            {
                Remove-Item -Path "$($_.FullName)" -Recurse -Force;
                Add-LogMessage -LogMessage "Removed $($_.FullName)" -LogFile $LogsPath;   
            }
            catch 
            {
                Add-LogMessage -LogMessage "Exception while removing an item: $($_.FullName)`n$($_.ToString())" `
                    -LogFile $LogsPath -IsError;
            }
        }
        # Add directory information
        else 
        {
            $myFile.FileName = "";
            $myFile.SubDirectory = $subDir;
            $myFile.FileHash = "";
        }
    }
    # Collect file information
    else 
    {
        $myFile.FileName = $_.Name;
        $myFile.SubDirectory = ($_.Directory.ToString()).TrimStart((Get-Item -Path $TargetDirectory).FullName);
        $myFile.FileHash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash;
    }

    Write-Verbose -Message "Adding item info:`n$myFile";
    $targetFiles.Add($myFile) | Out-Null;
}


# Sync files
Compare-Object -ReferenceObject $sourceFiles -DifferenceObject $targetFiles -Property SubDirectory, FileName, FileHash -PassThru | 
    Where-Object {-not ([string]::IsNullOrEmpty($_.FileName))} |
    Foreach-Object -ThrottleLimit 5 -Parallel {
        ${function:Add-LogMessage} = $USING:defAddLogMessage;

        # Remove obsolete files
        if ($_.SideIndicator -eq '=>') 
        {
            $obsoleteFile = $(Join-Path -Path $USING:TargetDirectory -ChildPath $_.SubDirectory -AdditionalChildPath $_.FileName);
            try 
            {
                Remove-Item -Path $obsoleteFile -Force;
                Add-LogMessage -LogMessage "File removed: $obsoleteFile" -LogFile "$USING:LogsPath";
            }
            catch 
            {
                Add-LogMessage -LogMessage "Exception while removing an item: $obsoleteFile`n$($_.ToString())" `
                    -LogFile $USING:LogsPath -IsError;
            }   
        }

        # Copy absent files or files with different hash
        if ($_.SideIndicator -eq '<=') 
        {
            $fileSubDir = Join-Path -Path $USING:TargetDirectory -ChildPath $_.SubDirectory;
            $filePath = Join-Path -Path $USING:SourceDirectory -ChildPath $_.SubDirectory -AdditionalChildPath $_.FileName;
            
            try 
            {
                Copy-Item -Path $filePath -Destination $fileSubDir -Force;
                Add-LogMessage -LogMessage "Copied item  $fileSubDir" -LogFile "$USING:LogsPath";
            }
            catch 
            {
                Add-LogMessage -LogMessage "Exception while copying an item:`n$filePath`nto $fileSubDir" `
                    -LogFile $USING:LogsPath -IsError;
            }
        }
}

<#PSScriptInfo

.VERSION 1.0.0

.GUID 8edd7619-84b3-4839-9551-0c7f41e269cf

.AUTHOR yevhenii.bondar@gmail.com

.COMPANYNAME yevhenii.bondar

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI https://github.com/Yevhenii-B/Sync-Directory

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 The script synchronizes two folders: source and replica.
    The script maintains a full, identical copy of source folder at replica folder using Powershell.
    
    Synchronization is one-way.
    File creation/copying/removal operations are logged to a file and to the console output.
    Folder paths and log file path are provided using the command line arguments. 

.PARAMETER SourceDirectory
    The path to the local existing directory which will be used as source for replication.

.PARAMETER TargetDirectory
    The valid path to the local directory which will be used as target for replication.

.PARAMETER LogsPath
    The valid path for the log file, e.g.: C:\Logs\Sync-File.log
    The parameter is optional. By default, the file will be created in current directory with following format:
    "Sync-Files yyyyMMddTHHmmss.log"

.EXAMPLE
    C:\PS>.\Sync-Directory.ps1 -SourceDirectory C:\SyncDataSource -TargetDirectory C:\SyncDataTarget

.EXAMPLE
    C:\PS>.\Sync-Directory.ps1 -SourceDirectory C:\SyncDataSource -TargetDirectory C:\SyncDataTarget -LogsPath C:\sync-dir.log -Verbose
#> 