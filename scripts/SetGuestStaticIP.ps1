param(
    $VirtualMachine,
    $Username,
    $Password,
    $IPAddress,
    $NetMask,
    $DefaultGateway,
    $DNSServer
)
Write-Output "Set $VirtualMachine IP to $IPAddress / $NetMask gw $DefaultGateway dns $DNSServer"
#Get an instance of the management service, the Msvm Computer System and setting data
$Msvm_VirtualSystemManagementService = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemManagementService
Write-Output "Msvm_VirtualSystemManagementService is $Msvm_VirtualSystemManagementService"
$Msvm_ComputerSystem = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter "ElementName='$VirtualMachine'"
Write-Output "Msvm_ComputerSystem is $Msvm_ComputerSystem"
$Msvm_VirtualSystemSettingData = $Msvm_ComputerSystem.GetRelated(
    "Msvm_VirtualSystemSettingData",
    "Msvm_SettingsDefineState",
    $null,
    $null,
    "SettingData",
    "ManagedElement",
    $false,
    $null)

#Get an instance of the port setting data object and the related guest network configuration object
$Msvm_SyntheticEthernetPortSettingData = $Msvm_VirtualSystemSettingData.GetRelated("Msvm_SyntheticEthernetPortSettingData")
$Msvm_GuestNetworkAdapterConfigurations = $Msvm_SyntheticEthernetPortSettingData.GetRelated(
    "Msvm_GuestNetworkAdapterConfiguration",
    "Msvm_SettingDataComponent",
    $null,
    $null,
    "PartComponent",
    "GroupComponent",
    $false,
    $null)

Write-Output "Msvm_GuestNetworkAdapterConfigurations is $Msvm_GuestNetworkAdapterConfigurations"
$Msvm_GuestNetworkAdapterConfiguration = ($Msvm_GuestNetworkAdapterConfigurations | % {$_})
$ConfigOld = $Msvm_GuestNetworkAdapterConfiguration.GetText(1)
Write-Output "Current Config is $ConfigOld"
#Set the IP address and related information
$Msvm_GuestNetworkAdapterConfiguration.DHCPEnabled = $false
$Msvm_GuestNetworkAdapterConfiguration.IPAddresses = $IPAddress
$Msvm_GuestNetworkAdapterConfiguration.Subnets = $NetMask
$Msvm_GuestNetworkAdapterConfiguration.DefaultGateways = $DefaultGateway
$Msvm_GuestNetworkAdapterConfiguration.DNSServers = $DNSServer

$Path = $Msvm_ComputerSystem.Path
# $Config = $Msvm_GuestNetworkAdapterConfiguration[0].GetText(1)
$Config = $Msvm_GuestNetworkAdapterConfiguration.GetText(1)
Write-Output "Msvm_ComputerSystem.Path is $Path"
Write-Output "NewConfig is $Config"

#Set the IP address
$Msvm_VirtualSystemManagementService.SetGuestNetworkAdapterConfiguration(
    $Msvm_ComputerSystem.Path,
   $Config)

#modified from https://learn.microsoft.com/en-us/archive/blogs/taylorb/setting-guest-ip-addresses-from-the-host