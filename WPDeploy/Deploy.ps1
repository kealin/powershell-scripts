#
# Script to spin up Ubuntu Server VM, configure NSG and network
#

# Get required info
$defaultRG = 'MyVMRG1'
$rg = Read-Host "Input resource group name [$($defaultRG)]"
$rg = ($defaultRG,$rg)[[bool]$rg]

$defaultLoc = 'northeurope'
$loc = Read-Host "Input resource group location [$($defaultLoc)]"
$loc = ($defaultLoc,$loc)[[bool]$loc]

$defaultNSG = 'MyVMNSG'
$nsgName = Read-Host "Input NSG name [$($defaultNSG)]"
$nsgName = ($defaultNSG,$nsgName)[[bool]$nsgName]

$defaultNIC = 'MyVMNIC'
$nicName = Read-Host "Input NIC name [$($defaultNIC)]"
$nicName = ($defaultNIC,$nicName)[[bool]$nicName]

$defaultVN = 'MyVMVNET'
$vnetName = Read-Host "Input vNET name [$($defaultVN)]"
$vnetName = ($defaultVN,$vnetName)[[bool]$vnetName]

$defaultSubnetName = 'MyVMSubnet'
$subnetName = Read-Host "Input vNET name [$($DefaultSubnetName)]"
$vnetName = ($DefaultSubnetName,$vnetName)[[bool]$vnetName]

$defaultDnsName = 'MyVMDNS'
$dnsName = Read-Host "Input DNS name [$($defaultDnsName)]"
$dnsName = ($defaultDnsName,$dnsName)[[bool]$dnsName]

$defaultVmUserName = 'ubuntu'
$vmUserName = Read-Host "Input VM username [$($defaultVmUserName)]"
$vmUserName = ($defaultVmUserName,$vmUserName)[[bool]$vmUserName]

$defaultVM = 'vm1'
$vm = Read-Host "Input VM name [$($defaultVM)]"
$vm = ($defaultVM,$vm)[[bool]$vm]

Login-AzureRmAccount

# Create a resource group
New-AzureRmResourceGroup -Name $rg -Location $loc

# Create a subnet configuration
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix 192.168.1.0/24

# Create a virtual network
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $rg -Location $loc `
  -Name $vnetName -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig

# Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $rg -Location $loc `
  -Name "$dnsName" -AllocationMethod Static -IdleTimeoutInMinutes 4

# Create an inbound network security group rule for port 22
$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig -Name $nsgName  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange 22 -Access Allow

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $rg -Location $loc `
  -Name $nsgName -SecurityRules $nsgRuleSSH

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $rg -Location $loc `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

# Create a virtual machine configuration
$vmConfig = New-AzureRmVMConfig -VMName $vm -VMSize Standard_D1 | `
Set-AzureRmVMOperatingSystem -Linux -ComputerName $vm -Credential $cred -DisablePasswordAuthentication | `
Set-AzureRmVMSourceImage -PublisherName Canonical -Offer UbuntuServer -Skus 16.04.0-LTS -Version latest | `
Add-AzureRmVMNetworkInterface -Id $nic.Id

# Configure SSH Keys
$sshPublicKey = Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"
Add-AzureRmVMSshPublicKey -VM $vmconfig -KeyData $sshPublicKey -Path "/home/$($($vmUserName))/.ssh/authorized_keys"

# Create a virtual machine
New-AzureRmVM -ResourceGroupName $rg -Location $loc -VM $vmConfig

