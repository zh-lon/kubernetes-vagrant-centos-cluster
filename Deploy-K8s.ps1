if ((Get-VMSwitch -SwitchName "k8s-Switch" -ErrorAction Ignore) -eq $null){
New-VMSwitch -SwitchName “k8s-Switch” -SwitchType Internal
New-NetIPAddress -IPAddress 172.17.8.1 -PrefixLength 24 -InterfaceIndex (Get-NetAdapter | ? {$_.Name -match "k8s-Switch"}).ifIndex `
 -AddressFamily IPv4
}

if((Get-NetNat | ? {$_.Name -match "K8s-NATNetwork"}) -eq $null){
New-NetNAT -Name “K8s-NATNetwork” -InternalIPInterfaceAddressPrefix 172.17.8.0/24
}

cd $PSScriptRoot
cmd /c "vagrant plugin install vagrant-reload"
cmd /c "vagrant up"
