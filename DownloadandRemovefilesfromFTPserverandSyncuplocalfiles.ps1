# Cumstom field as below,
#$filesperfolder: The number of files to be placed for each folder 
#$localPath:The path of files to be placed
#$remotePath:FTP path
#$sessionOptions:Authentication for FTP
#$filesize : the file size gt $filesize will be removed
param (
    $filesperfolder = ,
    $localPath = "",
    $remotePath = "",
    $filesize = 3kb,
    $i = 0,
    $folderNum = 1
)

#Creat log 
$Logfile = "$localPath\$(gc env:computername).log"
$currenttime = Get-Date

#Set up log function
Function LogWrite
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
} 

$Npath = "$localPath.\$((Get-Date).ToString('yyyy-MM-dd'))"
#Create folder per date
if(Test-Path $Npath)
{
LogWrite "$($currenttime),$Npath is exist!"
exit 1
}
else
{
New-Item -ItemType Directory -Path "$localPath.\$((Get-Date).ToString('yyyy-MM-dd'))"
}

$tempFolder = "$Npath.\cache"
#Create temp folder
if(Test-Path $tempFolder)
{
LogWrite "$($currenttime),Temp folder $tempFolder is exist!"
exit 1 }
else
{
New-Item -ItemType Directory -Path "$Npath.\cache"
}



#Set up function to move a certain number of files to the specified folder
Function SyncupFile
{
         LogWrite "$($currenttime),Start putting files to subfolder!"
         Get-ChildItem "$tempFolder\*.zip" -Recurse| % { 
                
                    if ($_.length -gt $filesize)
                    {
                    New-Item -Path ($Npath + "\" + $folderNum) -Type Directory -Force
                    Move-Item $_ ($Npath + "\" + $folderNum);
                    LogWrite "$($currenttime),$_ is moved to ($Npath + '\' + $folderNum)!"
                    $i++;
                    if ($i -eq $filesperfolder)
                    {
                        $folderNum++;
                        $i = 0 ;
                     }
                    }                
                    
                }
}

#main
try
{
    # Load WinSCP .NET assembly
    Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
 
    # Setup session options
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
    Protocol = [WinSCP.Protocol]::Sftp
    HostName = ""
    UserName = ""
    Password = ""
    SshHostKeyFingerprint = ""
    }

    $session = New-Object WinSCP.Session
    try
    {
        # Connect
        $session.Open($sessionOptions)

        #Set transfer mode
        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
        #Matches files larger than 
        #$transferOptions.FileMask = "*>2K"
 
        # Synchronize files to local directory, collect results
        $synchronizationResult = $session.SynchronizeDirectories([WinSCP.SynchronizationMode]::Local, $tempFolder, $remotePath, $False)
       
     
        SyncupFile 
           
        

        #Remove temp folder
        Remove-Item -Path $tempFolder  -Recurse -Force 
        LogWrite "$($currenttime), Temp folder $tempFolder is removed!"
        
        #Remove empty date folder 
        $directoryInfo = Get-ChildItem $Npath | Measure-Object
        if($directoryInfo.count -eq 0)
        {
        Remove-Item -Path $Npath  -Recurse -Force
        LogWrite "$($currenttime),$Npath is removed as empty!"
        }
 
        # Iterate over every download
        foreach ($download in $synchronizationResult.Downloads)
        {
            # Success or error?
            if ($download.Error -eq $Null)
            {
                LogWrite "$($currenttime),Download of $($download.FileName) succeeded, removing from source"

                # Download succeeded, remove file from source
                $removalResult =$session.RemoveFiles($session.EscapeFileMask("$remotePath"))
                 
                if ($removalResult.IsSuccess)
                {
                    LogWrite "$($currenttime),Removing of file $($download.FileName) succeeded"
                }
                else
                {
                    LogWrite "$($currenttime),Removing of file $($download.FileName) failed"
                }

                #Re-create parent folder on remote
                $createResult = $session.CreateDirectory("$remotePath")
                
                if ($createResult.Error -eq $Null)
                {
                    LogWrite "$($currenttime),Creating of folder $($remotePath) succeeded"
                }
               else
                {
                    LogWrite "$($currenttime),Creating of folder $($remotePath) failed"
                }
                
            }

          else
            {
                LogWrite (
                    "$($currenttime),Download of $($download.FileName) failed: $($download.Error.Message)")
            }
        }
    }
    finally
    {
        # Disconnect, clean up
        $session.Dispose()
    }
 
    exit 0
}
catch
{
    LogWrite "$($currenttime),Error: $($_.Exception.Message)"
    exit 1
}

