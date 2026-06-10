#Requires -Version 5.1
#Requires -RunAsAdministrator

param (
    [Parameter(HelpMessage = "Specify the action: 'Install' or 'Uninstall'. Defaults to 'Install'.")]
    [string]$Action,

    [Parameter(HelpMessage = "Product IDs for Office installation. Supports comma-separated multiple IDs (e.g., 'ProPlus2024Volume,VisioPro2024Volume,ProjectPro2024Volume'). Required if Action is 'Install'.")]
    [string]$ProductIds,

    [Parameter(HelpMessage = "Optional. Comma-separated list of App IDs to install (e.g., 'Word,Excel,PowerPoint'). If not specified, all apps for the ProductIds are installed.")]
    [string]$AppIds
)

# Environment variable fallback: parameters take precedence over env vars
if (-not $Action) {
    if ($env:Action) { $Action = $env:Action } else { $Action = "Install" }
}
if (-not $ProductIds) {
    if ($env:ProductIds) { $ProductIds = $env:ProductIds } else { $ProductIds = "O365ProPlusRetail" }
}
if (-not $AppIds) {
    if ($env:AppIds) { $AppIds = $env:AppIds } else { $AppIds = "Word,Excel,PowerPoint,Outlook" }
}
if ($Action -notin @("Install", "Uninstall")) {
    Write-Error "Invalid Action: '$Action'. Only 'Install' or 'Uninstall' is allowed."
    Exit 1
}

# Global settings
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms

