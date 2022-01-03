Param (
    [Parameter(Mandatory = $true)]
    [string]
    $AzureUserName,

    [string]
    $AzurePassword,

    [string]
    $domainName 
  
)

Install-Module AzureAD -Force

#Connect to the user account
$userName = $AzureUserName
$password = $AzurePassword
$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $SecurePassword

Connect-AzAccount -Credential $cred | Out-Null

$VnetName = "aadds-vnet"
$templateSourceLocation = "https://raw.githubusercontent.com/akhilthomas011/ARMTemplates/main/ADDS/deploy.json"


#Start creating Prerequisites 
#Register the provider 
Register-AzResourceProvider -ProviderNamespace Microsoft.AAD 

if(!($AADDSServicePrincipal = Get-AzADServicePrincipal -ApplicationId "2565bd9d-da50-47d4-8b85-4c97f669dc36")){ 
$AADDSServicePrincipal = New-AzADServicePrincipal -ApplicationId "2565bd9d-da50-47d4-8b85-4c97f669dc36" -ea SilentlyContinue} 

if(!($AADDSGroup = Get-AzADGroup -DisplayName "AAD DC Administrators")) 
{$AADDSGroup = New-AzADGroup -DisplayName "AAD DC Administrators" -Description "Delegated group to administer Azure AD Domain Services" -MailNickName "AADDCAdministrators" -ea SilentlyContinue}  


# Add the user to the 'AAD DC Administrators' group. 
Add-AzADGroupMember -MemberUserPrincipalName $AzureUserName -TargetGroupObjectId $($AADDSGroup).Id -ea SilentlyContinue  

#Get RG Name 
$resourceGroupName = "AVD-RG"
$location = "eastus"  
$Params = @{ 

     "domainName" = $domainName 

} 

 
#Deploy the AADDS template 
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateUri $templateSourceLocation -TemplateParameterObject $Params #Deploy the template #Update Virtual Network DNS servers 

#Update Virtual Network DNS servers 
$Vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $resourceGroupName 
$Vnet.DhcpOptions.DnsServers = @() 
$NICs = Get-AzResource -ResourceGroupName $resourceGroupName -ResourceType "Microsoft.Network/networkInterfaces" -Name "aadds*" 
ForEach($NIC in $NICs){ 
$Nicip = (Get-AzNetworkInterface -Name $($NIC.Name) -ResourceGroupName $resourceGroupName).IpConfigurations[0].PrivateIpAddress
 ($Vnet.DhcpOptions.DnsServers).Add($Nicip) 

} 

$Vnet | Set-AzVirtualNetwork    

#Reset user password  

Connect-AzureAD -Credential $cred | Out-Null
#$securePassword2 = $AzureNewPassword | ConvertTo-SecureString -AsPlainText -Force
Set-AzureADUserPassword -ObjectId  (Get-AzADUser -UserPrincipalName $AzureUserName).Id -Password $securePassword
