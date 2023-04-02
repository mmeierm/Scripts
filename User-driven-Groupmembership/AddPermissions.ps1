Install-Module Microsoft.Graph -Scope CurrentUser
Connect-MgGraph
Connect-AzureAD 

$PermissionName = "GroupMember.ReadWrite.All" 
$SystemmanagedIdentity = "<INSERT SYSTEMMANAGED IDENTITY ID HERE>"

$GraphServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
New-AzureAdServiceAppRoleAssignment -ObjectId $SystemmanagedIdentity -PrincipalId $SystemmanagedIdentity -ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id
