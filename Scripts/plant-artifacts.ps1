param (
    [string]$LogFile = "C:\Users\Public\Desktop\volatility-lab-setup.log"
)

$DesktopRoot = "C:\Users\Public\Desktop"
$LabRoot     = "$DesktopRoot\LAB_FILES"
$EvidenceRoot = "$LabRoot\Evidence"

function Write-Log {
    param ([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Tee-Object -FilePath $LogFile -Append
}

# ==============================================================================
# OBJECTIVE 1 - Plant credential artifacts
# Scenario: Attacker created a backdoor account and exposed credentials
# ==============================================================================
Write-Log "Planting Objective 1 artifacts: credentials."

# Create a backdoor service account
New-LocalUser -Name "svc_backup" -Password (ConvertTo-SecureString "Password123!" -AsPlainText -Force) -PasswordNeverExpires $true -ErrorAction SilentlyContinue
Add-LocalGroupMember -Group "Administrators" -Member "svc_backup" -ErrorAction SilentlyContinue

# Run a persistent process with credentials visible in command line
Start-Process powershell -ArgumentList "-WindowStyle Hidden -Command `"while(`$true){ net use \\fileserver\share /user:svc_backup Password123! 2>`$null; Start-Sleep 300 }`""

Write-Log "Objective 1 artifacts planted."

# Learner commands for Objective 1:
# cd C:\Users\Public\Desktop\LAB_FILES\volatility3
#
# Step 1 - List processes to find suspicious PowerShell
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.pslist
#
# Step 2 - Check command line of all processes for exposed credentials
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.cmdline


# ==============================================================================
# OBJECTIVE 2 - Plant suspicious process artifacts
# Scenario: Attacker masqueraded a malicious process as a legitimate svchost
# ==============================================================================
Write-Log "Planting Objective 2 artifacts: suspicious processes."

# Copy powershell.exe to Temp and rename it svchost.exe to simulate masquerading
Copy-Item "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\Windows\Temp\svchost.exe" -Force

# Launch the fake svchost so it stays alive in memory
Start-Process "C:\Windows\Temp\svchost.exe" -ArgumentList "-WindowStyle Hidden -Command `"while(`$true){Start-Sleep 60}`""

Write-Log "Objective 2 artifacts planted."

# Learner commands for Objective 2:
# cd C:\Users\Public\Desktop\LAB_FILES\volatility3
#
# Step 1 - List all processes and spot the fake svchost
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.pslist
#
# Step 2 - Check full path of each process to confirm masquerading
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.cmdline
#
# Step 3 - Scan for injected or malicious memory segments
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.malfind
#
# Step 4 - Check loaded DLLs for a suspicious PID (replace <PID> with PID from pslist)
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.dlllist --pid <PID>


# ==============================================================================
# OBJECTIVE 3 - Plant command history artifacts
# Scenario: Attacker ran reconnaissance and lateral movement commands
# ==============================================================================
Write-Log "Planting Objective 3 artifacts: command history."

# Simulate attacker recon and lateral movement command sequence
$AttackerCommands = @(
    "whoami /priv",
    "net user",
    "net localgroup administrators",
    "net user administrator /active:yes",
    "net localgroup administrators svc_backup /add",
    "ipconfig /all",
    "netstat -ano",
    "dir C:\Users\Administrator\Documents",
    "dir C:\Users\Public\Desktop",
    "tasklist /svc"
)

foreach ($cmd in $AttackerCommands) {
    cmd /c $cmd 2>&1 | Out-Null
}

# Leave a persistent process so cmdline shows attacker activity
Start-Process powershell -ArgumentList "-WindowStyle Hidden -Command `"while(`$true){ Start-Sleep 60 }`"" 

Write-Log "Objective 3 artifacts planted."

# Learner commands for Objective 3:
# cd C:\Users\Public\Desktop\LAB_FILES\volatility3
#
# Step 1 - Extract full command line for all running processes
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.cmdline
#
# Step 2 - Cross reference suspicious PIDs back to process list
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.pslist

Write-Log "Artifact planting complete."

