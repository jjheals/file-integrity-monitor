Write-Host @"

What would you like to do?
A) Collect new baseline
B) Begin monitoring files with a saved baseline

"@

$response = Read-Host -Prompt "Please enter 'A' or 'B'"
Write-Host ""

Function Calculate-File-Hash($filepath) {
    $filehash = Get-FileHash -Path $filepath -Algorithm SHA512 
    return $filehash
}

Function Choose-Folder($choice){
    $thisFolder = ""
    $thisFolder = Read-Host -Prompt "What is the name of the folder in the current directory you want to $($choice)?"
    return $thisFolder
}
Function Check-Folder-Exists-In-Current-Directory($name) {
    return Test-Path -Path .\$($name)
}

if ($response -eq "A".ToUpper()) {
    Write-Host "Please enter the name of the folder you would like to create a baseline of: "
    $folderName = Choose-Folder("make a baseline of")

    # Make sure that folder exists
    while (-Not (Check-Folder-Exists-In-Current-Directory($folderName))) {
        Write-Host "That folder does not exist in the current directory. Please choose a different folder: "
        $folderName = "$(Read-Host)"
    }

    # Tell user process is starting 
    Write-Host "Creating new baseline for $($folderName) in the current directory"

    $baselineFileName = "$($folderName)-baseline.txt"

    # Delete baseline.txt if it already exists for that folder 
    if (Test-Path -Path .\baselines\$($baselineFileName)) { 
        Remove-Item -Path .\baselines\$($baselineFileName)
    }
    New-Item -Path .\baselines\$($baselineFileName)

    # Collect all files in target folder
    $files = Get-ChildItem -Path .\$($folderName)

    # For file, calculate the hash, and write to baseline.txt
    foreach ($f in $files) { 
        $hash = Calculate-File-Hash $f.FullName 
        "$($hash.Path)|$($hash.Hash)" | Out-File -FilePath .\baselines\$($baselineFileName) -Append
    }
}

elseif ($response -eq "B".ToUpper()) {

    $fileHashDictionary = @{}

    # Ask user what folder to monitor, check that a baseline already exists 
    $monitorFolder = Choose-Folder("monitor")

    # Check if folder exists
    while (-Not (Check-Folder-Exists-In-Current-Directory($monitorFolder))) {
         Write-Host "That folder does not exist in the current directory. Please choose a different folder: "
         $monitorFolder = "$(Read-Host)"
    }

    # Check if baseline exists
    if (-Not (Test-Path ".\baselines\$($monitorFolder)-baseline.txt")) {
        Write-Host "There is no existing baseline for $($monitorFolder)."
        $createBaseline? = Read-Host -Prompt "Do you want to create a new baseline? [Y / N (quit program)]"

        if ($createBaseline? -eq "Y".ToUpper()) {
            New-Item -Path ".\baselines\$($monitorFolder)-baseline.txt"
            Write-Host "Created new baseline for $($monitorFolder)."
        }
        elseif ($createBaseline? -eq "N".ToUpper()) {
            Exit
        }
    }


    # Load file|hash from baseline.txt and store them in a dictionary 
    $filePathsAndHashes = Get-Content -Path .\baselines\"$($monitorFolder)-baseline.txt"

    foreach ($f in $filePathsAndHashes) {
        $fileHashDictionary.add($f.Split("|")[0],$f.Split("|")[1])
    } 

    # Begin (continuously) monitoring files with saved baseline
    while ($true) {
        Start-Sleep -Seconds 1
        Write-Host "Checking if files match..."

        $files = Get-ChildItem -Path .\$monitorFolder

        # For file, calculate the hash, and write to baseline.txt
        foreach ($f in $files) { 
            $hash = Calculate-File-Hash $f.FullName 
            #"$($hash.Path)|$($hash.Hash)" | Out-File -FilePath .\baseline.txt -Append

            # Notify if a new file has been created
            if ($fileHashDictionary[$hash.Path] -eq $null) {
                # A new file has been created!
                Write-Host "$($hash.Path) has been created!" -ForegroundColor Green
            } 
            else { 
                # Notify if a new file has been changed
                if ($fileHashDictionary[$hash.Path] -eq $hash.Hash) {
                    # The file has not been changed
                }
                else {
                    # The file has been compromised! Notify the user
                    Write-Host "$($hash.Path) has changed!" -ForegroundColor Yellow
                }
            }
        }

        foreach ($key in $fileHashDictionary.Keys) {
            if (-Not (Test-Path -Path $key)) {
                # One of the baseline files must have been deleted, notify the user
                Write-Host "$($key) has been deleted!" -ForegroundColor DarkRed
            }
        }
    }
}


# Let the user choose which folder to monitor
# Add error checking 
#     - If user responses with not A or B / Y or N when prompted (responds with something that is not an option)
#     - Find a way to notfiy user rather than printing to the screen (email? Twilio API send a text?)
