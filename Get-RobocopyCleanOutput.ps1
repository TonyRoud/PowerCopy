<#
    Function to gather filesystem information using Robocopy
    This is specifically targeted at '.dat' files used by Opentext
#>
function Get-CleanRobocopyOutput {
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][string]$SourceDirectory,
        [Parameter(Mandatory=$true)][string]$Outputfilepath
    )

    Write-Verbose "Beginning robocopy file list operation against $SourceDirectory"
    Write-Verbose "This may take some time..."

    Start-Sleep -Seconds 3

    $robolog = "robocopy_rawfilereport_" + (get-date -f HHmmss) + ".txt"
    $robologfullpath = join-path -Path $Outputfilepath -ChildPath $robolog

    Write-Verbose "Running command: robocopy `'$SourceDirectory`' null /l /e /xd `'$SourceDirectory\DFSRPrivate`' /ns /nc /ndl /fp /tee /log:$robologfullpath"
    robocopy $SourceDirectory 'X:\null' /l /e /xd "$SourceDirectory\DFSRPrivate" /ns /nc /ndl /fp /log:$robologfullpath

    Write-Verbose "Robocopy operation succeeded."
    Write-Verbose "Now processing robocopy log..."

    $outputFile = "robocopy_processed_" + (get-date -f HHmmss) + ".txt"
    $outputfilefullname = Join-path -Path $Outputfilepath -ChildPath $outputFile

    [regex]$regex = '\d{4}\\\d{3}\\\d*.\.dat'

    Get-Content $robologfullpath -ReadCount 1024 | ForEach-Object {

        ($_ | select-string $regex -AllMatches).Matches.Value | add-content -path $outputfilefullname

    }
    Write-Verbose "Success: Raw robocopy log saved to $robologfullpath"
    Write-Verbose "Processed file list saved to $outputfilefullname"
}