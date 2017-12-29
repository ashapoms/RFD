# Deploying an infrastructure for Torque cluster and tNavigator
 
 These ARM template and scripts deploy master VM and worker nodes that intended for installing and configuring Torque cluster and tNavigator solution.
 But basically, the infrastructure can be used for any other appropriate tasks. 

 [DeployTemplate.ps1](https://github.com/ashapoms/RFD/blob/master/RFD/DeployTemplate.ps1) creates a new resource group in Azure subscription and deploys resources based on given template file and parameters file.
 
 ### Requirements
[Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/overview?view=azurermps-5.1.1) modules must be installed in order to run the script.
 ### Parameters description 
 **ResourceGroupLocation**
 Sets Azure region for the deployment. Default region is 'westeurope'.
 **DeployIndex**
 Sets a number for the deployment iteration.
 **ResourceGroupPrefix**
 Used to form resource group name and deployment name.  
 **AzureUserName**
 Azure Active Directory tenant user name. This account is used to deploy all resources and should have necessary permissions. 
 **AzureUserPassword**
 Azure Active Directory tenant password.
 **TemplateUri**
 Template file location.
 **TemplateParameterUri**
 Template parameter file location.
 **DeleteOnly**
 If this parameter is set to 'true' the script will only delete resource group. No deployments will be started. Default value is 'false'.   

 ### Examples
1. If no parameters are provided, default values are used.
```
.\DeployTemplate.ps1 
```
.Example
     This example creates 'Test-RG02' resource group in West Europe region and starts deployment with the name 'Test-RG-Dep02'.

     .\DeployTemplate.ps1 -ResourceGroupLocation 'westeurope' -DeployIndex '02' -ResourceGroupPrefix 'Test-RG' -AzureUserName 'admin@mytenant.onmicrosoft.com' -AzureUserPassword 'P@ssw0rd!@#$%'
     
.Example
     This example checks is there 'Test-RG02' resource group in Azure subcription. If yes, the script will delete that resource group. No any deployments will be started.
     
     .\DeployTemplate.ps1 -DeployIndex '02' -ResourceGroupPrefix 'Test-RG' -DeleteOnly $true 
