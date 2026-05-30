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
# OBJECTIVE 2 - Plant suspicious executable memory artifact
# Scenario: Attacker used a helper process that appears related to svchost
# ==============================================================================

Write-Log "Planting Objective 2 artifacts: suspicious executable memory."

$CodePath = "C:\Windows\Temp\svchost-helper.cs"
$ExePath  = "C:\Windows\Temp\svchost-helper.exe"

$Code = @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public class SvchostHelper
{
    [DllImport("kernel32.dll")]
    static extern IntPtr VirtualAlloc(
        IntPtr lpAddress,
        UIntPtr dwSize,
        uint flAllocationType,
        uint flProtect
    );

    public static void Main()
    {
        byte[] buffer = new byte[4096];

        for (int i = 0; i < buffer.Length; i++)
        {
            buffer[i] = 0x90;
        }

        byte[] marker = Encoding.ASCII.GetBytes("VOLATILITY_LAB_INJECTED_CODE_MARKER");
        Array.Copy(marker, buffer, marker.Length);

        IntPtr memory = VirtualAlloc(
            IntPtr.Zero,
            (UIntPtr)buffer.Length,
            0x3000,
            0x40
        );

        Marshal.Copy(buffer, 0, memory, buffer.Length);

        while (true)
        {
            Thread.Sleep(60000);
        }
    }
}
"@

Set-Content -Path $CodePath -Value $Code -Force

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
`$code = Get-Content '$CodePath' -Raw
Add-Type -TypeDefinition `$code -OutputAssembly '$ExePath' -OutputType ConsoleApplication
"

Start-Process $ExePath -WindowStyle Hidden

schtasks /Create `
    /TN "SvchostHelper" `
    /TR $ExePath `
    /SC ONSTART `
    /RU SYSTEM `
    /RL HIGHEST `
    /F | Out-Null

Write-Log "Objective 2 svchost-helper artifact planted."

# Step 1 - List processes
#python .\vol.py -f ..\Evidence\MEMORY.dmp windows.pslist

# Interesting svc-host-helper.exe process should be visible with injected code marker in memory
#Then look for the windows.cmdline and we can see it running out of \Temp

#Then you use windows.malware.malfind and you can see the voltatilty marker in memory in the ASCII section of the injected memory


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

# ==============================================================================
# OBJECTIVE 3 - Plant command history artifacts
# Scenario: Attacker ran reconnaissance and lateral movement commands
# ==============================================================================
Write-Log "Planting Objective 3 artifacts: command history and attack timeline."

$TimelinePath = "C:\Users\Public\Desktop\LAB_FILES\Evidence\attacker-command-timeline.txt"

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

# Write a timeline file for learner validation and grading.
$TimelineLines = @()
$BaseTime = Get-Date

for ($i = 0; $i -lt $AttackerCommands.Count; $i++) {
    $EventTime = $BaseTime.AddMinutes($i)
    $TimelineLines += "$($EventTime.ToString('yyyy-MM-dd HH:mm:ss')) - $($AttackerCommands[$i])"
}

$TimelineLines | Set-Content -Path $TimelinePath -Force

# Execute each command once so the system state matches the story.
foreach ($cmd in $AttackerCommands) {
    cmd /c $cmd 2>&1 | Out-Null
}

# Leave a persistent process with the full attack sequence in memory.
$AttackSequence = $AttackerCommands -join " ; "

Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-Command",
    "`$attack_timeline = '$AttackSequence'; while (`$true) { Start-Sleep 60 }"
)

Write-Log "Objective 3 command history and timeline artifacts planted."

# Step 1 - Save process command lines for review
#python .\vol.py -f ..\Evidence\MEMORY.dmp windows.cmdline > ..\Evidence\cmdline-results.txt

# Step 2 - Search for attacker timeline artifacts
#findstr /i "attack_timeline whoami netstat tasklist svc_backup" ..\Evidence\cmdline-results.txt

# Step 3 - Cross-reference suspicious PowerShell processes

#python .\vol.py -f ..\Evidence\MEMORY.dmp windows.pslist > ..\Evidence\pslist-results.txt


# Step 4 - Open saved results for timeline reconstruction
#notepad ..\Evidence\cmdline-results.txt
#notepad ..\Evidence\pslist-results.txt