$HelpInfo = @{
    Path = ".\Sync-Directory.ps1"
    Version = "1.0.0"
    Author = "yevhenii.bondar@gmail.com"
    CompanyName = "yevhenii.bondar"
    Description = "The script synchronizes two folders: source and replica.
    The script maintains a full, identical copy of source folder at replica folder using Powershell.
    
    Synchronization is one-way.
    File creation/copying/removal operations are logged to a file and to the console output.
    Folder paths and log file path are provided using the command line arguments."
    Guid = New-Guid
    ProjectUri = "https://github.com/Yevhenii-B/Sync-Directory"
    Force = $true
    }

Update-ScriptFileInfo @HelpInfo -PassThru;