$ErrorActionPreference = "Stop"
$ScriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Invoke-CMApplyDriverPackage.ps1"
$ParseErrors = $null
$Ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$ParseErrors)
if ($ParseErrors.Count) { throw ($ParseErrors.Message -join "; ") }

foreach ($Name in @("Get-OSBuild", "Get-ComputerSystemType", "Confirm-SystemSKU", "Get-DeploymentType", "New-TerminatingErrorRecord", "Test-VirtualMachineDriverPackage")) {
    $Node = $Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Item.Name -eq $Name }.GetNewClosure(), $true)
    Invoke-Expression $Node.Extent.Text
}
$Node = $Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.AssignmentStatementAst] -and $Item.Left.Extent.Text -eq '$Script:VirtualMachinePackagePattern' }, $true)
Invoke-Expression $Node.Extent.Text
function Write-CMLogEntry { param($Value, $Severity) }
function Get-ItemProperty {
    param($Path, $Name, $ErrorAction)
    if ($Script:DisplayVersionThrows) { throw "DisplayVersion unavailable" }
    [pscustomobject]@{ DisplayVersion = $Script:DisplayVersion }
}
function Get-WmiObject { param($Class) $Script:TestSystem }
foreach ($Case in @(
    @("10.0.26300.1", "26H2"),
    @("10.0.28000.1", "26H1"),
    @("10.0.26200.1", "25H2")
)) {
    if ((Get-OSBuild -InputObject $Case[0] -OSName "Windows 11") -ne $Case[1]) {
        throw "Incorrect Windows 11 build mapping: $($Case -join ', ')"
    }
}
$Script:DisplayVersion = "27H1"
$Script:DisplayVersionThrows = $false
if ((Get-OSBuild -InputObject "10.0.29000.1" -OSName "Windows 11") -ne "27H1") {
    throw "DisplayVersion fallback failed"
}
foreach ($Fallback in @(
    @{ Value = "Preview"; Throws = $false },
    @{ Value = $null; Throws = $true }
)) {
    $Script:DisplayVersion = $Fallback.Value
    $Script:DisplayVersionThrows = $Fallback.Throws
    $Blocked = $false
    try { Get-OSBuild -InputObject "10.0.29000.1" -OSName "Windows 11" } catch { $Blocked = $true }
    if (-not $Blocked) { throw "Invalid or missing DisplayVersion did not fail closed" }
}
function Test-Platform {
    [CmdletBinding(DefaultParameterSetName = "BareMetal")]
    param([Parameter(ParameterSetName = "Debug")][switch]$DebugMode)
    $Script:PSCmdlet = $PSCmdlet
    Get-ComputerSystemType
}
$Cases = @(
    @("VMware7,1", "VMware, Inc.", "Hypervisor-VMware"),
    @("VMware 22,1", "VMware, Inc.", "Hypervisor-VMware"),
    @("Virtual Machine", "Microsoft Corporation", "Hypervisor-HyperV"),
    @("VirtualBox", "Oracle Corporation", "Hypervisor-VirtualBox"),
    @("Standard PC (Q35 + ICH9, 2009)", "QEMU", "Hypervisor-QEMUKVM"),
    @("KVM Virtual Machine", "Red Hat", "Hypervisor-QEMUKVM"),
    @("Standard PC (Q35 + ICH9, 2009)", "Contoso", "Physical-Unknown"),
    @("XenEnterprise", "Xen", "Hypervisor-XenCitrix"),
    @("HVM domU", "Citrix", "Hypervisor-XenCitrix"),
    @("Surface Pro", "Microsoft Corporation", "OEM-Surface"),
    @("Latitude", "Dell", "OEM-Dell"),
    @("Alienware m18", "Dell Inc.", "OEM-Alienware"),
    @("EliteBook", "Hewlett-Packard", "OEM-HP"),
    @("ExpertBook", "ASUSTeK COMPUTER INC.", "OEM-ASUS"),
    @("NUC13", "Intel", "OEM-IntelNUC"),
    @("Server", "Red Hat", "Physical-Unknown"),
    @("Virtual Machine", "Contoso", "Physical-Unknown")
)
foreach ($Case in $Cases) {
    $Script:TestSystem = [pscustomobject]@{ Model = $Case[0]; Manufacturer = $Case[1] }
    $AllowVirtualMachine = $true
    Test-Platform
    if ($Script:ComputerPlatform -ne $Case[2]) { throw "Incorrect platform: $($Case -join ', ')" }
    $AllowVirtualMachine = $false
    if ($Case[2] -like "Hypervisor-*") {
        $Blocked = $false
        try { Test-Platform } catch { if ($_.Exception.Message -ne "InnerTerminatingFailure") { throw }; $Blocked = $true }
        if (-not $Blocked) { throw "Virtual platform bypassed opt-in" }
        Test-Platform -DebugMode
    }
    else { Test-Platform }
}
foreach ($Case in @(
    @("42", "42", $true), @("142", "42", $false), @("ModelSKU-42", "42", $false),
    @("42;43,44 45", "44", $true), @("42;43,44 45", "45", $true),
    @("A[1]", "A[1]", $true), @("A1", "A[1]", $false), @("42", "", $false)
)) {
    $Result = Confirm-SystemSKU -DriverPackageInput $Case[0] -ComputerData ([pscustomobject]@{ SystemSKU = $Case[1]; FallbackSKU = "" })
    if ($Result.Detected -ne $Case[2]) { throw "Incorrect SKU match: $($Case -join ', ')" }
}
$Result = Confirm-SystemSKU -DriverPackageInput "42;43" -ComputerData ([pscustomobject]@{ SystemSKU = ""; FallbackSKU = "43" })
if (-not $Result.Detected -or $Result.SystemSKUValue -ne "43") { throw "Fallback SKU failed" }

