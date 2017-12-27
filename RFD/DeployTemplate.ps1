<#############################################################
 #                                                           #
 # DeployTemplate.ps1										 #
 #                                                           #
 #############################################################>

<#
 .Synopsis
	The script creates a new resource group in Azure subscription and deploys resources based on given template file and parameters file.

 .Requirements
	Azure PowerShell modules must be installed in order to run the script.
 .Parameter ResourceGroupLocation
	Sets Azure region for the deployment. Default region is 'westeurope'.
 .Parameter DeployIndex
	Sets a number for the deployment iteration.
 .Parameter ResourceGroupPrefix
	Used to form resource group name and deployment name.  
 .Parameter AzureUserName
	Azure Active Directory tenant user name. This account is used to deploy all resources and should have necessary permissions. 
 .Parameter AzureUserPassword
	Azure Active Directory tenant password.
 .Parameter TemplateUri
    Template file location.
 .Parameter TemplateParameterUri
    Template parameter file location.
 .Parameter DeleteOnly
    If this parameter is set to 'true' the script will only delete resource group. No deployments will be started. Default value is 'false'.   

.Example
     If no parameters are provided, default values are used.

     .\DeployTemplate.ps1 

.Example
     This example creates 'Test-RG02' resource group in West Europe region and starts deployment with the name 'Test-RG-Dep02'.

     .\DeployTemplate.ps1 -ResourceGroupLocation 'westeurope' -DeployIndex '02' -ResourceGroupPrefix 'Test-RG' -AzureUserName 'admin@mytenant.onmicrosoft.com' -AzureUserPassword 'P@ssw0rd!@#$%'
     
.Example
     This example checks is there 'Test-RG02' resource group in Azure subcription. If yes, the script will delete that resource group. No any deployments will be started.
     
     .\DeployTemplate.ps1 -DeployIndex '02' -ResourceGroupPrefix 'Test-RG' -DeleteOnly $true 
        
#>


Param(
	[string] $ResourceGroupLocation = "westeurope",
	[string] $DeployIndex = "",
	[string] $ResourceGroupPrefix = "RFD-RG",
	[string] $AzureUserName = "<admin name>@<tenant name>.onmicrosoft.com",
	[string] $AzureUserPassword = "<admin password>",
    [string] $TemplateUri = "https://raw.githubusercontent.com/ashapoms/RFD/master/RFD/azuredeploy.json",
    [string] $TemplateParameterUri = "https://raw.githubusercontent.com/ashapoms/RFD/master/RFD/azuredeploy.parameters.json",
    [boolean] $DeleteOnly = $false 
)



<#############################################################
 #
 # Function definition
 #
 #############################################################>

function DeleteRG 
{
    Remove-AzureRmResourceGroup -Name $ResourceGroupName -Verbose -Force
    Write-Host 'Resource group ' -NoNewline
    Write-Host @($ResourceGroupName) -BackgroundColor Green -ForegroundColor Black -NoNewline
    Write-Host ' was deleted'
}

function StartDeployment  
{
    # Create a new resource group in given location
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force
    
    # Start a new deployment in created resource group
    New-AzureRmResourceGroupDeployment  -Name $DeploymentName `
                                        -ResourceGroupName $ResourceGroupName `
                                        -TemplateUri $TemplateUri `
                                        -TemplateParameterUri $TemplateParameterUri `
                                        -Verbose
                                        
    # Log public IP Address of Master VM.
    # It's only way if IP Address allocation method is 'dynamic'.
    # For 'static' allocation method you can find public IP Address in 'Outputs' template section as well
    $MasterIpAddress = Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName
    Write-Host 'Public IP Address of Master VM is ' -NoNewline
    Write-Host @($MasterIpAddress.IpAddress) -BackgroundColor Green -ForegroundColor Black
}



<#############################################################
 #
 # Login to Azure and deployment 
 #
 #############################################################>


# Prepare credentials and login to Azure subscription 
$AadPass = ConvertTo-SecureString $AzureUserPassword -AsPlainText -Force
$AadCred = New-Object System.Management.Automation.PSCredential ($AzureUserName, $AadPass)

# Login to Azure subscription 
Login-AzureRmAccount -Credential $AadCred

# Prepare resource group name and deploument name 
$ResourceGroupName = $ResourceGroupPrefix + $DeployIndex
$DeploymentName = $ResourceGroupPrefix + "-Dep" + $DeployIndex


# Check is there resource group with the given name in Azure subscription  
$CurrentRG = (Get-AzureRmResourceGroup | Where-Object{$_.ResourceGroupName -eq $ResourceGroupName})

if ($DeleteOnly)
{
    if ($CurrentRG -ne $null)
    {
        Write-Host 'Resource group with the name ' -NoNewline
        Write-Host @($CurrentRG.ResourceGroupName) -BackgroundColor Green -ForegroundColor Black -NoNewline
        Write-Host ' will be deleted'
        Write-Host 'Please wait...'
        DeleteRG
    }
    else
    {
        Write-Host 'Resource group with the name ' -NoNewline
        Write-Host @($ResourceGroupName) -BackgroundColor Green -ForegroundColor Black -NoNewline
        Write-Host ' does not exist' 
    }
}
else
{
    if ($CurrentRG -ne $null)
    {
        Write-Host 'Resource group with the name ' -NoNewline
        Write-Host @($CurrentRG.ResourceGroupName) -BackgroundColor Green -ForegroundColor Black -NoNewline
        Write-Host ' already exists and will be deleted'
        Write-Host 'Please wait...'
        DeleteRG
        
        Write-Host 'Creating resource group and starting deployment...'
        StartDeployment        
    }
    else
    {
        Write-Host 'Creating resource group and starting deployment...'
        StartDeployment
    }
}