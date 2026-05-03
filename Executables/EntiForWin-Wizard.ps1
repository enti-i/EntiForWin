#requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Write-Log { param([string]$m,[System.Windows.Forms.TextBox]$l) $l.AppendText("$m`r`n") }
function Invoke-Step {
    param([string]$Name,[scriptblock]$Action,[int]$Percent,[System.Windows.Forms.ProgressBar]$Progress,[System.Windows.Forms.Label]$Status,[System.Windows.Forms.TextBox]$Log)
    $Status.Text = "Running: $Name"
    Write-Log "[INFO] $Name" $Log
    & $Action
    $Progress.Value = [Math]::Min(100, $Percent)
    Write-Log "[OK]   $Name" $Log
}

$form = New-Object Windows.Forms.Form
$form.Text='EntiForWin Full Installer Wizard'
$form.Size=New-Object Drawing.Size(960,760)
$form.StartPosition='CenterScreen'; $form.MaximizeBox=$false; $form.FormBorderStyle='FixedDialog'

$lbl=New-Object Windows.Forms.Label
$lbl.Text='EntiForWin - Full System Transformation Installer'
$lbl.Font=New-Object Drawing.Font('Segoe UI',14,[Drawing.FontStyle]::Bold)
$lbl.AutoSize=$true; $lbl.Location=New-Object Drawing.Point(20,15); $form.Controls.Add($lbl)

$sub=New-Object Windows.Forms.Label
$sub.Text='Komplette Installation + optional vollständige System-Anpassung.'
$sub.AutoSize=$true; $sub.Location=New-Object Drawing.Point(20,48); $form.Controls.Add($sub)

$g=New-Object Windows.Forms.GroupBox
$g.Text='Install / Transformation Mode'; $g.Size=New-Object Drawing.Size(900,220); $g.Location=New-Object Drawing.Point(20,80); $form.Controls.Add($g)

$rbSafe=New-Object Windows.Forms.RadioButton
$rbSafe.Text='Standard Install (safe)'; $rbSafe.Location=New-Object Drawing.Point(14,28); $rbSafe.AutoSize=$true; $rbSafe.Checked=$true; $g.Controls.Add($rbSafe)
$rbFull=New-Object Windows.Forms.RadioButton
$rbFull.Text='FULL SYSTEM TRANSFORMATION (recommended by request)'; $rbFull.Location=New-Object Drawing.Point(14,54); $rbFull.AutoSize=$true; $g.Controls.Add($rbFull)

$cbDesktop=New-Object Windows.Forms.CheckBox
$cbDesktop.Text='Install Desktop assets to C:\Windows\AtmosphereDesktop'; $cbDesktop.Location=New-Object Drawing.Point(14,88); $cbDesktop.AutoSize=$true; $cbDesktop.Checked=$true; $g.Controls.Add($cbDesktop)
$cbModules=New-Object Windows.Forms.CheckBox
$cbModules.Text='Install Modules to C:\Windows\AtmosphereModules'; $cbModules.Location=New-Object Drawing.Point(14,114); $cbModules.AutoSize=$true; $cbModules.Checked=$true; $g.Controls.Add($cbModules)
$cbShortcut=New-Object Windows.Forms.CheckBox
$cbShortcut.Text='Create EntiForWin desktop shortcut'; $cbShortcut.Location=New-Object Drawing.Point(14,140); $cbShortcut.AutoSize=$true; $cbShortcut.Checked=$true; $g.Controls.Add($cbShortcut)
$cbReboot=New-Object Windows.Forms.CheckBox
$cbReboot.Text='Auto reboot after completion'; $cbReboot.Location=New-Object Drawing.Point(14,166); $cbReboot.AutoSize=$true; $g.Controls.Add($cbReboot)

$warn=New-Object Windows.Forms.Label
$warn.Text='Hinweis: Full Mode führt viele bestehende EntiForWin/Atmosphere-Skripte automatisiert aus.'
$warn.AutoSize=$true; $warn.ForeColor='DarkRed'; $warn.Location=New-Object Drawing.Point(20,315); $form.Controls.Add($warn)

$status=New-Object Windows.Forms.Label
$status.Text='Ready.'; $status.AutoSize=$true; $status.Location=New-Object Drawing.Point(20,340); $form.Controls.Add($status)

$progress=New-Object Windows.Forms.ProgressBar
$progress.Location=New-Object Drawing.Point(20,365); $progress.Size=New-Object Drawing.Size(900,24); $progress.Minimum=0; $progress.Maximum=100; $form.Controls.Add($progress)