function Test-Path { param($Path) $Script:XmlExists }
$TSEnvironment = New-Object PSObject
$TSEnvironment | Add-Member ScriptMethod Value { param($Name) "C:\Package" }
function Test-Deployment {
    [CmdletBinding(DefaultParameterSetName = "XMLPackage")]
    param()
    $Script:PSCmdlet = $PSCmdlet
    Get-DeploymentType
}
$Script:XmlExists = $true
foreach ($Mode in @("OSUpdate", "OSUpgrade", "BareMetal", "DriverUpdate", "PreCache")) {
    $Script:XMLDeploymentType = $Mode
    Test-Deployment
    $Expected = $Mode
    if ($Mode -eq "OSUpdate") { $Expected = "OSUpgrade" }
    if ($Script:DeploymentMode -ne $Expected) { throw "Incorrect XML deployment mode" }
}
$Script:XmlExists = $false
$Blocked = $false
try { Test-Deployment } catch { if ($_.Exception.Message -ne "InnerTerminatingFailure") { throw }; $Blocked = $true }
if (-not $Blocked) { throw "Missing XML file did not stop deployment" }

$InstallNode = $Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Item.Name -eq "Install-DriverPackageContent" }, $true)
$SwitchNode = $InstallNode.Find({ param($Item) $Item -is [System.Management.Automation.Language.SwitchStatementAst] -and $Item.Condition.Extent.Text -eq '$Script:DeploymentMode' }, $true)
$UpdateClause = $SwitchNode.Clauses | Where-Object { $_.Item1.Value -eq "DriverUpdate" }
$UpdateBlock = [scriptblock]::Create($UpdateClause.Item2.Extent.Text.TrimStart("{").TrimEnd("}"))
function Invoke-Executable { param($FilePath, $Arguments) $Script:InstallArguments = $Arguments; $Script:InstallExitCode }
function Test-Install {
    [CmdletBinding()]param()
    & $UpdateBlock
}
$ContentLocation = "C:\Driver Packs\O'Brien"
$LogsDirectory = "C:\Deployment Logs"
foreach ($Code in @(0, 3010, 5, -1)) {
    $Script:InstallExitCode = $Code
    $Failed = $false
    try { Test-Install } catch { if ($_.Exception.Message -ne "InnerTerminatingFailure") { throw }; $Failed = $true }
    if ($Failed -ne ($Code -notin @(0, 3010))) { throw "Incorrect installation exit handling: $Code" }
}
$Command = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String(($Script:InstallArguments -split " ")[-1]))
$CommandErrors = $null
[System.Management.Automation.Language.Parser]::ParseInput($Command, [ref]$null, [ref]$CommandErrors) | Out-Null
if ($CommandErrors.Count -or $Command -notlike '*exit $LASTEXITCODE*' -or -not $Command.Contains("O''Brien")) { throw "Installer command quoting or exit propagation failed" }
foreach ($Label in @("VMware7,1", "Citrix", "XenServer", "Proxmox", "VirtIO")) {
    if (-not (Test-VirtualMachineDriverPackage -Package ([pscustomobject]@{ Name = "Drivers - $Label - Windows 11 26H2 Arm64" }))) { throw "VM package label rejected" }
}
$FallbackNode = $Ast.Find({ param($Item) $Item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Item.Name -eq "Confirm-FallbackDriverPackage" }, $true)
if ($null -eq $FallbackNode) { throw "Fallback function not found" }
$PatternNode = $FallbackNode.Find({ param($Item) $Item -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $Item.Value -like "*Architecture*" -and $Item.Value -like "*x86*" }, $true)
if ("Driver Fallback Package - Windows 11 Arm64" -notmatch $PatternNode.Value -or $Matches.Architecture -ne "Arm64") { throw "Arm64 fallback parsing failed" }
Write-Output "Driver deployment regression checks passed."
