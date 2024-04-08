if ((Get-VMSwitch -SwitchName "VLAN1-V" -ErrorAction Ignore) -eq $null){
New-VMSwitch -SwitchName “VLAN1-V” -SwitchType Internal
New-NetIPAddress -IPAddress 10.129.0.254 -PrefixLength 24 -InterfaceIndex (Get-NetAdapter | ? {$_.Name -match "k8s-Switch"}).ifIndex `
 -AddressFamily IPv4
}

if((Get-NetNat | ? {$_.Name -match "VLAN1-V"}) -eq $null){
New-NetNAT -Name “VLAN1-V” -InternalIPInterfaceAddressPrefix 10.129.0.0/16
}

cd $PSScriptRoot
cmd /c "vagrant plugin install vagrant-reload"
cmd /c "vagrant up"
