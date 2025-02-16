Install-Module Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes Application.ReadWrite.All, AppRoleAssignment.ReadWrite.All

$PermissionName = "DeviceManagementServiceConfig.ReadWrite.All" 
$SystemmanagedIdentity = "<INSERT SYSTEMMANAGED IDENTITY ID HERE>"

$GraphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}

New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $SystemmanagedIdentity -PrincipalId $SystemmanagedIdentity -ResourceId $GraphServicePrincipal.Id -Id $AppRole.Id -AppRoleId $AppRole.Id
