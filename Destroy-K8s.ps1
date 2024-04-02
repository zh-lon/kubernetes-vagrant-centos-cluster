cd $PSScriptRoot
cmd /c "vagrant destroy"
Remove-NetNAT -Name “K8s-NATNetwork” 
Remove-VMSwitch -SwitchName “k8s-Switch” 
    

