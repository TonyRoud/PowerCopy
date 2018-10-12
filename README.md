# PowerCopy

This project contains scripts that combine the power of PowerShell & Robocopy

The purpose of the project was to facilitate data re-synchronisation between DFS nodes of an OpenText cluster which experienced file synchronisation issues due to a failure of DFS replication.

## Getting Started

```PowerShell
$Src               = 'C:\test\src\'
$Dst               = 'C:\test\dst\'
$Logfile           = "copylog.txt"
$MissingFileReport = "C:\test\TestFile.txt"

# Main command with write mode set to disabled
Copy-MissingDfSData -Src $Src -Dst $Dst -Logfile $logfile -MissingFileReport $MissingFileReport -WriteFlag:$true -verbose
```