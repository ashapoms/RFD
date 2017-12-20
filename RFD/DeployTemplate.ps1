#
# DeployTemplate.ps1
#
# The script creates resource group and deploy ARM template
#

$aadpass = ConvertTo-SecureString "<subscription_admin_password>" -AsPlainText -Force
$aadcred = New-Object System.Management.Automation.PSCredential ("<admin_name>@<tenant_name>.onmicrosoft.com", $aadpass)

#Add-AzureRmAccount
Login-AzureRmAccount -Credential $aadcred

$DeployIndex = "201"
$ResourceGroupName = "RFD-RG" + $DeployIndex
$ResourceGroupLocation = "westeurope"
$RFDDeploymentName = "RFD-Dep" + $DeployIndex

$TemplateUri = "https://raw.githubusercontent.com/ashapoms/RFD/master/RFD/azuredeploy.json"
$TemplateParameterUri = "https://raw.githubusercontent.com/ashapoms/RFD/master/RFD/azuredeploy.parameters.json"

New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force

New-AzureRmResourceGroupDeployment -Name $RFDDeploymentName `
                                       -ResourceGroupName $ResourceGroupName `
                                       -TemplateUri $TemplateUri `
                                       -TemplateParameterUri $TemplateParameterUri `
                                       -Verbose 

# Remove-AzureRmResourceGroup -Name $ResourceGroupName -Verbose -Force



# $TemplateFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\openwbVMs.json"
# $TemplateParametersFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\openwbVMs.parameters.json"
# $TemplateFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\sqlVM.json"
# $TemplateParametersFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\sqlVM.parameters.json"
# $TemplateFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\sqlMultiVMs.json"
# $TemplateParametersFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\sqlMultiVMs.parameters.json"
# $TemplateFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\gateVMSS.json"
# $TemplateParametersFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\gateVMSS.parameters.json"
# $TemplateFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\gateSS.json"
# $TemplateParametersFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\gateSS.parameters.json"
# $TemplateFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\loadVM.json"
# $TemplateParametersFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\loadVM.parameters.json"
# $TemplateFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\stubVM.json"
# $TemplateParametersFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\stubVM.parameters.json"

# $TemplateFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\openWb.json"
# $TemplateParametersFile = "C:\Users\ashapo\Work Folders\DPE\VS\OpenArm\open-wb\open-wb-infra\open-wb-infra\openWb.parameters.json"


# New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force

<#
New-AzureRmResourceGroupDeployment -Name $OpenDeploymentName `
                                       -ResourceGroupName $ResourceGroupName `
                                       -TemplateFile $TemplateFile `
                                       -TemplateParameterFile $TemplateParametersFile `
                                       -Verbose
#>