# Log output to specified file for audit purposes
Function LogWrite {
    Param ([Parameter(Mandatory=$true,Position=1)][String]$logstring)
    $timestamp = Get-Date -f s
    Write-Verbose $logstring
    $logstring = "[$timestamp] " + $logstring
    Add-content -Path $Logfile -value $logstring
}
# Main copy function to create directory and copy file
function Copy-MissingDfSData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param(
        [Parameter(Mandatory=$true,Position=1)][String]$Src,
        [Parameter(Mandatory=$true,Position=2)][String]$Dst,
        [Parameter(Mandatory=$true)][String]$MissingFileReport,
        [Parameter(Mandatory=$true)][String]$Logfile,
        [Parameter(Mandatory=$true,HelpMessage="Set WriteFlag to `'True`' to enable write mode")][Bool]$WriteFlag
    )
    New-Item $logfile -Force -ItemType File
    # Set error and success variables
    $FilesCopied  = 0
    $FilesSkipped = 0
    $CopyErrors   = 0

    # Gather list of files to copy (using readcount to prevent memory exhaustion)
    try {

        LogWrite "Initialising input: Reading missing file list"
        Get-Item $MissingFileReport -ErrorAction Stop

        $Filelist = Get-Content $MissingFileReport -ReadCount 1024

        Foreach ($file in $filelist) {
            $RcSrc = Join-Path $Src -ChildPath $file
            $RcDst = Join-Path $Dst -ChildPath $file
            $CopyResult = Start-DfsFileCopyOperation -RcSrc $RcSrc -RcDst $RcDst -WriteFlag $WriteFlag
            if ($CopyResult -eq 3 ){ $CopyErrors += 1 }
            elseif ($CopyResult -eq 2) { $FilesSkipped += 1 }
            elseif ($CopyResult -eq 1 ){ $FilesCopied += 1 }
        }
    }
    Catch {
        Write-Error "Unable to locate missing file report $MissingFileReport`. Exiting operation."
        LogWrite "Warning: unable to locate missing file report $MissingFileReport`. Exiting operation."
    }
    Logwrite "Summary: $FilesCopied files copied successfully, $FilesSkipped files skipped, $CopyErrors failed to copy."
}
# Individual File Copy function
Function Start-DfsFileCopyOperation {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,Position=1)][String]$RcSrc,
        [Parameter(Mandatory=$true,Position=2)][String]$RcDst,
        [Parameter(Mandatory=$true,HelpMessage="Set WriteFlag to `'True`' to enable write mode")][Bool]$WriteFlag
    )
    $CopyResult = 3
    $SourceFile = Try {
        Get-Item $RcSrc -ErrorAction STOP -Verbose:$VerbosePreference
        LogWrite "Fetching item $RcSrc"
    }
    Catch {
        LogWrite "Warning: Unable to locate source file `"$RcSrc`". Double check file still exists on source."
    }
    LogWrite "Checking if $RcDst exists already"
    $DestFile = Get-Item $RcDst -ErrorAction Ignore -Verbose:$VerbosePreference

    if($SourceFile){
        LogWrite "$SourceFile found on source"
        $NewPath = (Split-Path -Path $RcDst -Parent)
        $NewFile = (Split-Path -Path $RcDst -Leaf)

        if (!$DestFile){
            LogWrite "Confirmed file not present on target"
            if($WriteFlag){
            LogWrite "Write flag is enabled"
                if(Test-Path $NewPath) {
                    LogWrite "Directory `"$NewPath`" already exists, `"$NewFile`" will be copied to existing directory"

                }
                elseif(!(Test-Path $NewPath)){
                    LogWrite "Action: Write - `"$RcDst`" not found on target."
                    try {
                        LogWrite "Action: Write - Creating directory `"$NewPath\`""
                        New-Item -ItemType directory -Path $NewPath -Verbose:$VerbosePreference -ErrorAction STOP
                    }
                    Catch {
                        Write-Warning "Failed to create directory `"$NewPath\`" (May already exist). Attempting to copy file into existing directory..."
                        LogWrite "Warning: Failed to create directory `"$NewPath\`" (May already exist). Attempting to copy file into existing directory..."
                        LogWrite $_.exception.message
                    }

                }
                try {
                    LogWrite "Action: Write - Copying file `"$RcSrc`" to `"$RcDst`""
                    Copy-Item -Path $RcSrc -Destination $RcDst -Verbose:$VerbosePreference -ErrorAction STOP

                }
                Catch {
                    Write-Warning "Failed to Copy file `"$RcSrc`" to `"$RcDst`""
                    LogWrite "Warning: Failed to Copy file `"$RcSrc`" to `"$RcDst`""
                    LogWrite $_.exception.message
                }
                $finalcopyresult = Get-Item $RcDst -ErrorAction Ignore
                if ($finalcopyresult){
                    $CopyResult = 1
                    LogWrite "`"$RcSrc`" successfully copied to to `"$RcDst`""
                }
                elseif(!$finalcopyresult){
                    $CopyResult = 3
                    LogWrite "`"$RcSrc`" failed to copy to `"$RcDst`""
                }
            }
            Elseif(!$WriteFlag){
                if(Test-Path $NewPath -ErrorAction SilentlyContinue -Verbose:$VerbosePreference) {
                    Write-Warning "Directory `"$NewPath`" already exists, `"$NewFile`" will be copied to existing directory"
                    LogWrite "Warning: Directory `"$NewPath`" already exists, `"$NewFile`" will be copied to existing directory"
                }
                else { LogWrite "Action: Log - Directory `"$NewPath`" not found on target. In write mode directory will be created" }
                LogWrite "Action: Log - In write mode file `"$RcSrc`" will be copied to to `"$RcDst`""
                $CopyResult = 1
            }
        }
        Elseif($DestFile) {
            Write-Warning "File $RcDst already exists on destination, skipping..."
            LogWrite "Warning: File $RcDst already exists on destination, skipping..."
            $CopyResult = 2
        }
        else {
            LogWrite "Warning: Unkown error copying file `"$NewFile`""
            $CopyResult = 3
        }
    }
    $CopyResult
}