# --- Administrative Privileges Check ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires administrator privileges. Attempting to restart as administrator..."
    if ($PSCommandPath) {
        # Script is a file on disk — re-launch as file with args
        $powershellArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($Action -ne "Install") { $powershellArgs += " -Action `"$Action`"" }
        if ($ProductIds) { $powershellArgs += " -ProductIds `"$ProductIds`"" }
        if ($AppIds) { $powershellArgs += " -AppIds `"$AppIds`"" }
        Start-Process powershell -Verb RunAs -ArgumentList $powershellArgs
    }
    else {
        # Script was loaded via irm|iex — re-launch with env vars
        $envArgs = "`$env:Action='$Action'; `$env:ProductIds='$ProductIds'; `$env:AppIds='$AppIds'; irm https://kms.akams.cn/install.ps1 | iex"
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -c $envArgs"
    }
    Exit
}

# --- Variables ---
$odtUrl = "https://officecdn.microsoft.com/pr/wsus/setup.exe"
$workDir = Join-Path -Path $env:TEMP -ChildPath "KMS_AKAMS_CN"
$odtPath = Join-Path -Path $workDir -ChildPath "setup.exe"
$configPath = Join-Path -Path $workDir -ChildPath "config.xml"
$logPath = Join-Path -Path $workDir -ChildPath "ODT-log.txt"

# --- Helper Functions ---
function Show-MessageBox {
    param (
        [string]$Text,
        [string]$Caption,
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    [System.Windows.Forms.MessageBox]::Show($Text, $Caption, $Buttons, $Icon) | Out-Null
}

function Log-Message {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet("Info", "Step", "Success", "Warning", "Error", "Title")]
        [string]$Level = "Info",
        [switch]$WithBlankLine
    )

    $color = "Gray"
    $prefix = ""

    switch ($Level) {
        "Step" { $color = "Cyan"; $prefix = "[*] " }
        "Info" { $color = "Yellow" }
        "Success" { $color = "Green"; $prefix = "[+] " }
        "Warning" { $color = "Yellow"; $prefix = "[-] " }
        "Error" { $color = "Red"; $prefix = "[-] " }
        "Title" { $color = "Magenta"; $prefix = "`n[*] " }
    }

    Write-Host "$prefix$Message" -ForegroundColor $color

    if ($WithBlankLine) {
        Write-Host ""
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logDir = Split-Path $logPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    "$timestamp - [$Level] $Message" | Out-File -FilePath $logPath -Append -Encoding UTF8 -ErrorAction SilentlyContinue
}

# Product ID -> GVLK key mapping (based on Microsoft official documentation)
$PIDKEY_MAP = @{
    # Office LTSC 2024
    "ProPlus2024Volume"    = "XJ2XN-FW8RK-P4HMP-DKDBV-GCVGB"
    "Standard2024Volume"   = "V28N4-JG22K-W66P8-VTMGK-H6HGR"
    # Project 2024
    "ProjectPro2024Volume" = "FQQ23-N4YCY-73HQ3-FM9WC-76HF4"
    "ProjectStd2024Volume" = "PD3TT-NTHQQ-VC7CY-MFXK3-G87F8"
    # Visio LTSC 2024
    "VisioPro2024Volume"   = "B7TN8-FJ8V3-7QYCP-HQPMV-YY89G"
    "VisioStd2024Volume"   = "JMMVY-XFNQC-KK4HK-9H7R3-WQQTV"
    # Office LTSC 2021
    "ProPlus2021Volume"    = "FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH"
    "Standard2021Volume"   = "KDX7X-BNVR8-TXXGX-4Q7Y8-78VT3"
    # Project 2021
    "ProjectPro2021Volume" = "FTNWT-C6WBT-8HMGF-K9PRX-QV9H8"
    "ProjectStd2021Volume" = "J2JDC-NJCYY-9RGQ4-YXWMH-T3D4T"
    # Visio LTSC 2021
    "VisioPro2021Volume"   = "KNH8D-FGHT4-T8RK3-CTDYJ-K2HT4"
    "VisioStd2021Volume"   = "MJVNY-BYWPY-CWV6J-2RKRT-4M8QG"
    # Office 2019
    "ProPlus2019Volume"    = "NMMKJ-6RK4F-KMJVX-8D9MJ-6MWKP"
    "Standard2019Volume"   = "6NWWJ-YQWMR-QKGCB-6TMB3-9D9HK"
    # Project 2019
    "ProjectPro2019Volume" = "B4NPR-3FKK7-T2MBV-FRQ4W-PKD2B"
    "ProjectStd2019Volume" = "C4F7P-NCP8C-6CQPT-MQHV9-JXD2M"
    # Visio 2019
    "VisioPro2019Volume"   = "9BGNQ-K37YR-RQHF2-38RQ3-7VCBB"
    "VisioStd2019Volume"   = "7TQNQ-K3YQQ-3PFH7-CCPPM-X4VQ2"
    # Office 2016
    "ProPlusVolume"        = "XQNVK-8JYDB-WJ9W3-YJ8YR-WFG99"
    "StandardVolume"       = "JNRGM-WHDWX-FJJG3-K47QV-DRTFM"
    # Project 2016
    "ProjectPro2016Volume" = "YG9NW-3K39V-2T3HJ-93F3Q-G83KT"
    "ProjectStd2016Volume" = "GNFHQ-F6YQM-KQDGJ-327XX-KQBVC"
    # Visio 2016
    "VisioPro2016Volume"   = "PD3PC-RHNGV-FXJ29-8JK7D-RJRJK"
    "VisioStd2016Volume"   = "7WHWN-4T7MP-G96JF-G33KR-W8GF4"
}

# Product ID -> display label (used in XML comments)
$PRODUCT_LABELS = @{
    "ProPlus2024Volume"    = "Office LTSC Professional Plus 2024 - Volume License"
    "Standard2024Volume"   = "Office LTSC Standard 2024 - Volume License"
    "VisioPro2024Volume"   = "Visio LTSC Professional 2024 - Volume License"
    "VisioStd2024Volume"   = "Visio LTSC Standard 2024 - Volume License"
    "ProjectPro2024Volume" = "Project Professional 2024 - Volume License"
    "ProjectStd2024Volume" = "Project Standard 2024 - Volume License"
    "ProPlus2021Volume"    = "Office LTSC Professional Plus 2021 - Volume License"
    "Standard2021Volume"   = "Office LTSC Standard 2021 - Volume License"
    "VisioPro2021Volume"   = "Visio LTSC Professional 2021 - Volume License"
    "VisioStd2021Volume"   = "Visio LTSC Standard 2021 - Volume License"
    "ProjectPro2021Volume" = "Project Professional 2021 - Volume License"
    "ProjectStd2021Volume" = "Project Standard 2021 - Volume License"
    "ProPlus2019Volume"    = "Office Professional Plus 2019 - Volume License"
    "Standard2019Volume"   = "Office Standard 2019 - Volume License"
    "VisioPro2019Volume"   = "Visio Professional 2019 - Volume License"
    "VisioStd2019Volume"   = "Visio Standard 2019 - Volume License"
    "ProjectPro2019Volume" = "Project Professional 2019 - Volume License"
    "ProjectStd2019Volume" = "Project Standard 2019 - Volume License"
    "ProPlusVolume"        = "Office Professional Plus 2016 - Volume License"
    "StandardVolume"       = "Office Standard 2016 - Volume License"
    "VisioPro2016Volume"   = "Visio Professional 2016 - Volume License"
    "VisioStd2016Volume"   = "Visio Standard 2016 - Volume License"
    "ProjectPro2016Volume" = "Project Professional 2016 - Volume License"
    "ProjectStd2016Volume" = "Project Standard 2016 - Volume License"
    "O365ProPlusRetail"    = "Microsoft 365 Apps for Enterprise"
}

# Generate ODT configuration file: supports multiple Product IDs, PIDKEY, MatchOS, AppSettings
function Generate-OfficeConfig {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ProductIds,
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        [string]$AppIds
    )

    # Auto-detect ODT Channel based on ProductIds
    $channelMappings = @{
        "2019" = "PerpetualVL2019"
        "2021" = "PerpetualVL2021"
        "2024" = "PerpetualVL2024"
    }
    $detectedChannel = "PerpetualVL2019"
    foreach ($year in @("2024", "2021", "2019")) {
        foreach ($p in $ProductIds) {
            if ($p -match $year) {
                $detectedChannel = $channelMappings[$year]
                break
            }
        }
        if ($detectedChannel -ne "PerpetualVL2019") { break }
    }

    # M365 uses Current channel
    if ($ProductIds -contains "O365ProPlusRetail") {
        $detectedChannel = "Current"
    }

    # ExcludeApp ID list
    $canonicalExcludeApps = @(
        "Access", "Excel", "Groove", "Lync", "OneNote",
        "Outlook", "OutlookForWindows", "PowerPoint", "Publisher",
        "Teams", "Word"
    )

    # If AppIds is specified, keep selected apps and exclude the rest; otherwise install all
    if ($AppIds) {
        $selectedIds = $AppIds.Split(',') | ForEach-Object { $_.Trim() }
        $excludedApps = $canonicalExcludeApps | Where-Object { $_ -notin $selectedIds }
    }
    else {
        $excludedApps = @()
    }

    $xmlWriter = New-Object System.Xml.XmlTextWriter($ConfigPath, [System.Text.Encoding]::UTF8)
    $xmlWriter.Formatting = 'Indented'
    $xmlWriter.Indentation = 2

    $xmlWriter.WriteStartDocument()
    # Build dynamic comment: from kms.akams.cn
    $commentParts = @()
    $firstProduct = $true
    foreach ($p in $ProductIds) {
        $label = if ($PRODUCT_LABELS.ContainsKey($p)) { $PRODUCT_LABELS[$p] } else { $p }
        if ($firstProduct -and $AppIds) {
            $appList = ($AppIds.Split(',') | ForEach-Object { $_.Trim() }) -join ", "
            $label += " ($appList)"
            $firstProduct = $false
        }
        $commentParts += $label
    }
    $commentText = "From kms.akams.cn - Installing: " + ($commentParts -join ", ")
    $xmlWriter.WriteComment($commentText)
    $xmlWriter.WriteStartElement("Configuration")

    # <Add>
    $xmlWriter.WriteStartElement("Add")
    $xmlWriter.WriteAttributeString("OfficeClientEdition", "64")
    $xmlWriter.WriteAttributeString("Channel", $detectedChannel)

    foreach ($p in $ProductIds) {
        $xmlWriter.WriteStartElement("Product")
        $xmlWriter.WriteAttributeString("ID", $p)
        if ($PIDKEY_MAP.ContainsKey($p) -and $PIDKEY_MAP[$p]) {
            $xmlWriter.WriteAttributeString("PIDKEY", $PIDKEY_MAP[$p])
        }
        $xmlWriter.WriteStartElement("Language")
        $xmlWriter.WriteAttributeString("ID", "MatchOS")
        $xmlWriter.WriteEndElement()
        foreach ($app in $excludedApps) {
            $xmlWriter.WriteStartElement("ExcludeApp")
            $xmlWriter.WriteAttributeString("ID", $app)
            $xmlWriter.WriteEndElement()
        }
        $xmlWriter.WriteEndElement()
    }
    $xmlWriter.WriteEndElement()

    # <Display>
    $xmlWriter.WriteStartElement("Display")
    $xmlWriter.WriteAttributeString("Level", "Full")
    $xmlWriter.WriteAttributeString("AcceptEULA", "TRUE")
    $xmlWriter.WriteEndElement()

    # <Property>
    $xmlWriter.WriteStartElement("Property")
    $xmlWriter.WriteAttributeString("Name", "AUTOACTIVATE")
    $xmlWriter.WriteAttributeString("Value", "1")
    $xmlWriter.WriteEndElement()

    # <Updates>
    $xmlWriter.WriteStartElement("Updates")
    $xmlWriter.WriteAttributeString("Enabled", "TRUE")
    $xmlWriter.WriteEndElement()

    # <RemoveMSI>
    $xmlWriter.WriteStartElement("RemoveMSI")
    $xmlWriter.WriteEndElement()

    # <AppSettings>
    $xmlWriter.WriteStartElement("AppSettings")
    $appSettings = @(
        @{Key="software\microsoft\office\16.0\excel\options"; Name="defaultformat"; Value="51"; Type="REG_DWORD"; App="excel16"; Id="L_SaveExcelfilesas"}
        @{Key="software\microsoft\office\16.0\powerpoint\options"; Name="defaultformat"; Value="27"; Type="REG_DWORD"; App="ppt16"; Id="L_SavePowerPointfilesas"}
        @{Key="software\microsoft\office\16.0\word\options"; Name="defaultformat"; Value=""; Type="REG_SZ"; App="word16"; Id="L_SaveWordfilesas"}
    )
    foreach ($setting in $appSettings) {
        $xmlWriter.WriteStartElement("User")
        $xmlWriter.WriteAttributeString("Key", $setting.Key)
        $xmlWriter.WriteAttributeString("Name", $setting.Name)
        $xmlWriter.WriteAttributeString("Value", $setting.Value)
        $xmlWriter.WriteAttributeString("Type", $setting.Type)
        $xmlWriter.WriteAttributeString("App", $setting.App)
        $xmlWriter.WriteAttributeString("Id", $setting.Id)
        $xmlWriter.WriteEndElement()
    }
    $xmlWriter.WriteEndElement()

    $xmlWriter.WriteEndElement()
    $xmlWriter.WriteEndDocument()
    $xmlWriter.Close()

    if (-not (Test-Path $ConfigPath)) {
        throw "Failed to generate config file: $ConfigPath"
    }
}

