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
# OBJECTIVE 1 - Plant credential artifacts in registry
# Scenario: Attacker stored credentials in registry during intrusion
# ==============================================================================
Write-Log "Planting Objective 1 artifacts: credentials in registry."

# Create a backdoor service account
New-LocalUser -Name "svc_backup" -Password (ConvertTo-SecureString "Password123!" -AsPlainText -Force) -PasswordNeverExpires $true -ErrorAction SilentlyContinue
Add-LocalGroupMember -Group "Administrators" -Member "svc_backup" -ErrorAction SilentlyContinue

# Store plaintext credentials in registry to simulate attacker staging
reg add "HKLM\SOFTWARE\LabConfig" -v "AdminPassword" -t REG_SZ -d "Password123!" -f | Out-Null
reg add "HKLM\SOFTWARE\LabConfig" -v "ServiceAccount" -t REG_SZ -d "svc_backup" -f | Out-Null
reg add "HKLM\SOFTWARE\LabConfig" -v "Notes" -t REG_SZ -d "Backup admin account - do not remove" -f | Out-Null

Write-Log "Objective 1 artifacts planted."

# Learner commands for Objective 1:
# cd C:\Users\Public\Desktop\LAB_FILES\volatility3
#
# Step 1 - List all registry hives loaded in memory
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.registry.hivelist
#
# Step 2 - Extract the planted credential key
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.registry.printkey --key "SOFTWARE\LabConfig"
#
# Step 3 - Browse user account hive for account information
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.registry.printkey --key "SAM\Domains\Account\Users\Names"


# ==============================================================================
# OBJECTIVE 2 - Plant suspicious process and code injection artifacts
# Scenario: Attacker ran PowerShell and masqueraded as a legitimate process
# ==============================================================================
Write-Log "Planting Objective 2 artifacts: suspicious processes."

# Drop a fake svchost in Temp to simulate process masquerading (classic attacker IOC)
Copy-Item "C:\Windows\System32\notepad.exe" "C:\Windows\Temp\svchost.exe" -Force

# Start the masquerading process so it shows in memory
Start-Process "C:\Windows\Temp\svchost.exe"

# Start a hidden PowerShell process to simulate attacker persistence
Start-Process powershell -ArgumentList "-WindowStyle Hidden -Command `"while(`$true){Start-Sleep 60}`""

Write-Log "Objective 2 artifacts planted."

# Learner commands for Objective 2:
# cd C:\Users\Public\Desktop\LAB_FILES\volatility3
#
# Step 1 - List all processes and look for anomalies
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.pslist
#
# Step 2 - View process tree to identify suspicious parent/child relationships
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.pstree
#
# Step 3 - Scan for injected or malicious memory segments
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.malfind
#
# Step 4 - List DLLs for a suspicious process (replace <PID> with PID from pslist)
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
    "reg query HKLM\SOFTWARE\LabConfig",
    "dir C:\Users\Administrator\Documents",
    "dir C:\Users\Public\Desktop",
    "tasklist /svc",
    "powershell -WindowStyle Hidden -Command IEX('whoami')"
)

foreach ($cmd in $AttackerCommands) {
    cmd /c $cmd 2>&1 | Out-Null
}

Write-Log "Objective 3 artifacts planted."

# Learner commands for Objective 3:
# cd C:\Users\Public\Desktop\LAB_FILES\volatility3
#
# Step 1 - Extract command-line arguments for all running processes
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.cmdline
#
# Step 2 - Scan for console command history artifacts in memory
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.cmdscan
#
# Step 3 - Correlate commands back to process list for timeline
# python .\vol.py -f ..\Evidence\MEMORY.dmp windows.pslist


Write-Log "Artifact planting complete."