$log=New-Object Windows.Forms.TextBox
$log.Multiline=$true; $log.ScrollBars='Vertical'; $log.ReadOnly=$true
$log.Font=New-Object Drawing.Font('Consolas',9); $log.Size=New-Object Drawing.Size(900,290); $log.Location=New-Object Drawing.Point(20,400); $form.Controls.Add($log)

$btnInstall=New-Object Windows.Forms.Button
$btnInstall.Text='Install'; $btnInstall.Size=New-Object Drawing.Size(120,34); $btnInstall.Location=New-Object Drawing.Point(670,700); $form.Controls.Add($btnInstall)
$btnClose=New-Object Windows.Forms.Button
$btnClose.Text='Close'; $btnClose.Size=New-Object Drawing.Size(120,34); $btnClose.Location=New-Object Drawing.Point(800,700); $btnClose.Add_Click({$form.Close()}); $form.Controls.Add($btnClose)

$btnInstall.Add_Click({
    $btnInstall.Enabled=$false; $progress.Value=0
    Write-Log "=== Start $(Get-Date) ===" $log
    try {
        Invoke-Step 'Validate admin rights' {
            $p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){ throw 'Run as Administrator' }
        } 5 $progress $status $log

        Invoke-Step 'Prepare target folders' {
            New-Item -ItemType Directory -Path 'C:\Windows\AtmosphereDesktop' -Force | Out-Null
            New-Item -ItemType Directory -Path 'C:\Windows\AtmosphereModules' -Force | Out-Null
        } 12 $progress $status $log

        if($cbDesktop.Checked){ Invoke-Step 'Copy Desktop assets' { Copy-Item '.\AtmosphereDesktop\*' 'C:\Windows\AtmosphereDesktop' -Recurse -Force -ErrorAction Stop } 25 $progress $status $log }
        if($cbModules.Checked){ Invoke-Step 'Copy Modules' { Copy-Item '.\AtmosphereModules\*' 'C:\Windows\AtmosphereModules' -Recurse -Force -ErrorAction Stop } 38 $progress $status $log }
        if($cbShortcut.Checked){ Invoke-Step 'Create desktop shortcut' {
            $s=New-Object -ComObject WScript.Shell
            $lnk=$s.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\EntiForWin.lnk")
            $lnk.TargetPath='C:\Windows\AtmosphereDesktop'; $lnk.Save()
        } 45 $progress $status $log }

        if($rbSafe.Checked){
            Invoke-Step 'Apply baseline tweaks' {
                reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
                reg add 'HKCU\Software\Microsoft\GameBar' /v ShowStartupPanel /t REG_DWORD /d 0 /f | Out-Null
                reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' /v Enabled /t REG_DWORD /d 0 /f | Out-Null
            } 70 $progress $status $log
        }

        if($rbFull.Checked){
            Invoke-Step 'FULL: apply service defaults script' { Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','"C:\Windows\AtmosphereDesktop\8. Troubleshooting\Set services to defaults.cmd" /silent' -Wait } 55 $progress $status $log
            Invoke-Step 'FULL: run user configuration script' { Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoP','-EP','Bypass','-File','C:\Windows\AtmosphereModules\Scripts\newUsers.ps1' -Wait } 70 $progress $status $log
            Invoke-Step 'FULL: run post-install finalizer' { Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoP','-EP','Bypass','-File','C:\Windows\AtmosphereModules\Scripts\Post-Install.ps1' -Wait } 85 $progress $status $log
            Invoke-Step 'FULL: register RAMSYS task if present' {
                $xml='C:\Windows\AtmosphereModules\Other\RAMSYS.xml'
                if(Test-Path $xml){ Register-ScheduledTask -TaskName RAMSYS -Xml (Get-Content $xml -Raw) -Force | Out-Null }
            } 93 $progress $status $log
        }

        Invoke-Step 'Finalize' { Start-Sleep -Milliseconds 300 } 100 $progress $status $log
        $status.Text='Installation complete.'
        Write-Log '=== Completed successfully ===' $log
        if($cbReboot.Checked){ Write-Log '[INFO] Rebooting in 10 seconds...' $log; shutdown.exe /r /t 10 }
        [Windows.Forms.MessageBox]::Show('EntiForWin installation completed.','EntiForWin Installer')|Out-Null
    } catch {
        $status.Text='Failed.'
        Write-Log "[ERR] $($_.Exception.Message)" $log
        [Windows.Forms.MessageBox]::Show("Installation failed: $($_.Exception.Message)",'EntiForWin Installer')|Out-Null
    } finally { $btnInstall.Enabled=$true }
})

[void]$form.ShowDialog()