# --- Main Script Logic ---

# 1. Create Working Directory
if (-not (Test-Path $workDir)) {
    New-Item -Path $workDir -ItemType Directory -Force | Out-Null
}
Log-Message "Working directory ready: $workDir" -Level Success -WithBlankLine

# 2. Download Office Deployment Tool (ODT) - Enhanced with Content-Length Check
Log-Message "Checking / downloading Office Deployment Tool..." -Level Step

$shouldDownload = $true
$remoteSize = 0

try {
    Write-Host "  Checking remote file info..." -NoNewline
    $headResponse = Invoke-WebRequest -Uri $odtUrl -Method Head -UseBasicParsing -ErrorAction Stop -TimeoutSec 10

    if ($headResponse.Headers["Content-Length"]) {
        $remoteSize = [int64]$headResponse.Headers["Content-Length"]
        Write-Host " [Remote size: $remoteSize bytes]" -ForegroundColor Gray
    }
    else {
        Write-Host " [Warning: Content-Length not available]" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n  Warning: Cannot connect to remote server to get file header: $($_.Exception.Message)" -ForegroundColor Yellow
}

if (Test-Path $odtPath) {
    $localSize = (Get-Item $odtPath).Length
    Write-Host "  Local file size: $localSize bytes" -ForegroundColor Gray

    if ($remoteSize -gt 0) {
        if ($localSize -eq $remoteSize) {
            Write-Host "  Local file is intact (size match), skipping download." -ForegroundColor Green
            $shouldDownload = $false
        }
        else {
            Write-Host "  File size mismatch (local: $localSize vs remote: $remoteSize), re-downloading..." -ForegroundColor Yellow
            $shouldDownload = $true
        }
    }
    elseif ($localSize -eq 0) {
        $shouldDownload = $true
    }
    else {
        Write-Host "  Cannot verify remote size, using existing local file." -ForegroundColor Yellow
        $shouldDownload = $false
    }
}
else {
    Write-Host "  Local file not found, downloading..."
    $shouldDownload = $true
}

if ($shouldDownload) {
    try {
        Write-Host "  Downloading $odtUrl to $odtPath..."
        Invoke-WebRequest -Uri $odtUrl -OutFile $odtPath -ErrorAction Stop -UseBasicParsing
        Log-Message "ODT downloaded: $odtPath" -Level Success -WithBlankLine
    }
    catch {
        Log-Message "Failed to download ODT (setup.exe): $($_.Exception.Message)" -Level Error
        Show-MessageBox "Failed to download Office Deployment Tool. Please check your network connection or firewall settings." "Download Failed" "OK" "Error"
        Exit 1
    }
}

# --- Action: Uninstall ---
if ($Action -eq "Uninstall") {

    Log-Message "Action: Uninstall Office" -Level Title

    # 3. Generate Uninstall Configuration File
    Log-Message "Generating uninstall configuration file..." -Level Step
    $uninstallConfigContent = @"
<Configuration ID="office-uninstall-script-$(Get-Random)">
  <Remove All="TRUE" />
  <RemoveMSI />
  <Display Level="None" AcceptEULA="TRUE" />
  <Logging Level="Standard" Path="$workDir" />
</Configuration>
"@
    try {
        $uninstallConfigContent | Out-File -Encoding UTF8 -FilePath $configPath -Force
        Log-Message "Uninstall config created: $configPath" -Level Success -WithBlankLine
    }
    catch {
        Log-Message "Failed to create uninstall config: $($_.Exception.Message)" -Level Error
        Show-MessageBox "Failed to create uninstall configuration file." "Operation Failed" "OK" "Error"
        Exit 1
    }

    # 4. Execute Uninstall Command
    Log-Message "Starting Office uninstall (this may take a while)..." -Level Step
    try {
        $process = Start-Process -FilePath $odtPath -ArgumentList "/configure `"$configPath`"" -WorkingDirectory $workDir -Wait -PassThru -ErrorAction Stop
        if ($process.ExitCode -ne 0) {
            throw "Uninstall returned non-zero exit code: $($process.ExitCode)"
        }
        Log-Message "Office uninstall completed." -Level Success -WithBlankLine
    }
    catch {
        Log-Message "Office uninstall failed: $($_.Exception.Message)" -Level Error
        Show-MessageBox "An error occurred during Office uninstall. Check $logPath for details." "Uninstall Failed" "OK" "Error"
    }

    # 5. Transition to Deep Clean
    Log-Message "Starting deep clean..." -Level Step

    # --- Deep Clean (Force Uninstall Logic) ---
    Log-Message "Performing deep clean (post-uninstall steps)..." -Level Title

    # Step 1/7: Clean Office product keys
    Log-Message "Step 1/7: Cleaning installed Office product keys" -Level Step
    $osppPath = @(
        "C:\Program Files\Microsoft Office\Office16\ospp.vbs",
        "C:\Program Files (x86)\Microsoft Office\Office16\ospp.vbs",
        "C:\Program Files\Microsoft Office\Office15\ospp.vbs",
        "C:\Program Files (x86)\Microsoft Office\Office15\ospp.vbs"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($osppPath) {
        try {
            $keys = cscript //nologo "$osppPath" /dstatus | Select-String "Last 5 characters of installed product key" | ForEach-Object {
                if ($_.ToString() -match ":\s*([A-Z0-9]{5})") { $matches[1] }
            }

            if ($keys -and $keys.Count -gt 0) {
                foreach ($key in $keys) {
                    Log-Message "Uninstalling key: $key" -Level Warning
                    cscript //nologo "$osppPath" /unpkey:$key | Out-Null
                }
                Log-Message "Key cleanup completed." -Level Success
            }
            else {
                Log-Message "No installed Office retail or volume keys found." -Level Info
            }
        }
        catch {
            Log-Message "Exception during key cleanup, skipping this step." -Level Warning
        }
    }
    else {
        Log-Message "ospp.vbs not found (Office may already be uninstalled), skipping key cleanup." -Level Info
    }

    # Step 2/7: Terminate Office processes
    Log-Message "Step 2/7: Terminating Office processes" -Level Step
    $OfficeProcs = "winword", "excel", "powerpnt", "outlook", "onenote", "publisher", "visio", "mspub", "groove", "infiniteviz", "onenotem", "officeclicktorun", "setup", "integrationmanager"
    foreach ($proc in $OfficeProcs) {
        Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force
    }
    Log-Message "Step 2/7 done." -Level Success

    # Step 3/7: Stop and remove Office services
    Log-Message "Step 3/7: Uninstalling system services" -Level Step
    $Services = Get-Service | Where-Object { $_.DisplayName -like "*Microsoft Office*" -or $_.ServiceName -like "*ClickToRun*" }
    foreach ($svc in $Services) {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        sc.exe delete $svc.ServiceName 2>$null
    }
    Log-Message "Step 3/7 done." -Level Success

    # Step 4/7: Delete program folders
    Log-Message "Step 4/7: Removing program residual files" -Level Step
    $TargetFolders = @(
        "${env:ProgramFiles}\Microsoft Office",
        "${env:ProgramFiles(x86)}\Microsoft Office",
        "${env:ProgramFiles}\Common Files\Microsoft Shared\OFFICE16",
        "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\OFFICE16",
        "${env:ProgramData}\Microsoft\Office",
        "$env:LOCALAPPDATA\Microsoft\Office",
        "$env:APPDATA\Microsoft\Office"
    )

    foreach ($folder in $TargetFolders) {
        if (Test-Path $folder) {
            Write-Host "Cleaning path: $folder" -ForegroundColor Gray
            takeown /f $folder /r /d y >$null 2>$null
            icacls $folder /grant administrators:F /t >$null 2>$null
            Remove-Item -Recurse -Force $folder -ErrorAction SilentlyContinue
        }
    }
    Log-Message "Step 4/7 done." -Level Success

    # Step 5/7: Clean registry entries
    Log-Message "Step 5/7: Cleaning registry remnants" -Level Step
    $RegistryKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Office",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office",
        "HKCU:\Software\Microsoft\Office",
        "HKLM:\SOFTWARE\Microsoft\AppVISV",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Office*",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Office*"
    )

    foreach ($key in $RegistryKeys) {
        if (Test-Path $key) {
            Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Log-Message "Step 5/7 done." -Level Success

    # Step 6/7: Clean shortcuts
    Log-Message "Step 6/7: Cleaning shortcuts" -Level Step
    $ShortcutPaths = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
        "$env:AppData\Microsoft\Windows\Start Menu\Programs",
        "$env:USERPROFILE\Desktop",
        "$env:Public\Desktop",
        "$env:AppData\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    )

    $Keywords = @("*Office*", "*Word*", "*Excel*", "*PowerPoint*", "*Outlook*", "*OneNote*", "*Access*", "*Publisher*", "*Lync*", "*Skype for Business*")

    foreach ($path in $ShortcutPaths) {
        if (Test-Path $path) {
            foreach ($key in $Keywords) {
                Get-ChildItem -Path $path -Filter $key -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -Confirm:$false
            }
        }
    }
    Log-Message "Step 6/7 done." -Level Success

    # Step 7/7: Clean scheduled tasks and restart explorer
    Log-Message "Step 7/7: Removing scheduled tasks and restarting explorer" -Level Step
    Get-ScheduledTask -TaskPath "\Microsoft\Office\" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
    Log-Message "Step 7/7 done." -Level Success

    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

    Log-Message "Deep clean completed. Some DLLs may remain in memory, a reboot is strongly recommended." -Level Success -WithBlankLine
    Show-MessageBox "Office uninstall and deep clean completed. A reboot is strongly recommended." "Operation Complete"

}
# --- Action: Install ---
elseif ($Action -eq "Install") {

    # Validate ProductIds
    if (-not $ProductIds) {
        Log-Message "ProductIds not specified for install." -Level Error
        Show-MessageBox "Product IDs are required to install Office (e.g., ProPlus2021Volume)." "Parameter Error" "OK" "Error"
        Exit 1
    }

    # Split comma-separated ProductIds into array
    $productIdArray = $ProductIds.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($productIdArray.Count -eq 0) {
        Log-Message "ProductIds is empty or invalid." -Level Error
        Show-MessageBox "Valid product IDs are required (e.g., ProPlus2024Volume,VisioPro2024Volume)." "Parameter Error" "OK" "Error"
        Exit 1
    }

    $productList = $productIdArray -join ', '
    if ($AppIds) {
        Log-Message "Action: Install Office | Products: $productList | Apps: $AppIds" -Level Title -WithBlankLine
    }
    else {
        Log-Message "Action: Install Office | Products: $productList | Apps: All" -Level Title -WithBlankLine
    }

    # 3. Terminate existing Office processes
    Get-Process -Name "OfficeC2RClient", "outlook", "winword", "excel", "powerpnt", "msaccess", "visio", "project", "onenote", "mspub", "lync", "teams", "setup", "odt" -ErrorAction SilentlyContinue | ForEach-Object {
        Log-Message "Terminating conflicting process: $($_.Name) (ID: $($_.Id))" -Level Warning
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 300
    }

    # 4. Generate Local Configuration File
    Log-Message "Generating local Office configuration file..." -Level Step
    try {
        Generate-OfficeConfig -ProductIds $productIdArray -AppIds $AppIds -ConfigPath $configPath
        Log-Message "Local config file generated: $configPath" -Level Success -WithBlankLine
    }
    catch {
        Log-Message "Failed to generate Office config: $($_.Exception.Message)" -Level Error
        Show-MessageBox "Failed to generate Office configuration. $($_.Exception.Message)" "Config Failed" "OK" "Error"
        Exit 1
    }

    # 5. Execute Install Command
    Log-Message "Starting Office installation (this may take a long time, please be patient)..." -Level Step -WithBlankLine
    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $odtPath
        $processInfo.Arguments = "/configure `"$configPath`""
        $processInfo.WorkingDirectory = $workDir
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        $stdOutput = $process.StandardOutput.ReadToEndAsync()
        $stdError = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()

        $exitCode = $process.ExitCode
        $outputLog = $stdOutput.Result
        $errorLog = $stdError.Result

        if ($outputLog) { Log-Message "ODT stdout: $outputLog" -Level Info }
        if ($errorLog) { Log-Message "ODT stderr: $errorLog" -Level Info }

        if ($exitCode -ne 0) {
            throw "Office install failed. Exit code: $exitCode. Error: $errorLog"
        }
        Log-Message "Office installed successfully. Exit code: $exitCode" -Level Success -WithBlankLine

    }
    catch {
        Log-Message "Office install failed - $($_.Exception.Message)" -Level Error
        if ($errorLog) { Write-Host "Details: $errorLog" -ForegroundColor Red }
        Show-MessageBox "An error occurred during Office installation. Check $logPath for details.`n$($_.Exception.Message)" "Install Failed" "OK" "Error"
        Exit 1
    }

    # 6. Install Mondo 2016 License Certificates (for O365ProPlusRetail KMS activation)
    if ($productIdArray -contains "O365ProPlusRetail") {
        Log-Message "O365ProPlusRetail detected, installing Mondo 2016 license certificates..." -Level Step
        $mondoLicensePath = @(
            "${env:ProgramFiles}\Microsoft Office\root\Licenses16",
            "${env:ProgramFiles(x86)}\Microsoft Office\root\Licenses16"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($mondoLicensePath) {
            $mondoCerts = @(
                "MondoVL_KMS_Client-ppd.xrm-ms",
                "MondoVL_KMS_Client-ul-oob.xrm-ms",
                "MondoVL_KMS_Client-ul.xrm-ms",
                "MondoVL_MAK-pl.xrm-ms",
                "MondoVL_MAK-ppd.xrm-ms",
                "MondoVL_MAK-ul-oob.xrm-ms",
                "MondoVL_MAK-ul-phn.xrm-ms"
            )
            $slmgr = Join-Path -Path $env:SystemRoot -ChildPath "System32\slmgr.vbs"
            foreach ($cert in $mondoCerts) {
                $certPath = Join-Path -Path $mondoLicensePath -ChildPath $cert
                if (Test-Path $certPath) {
                    $result = cscript //nologo "$slmgr" /ilc "$certPath" 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Log-Message "Certificate installed: $cert" -Level Success
                    }
                    else {
                        Log-Message "Failed to install certificate: $cert - $result" -Level Warning
                    }
                }
                else {
                    Log-Message "Certificate file not found: $certPath" -Level Warning
                }
            }
            Log-Message "Mondo 2016 certificate installation completed." -Level Success -WithBlankLine
        }
        else {
            Log-Message "Office Licenses16 directory not found, skipping Mondo certificate installation." -Level Warning
        }
    }

    # 7. Create Desktop Shortcuts
    Log-Message "Creating desktop shortcuts..." -Level Step
    function New-DesktopShortcut {
        param (
            [string]$Target,
            [string]$Name
        )
        $shortcutPath = Join-Path -Path $env:USERPROFILE -ChildPath "Desktop\$Name.lnk"
        if (-not (Test-Path $shortcutPath)) {
            try {
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = $Target
                $shortcut.Save()
                Log-Message "Shortcut created: $Name.lnk" -Level Success
            }
            catch {
                Log-Message "Failed to create shortcut $Name.lnk: $($_.Exception.Message)" -Level Warning
            }
        }
        else {
            Log-Message "Shortcut already exists: $Name.lnk" -Level Info
        }
    }

    $foundOfficeApps = @{}
    $startMenuProgramsPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    if (Test-Path $startMenuProgramsPath) {
        Get-ChildItem -Path $startMenuProgramsPath -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($_.FullName)
                $targetPath = $shortcut.TargetPath

                if ($targetPath -and ($targetPath -match "\\Office\d{2}\\[^\\]+\.exe$" -or $targetPath -match "root\\Office\d{2}\\[^\\]+\.exe$")) {
                    $appName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                    $exeName = [System.IO.Path]::GetFileName($targetPath)

                    if ("WINWORD.EXE", "EXCEL.EXE", "POWERPNT.EXE", "OUTLOOK.EXE", "MSACCESS.EXE", "MSPUB.EXE", "ONENOTE.EXE", "VISIO.EXE", "PROJECT.EXE" -contains $exeName.ToUpperInvariant()) {
                        if (-not $foundOfficeApps.ContainsKey($appName)) {
                            New-DesktopShortcut -Target $targetPath -Name $appName
                            $foundOfficeApps[$appName] = $true
                        }
                    }
                }
            }
            catch {
                Log-Message "Error processing Start Menu shortcut '$($_.Name)' - $($_.Exception.Message)" -Level Warning
            }
        }
    }
    else {
        Log-Message "Start Menu Programs folder not found: $startMenuProgramsPath" -Level Warning
    }

    if ($foundOfficeApps.Count -eq 0) {
        Log-Message "No Office application shortcuts found in Start Menu to copy to desktop." -Level Warning
    }

    # 8. Final Install Message and KMS site
    Log-Message "Office installation completed." -Level Success -WithBlankLine
    Show-MessageBox "Office installation complete! Visit KMS.AKAMS.CN to activate your Office products." "Install Success"

    try {
        Log-Message "Opening KMS activation guide page..." -Level Step
        Start-Process "https://kms.akams.cn" -WindowStyle Normal -ErrorAction SilentlyContinue
        Log-Message "Attempted to open KMS website: https://kms.akams.cn" -Level Info
    }
    catch {
        Log-Message "Failed to open KMS website - $($_.Exception.Message)" -Level Warning
    }
}
# --- Action: ForceUninstall ---
else {
    Log-Message "Invalid action parameter: '$Action'" -Level Error
    Exit 1
}

Log-Message "Script execution completed." -Level Success -WithBlankLine
Exit 0
