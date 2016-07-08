
[CmdletBinding()]
param
(
    [String]
    [Parameter(Mandatory = $false)]
    $vsName,

    [String]
    [Parameter(Mandatory = $false)]
    $domainName,

    [String]
    [Parameter(Mandatory = $false)]
    $dcName = "INFRA-DC",

    [String]
    [Parameter(Mandatory = $false)]
    $AdminPassword = "User@123",

    [String]
    [Parameter(Mandatory = $false)]
    $Differentiator = (get-date -format hhmmss),
 
    [INT]
    [Parameter(Mandatory = $false)]
    $nodeNumber = 3,

    [INT]
    [Parameter(Mandatory = $false)]
    $diskNumber = 4,

    [string]
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("Hyper-Converged", "Disaggregate")]
    $Usage = "Hyper-Converged",

    [String]
    [Parameter(Mandatory = $false)]
    $VHDLanguage = "en-US"
)

$ErrorActionPreference = 'Stop'

$SecurePassword = $AdminPassword | ConvertTo-SecureString -AsPlainText -Force
$LocalAdmin = ".\administrator"
$localCred = New-Object System.Management.Automation.PSCredential -ArgumentList $LocalAdmin, $SecurePassword

if ( $vsName -eq "") 
{
    $dc = get-vm $dcName
    $vsName = (Get-VMNetworkAdapter -VM $dc).SwitchName
}
else
{
    Get-VMSwitch $vsName
}

$targetDir=Read-Host "What directory do you want to create VM"                 # Get the target directory for the VM provsioning

if (Test-Path $targetDir\OS.VHDX)
{
    Write-Host "INFO   : OS.VHDX exists"
}
else
{
    $image=Read-Host "Please provide the full path of the syspreped image VHD" # Get the path of the syspreped image
    Write-Host "INFO   : Prepare a local copy of the syspreped image..."
    Copy $image $targetDir\OS.VHDX
} 

for ($i=1 ; $i -le $nodeNumber ; $i++) 
{     
    $COMPUTERNAME = "HOST"+$Differentiator+$i

    Write-Host "INFO   : Preparing " $COMPUTERNAME

    $newDir = Join-Path $targetDir $COMPUTERNAME
    MD $newDir
    Copy $targetDir\OS.VHDX $newDir

    # Prepare unattend file

    # Write-Host "INFO   : Preparing Unattend File for" $COMPUTERNAME
             
    $VHDXFILE = Join-Path $newDir 'OS.VHDX'
    Dismount-DiskImage -ImagePath $VHDXFILE
    Mount-DiskImage -ImagePath $VHDXFILE -StorageType vhdx -Access ReadWrite
    $DriveLetter = (Get-DiskImage -ImagePath $VHDXFILE | Get-Disk | Get-Partition | Get-Volume).DriveLetter

    $UnattendedFilePath = ".\unattend_amd64_Server.xml"
    $UnattendedFile = (Get-Content $UnattendedFilePath)
    $UnattendedFile = $UnattendedFile -replace "%productkey%", "74YFP-3QFB3-KQT8W-PMXWJ-7M648"
    $UnattendedFile = $UnattendedFile -replace "%locale%", $VHDLanguage
    $UnattendedFile = $UnattendedFile -replace "%computername%", $COMPUTERNAME
    $UnattendedFile = $UnattendedFile -replace "%adminpassword%", $AdminPassword

    $UnattendedFile | Out-File ($DriveLetter+":\unattend.xml") -Encoding ascii

    Dismount-DiskImage -ImagePath $VHDXFILE

    # Write-Host "INFO   : Unattend File is in place"

    New-VM -Name $COMPUTERNAME -Path $targetDir -VHDPath $VHDXFILE -Memory 16GB -SwitchName $vsName -Generation 2
    Set-VM -Name $COMPUTERNAME  -ProcessorCount 8    
    1..$diskNumber | % { New-VHD -Path $newDir\Disk_$_.VHDX -Fixed -Size 20GB}
    1..$diskNumber | % { Add-VMHardDiskDrive -VMName $COMPUTERNAME -ControllerType SCSI -Path $newDir\Disk_$_.VHDX}

    if ( $Usage -eq "Hyper-Converged") 
    {
        # Enable Nested Virtualization

        Write-Host "INFO   : Enable Nested Virtualization for"$COMPUTERNAME
        Set-VMProcessor -VMName $COMPUTERNAME -ExposeVirtualizationExtensions $true
        Set-VMNetworkAdapter -VMName $COMPUTERNAME -MacAddressSpoofing on
    }

    # Join Domain and install Roles and Features

    Start-VM $COMPUTERNAME
    sleep 120
    Invoke-Command -VMName $COMPUTERNAME -ScriptBlock {param($domainName,$AdminPassword); `
        Get-NetAdapter -Name Ethernet | Rename-NetAdapter -NewName MGMT; ` 
        if ( $domainName -eq "") {$domainName = (Get-NetIPConfiguration).NetProfile.Name}; `
        $securePassword = $AdminPassword | ConvertTo-SecureString -AsPlainText -Force; `
        $domainAdmin = $domainName+"\administrator"; `
        $domainCred = New-Object System.Management.Automation.PSCredential -ArgumentList $domainAdmin, $securePassword; `
        sleep 30; `
        Add-Computer -DomainName $domainName -Credential $domainCred; `
        Install-WindowsFeature –Name File-Services, Failover-Clustering, Data-Center-Bridging -IncludeManagementTools} -Credential $localCred -ArgumentList $($domainName,$AdminPassword)

    if ( $Usage -eq "Hyper-Converged") 
    {
        Invoke-Command -VMName $COMPUTERNAME -ScriptBlock {Install-WindowsFeature –Name Hyper-V -IncludeManagementTools -Restart} -Credential $localCred
    }
    else
    {
        Invoke-Command -VMName $COMPUTERNAME -ScriptBlock {Restart-Computer} -Credential $localCred
    }
}