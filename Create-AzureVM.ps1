#region Connect
Add-AzureAccount

# Switch to the Resource Manager mode   
Switch-AzureMode AzureResourceManager
Select-AzureSubscription "FH-Azure-QNH01"
#endregion

#region Variables
# Collect desired local admin credentials
$cred = Get-Credential -Message "Type the name and password of the local administrator account." 

# Specify the name and size for the new VM
$vmName = "FH-VM-DB03"
$vmSize = "Standard_A1"

# Specify the name for the new Availability Set
$avName = "FH-AS-DBPROD01"
$createavSet = $false

# Specify the existing VNET en subnet to place the VM in
$vnetName = "FH-VNET-GENERIC01"
$subnetName = "FH-PRD-BACK01"
$privateIP =  "172.30.40.7"

# Set values for existing resource group and storage account names
$rgName = "FH-RG01"
$locName = "WestEurope"

# Storage Account
$saName = "fhstoragelow" #lowercase!
$diskSize = 200 #App disk size in GB
#endregion

#region ScriptCode
# Get the existing virtual network and subnet index
$vnet = Get-AzurevirtualNetwork -Name $vnetName -ResourceGroupName $rgName
$subnet = $vnet.subnets | where {$_.name -eq $subnetName}

# Configure the availability set
If ($createavSet){$avs = New-AzureAvailabilitySet -Name $avName -ResourceGroupName $rgName -Location $locName}

# Get AvailabilitySet informtion and create a new VM config
If ($avName){$avSet = Get-AzureAvailabilitySet –Name $avName –ResourceGroupName $rgName}
If ($avName){$vm = New-AzureVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetId $avset.Id}
If (-not $avName) {$vm = New-AzureVMConfig -VMName $vmName -VMSize $vmSize}

# Create the NIC
$nicName = $vmName + "-NIC-0"
$nic = New-AzureNetworkInterface -Name $nicName -ResourceGroupName $rgName -Location $locName -SubnetId $subnet.Id -PrivateIpAddress $privateIP

# Add an additional data disk
$diskName = "-disk-1"
$diskLabel = $vmName + $diskName
$storageAccDataDisk = Get-AzureStorageAccount -ResourceGroupName $rgName -Name $saName
$vhdURI = $storageAccDataDisk.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName + $diskName  + ".vhd"
Add-AzureVMDataDisk -VM $vm -Name $diskLabel -DiskSizeInGB $diskSize -VhdUri $vhdURI -CreateOption empty -Lun 0

# Specify the image and local administrator account, and then add the NIC
$pubName = "MicrosoftWindowsServer"
$offerName = "WindowsServer"
$skuName = "2012-R2-Datacenter"
$vm = Set-AzureVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $cred -ProvisionVMAgent #-EnableAutoUpdate
$vm = Set-AzureVMSourceImage -VM $vm -PublisherName $pubName -Offer $offerName -Skus $skuName -Version "latest"
$vm = Add-AzureVMNetworkInterface -VM $vm -Id $nic.Id

# Specify the OS disk name and create the VM
$storageAcc = Get-AzureStorageAccount -ResourceGroupName $rgName -Name $saName
$osDiskUri = $storageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName + ".vhd"
$vm = Set-AzureVMOSDisk -VM $vm -Name $vmName -VhdUri $osDiskUri -CreateOption fromImage
New-AzureVM -ResourceGroupName $rgName -Location $locName -VM $vm
#endregion
