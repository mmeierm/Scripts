Install-Module Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes Application.ReadWrite.All, AppRoleAssignment.ReadWrite.All

$PermissionName = "DeviceManagementManagedDevices.Read.All" 
$PermissionName2 = "User.Read.All"
$PermissionName3 = "Machine.ReadWrite.All"
$SystemmanagedIdentity = "<INSERT SystemmanagedIdentity HERE>"

$GraphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$GraphServicePrincipal2 = Get-MgServicePrincipal -Filter "appId eq 'fc780465-2017-40d4-a0c5-307022471b92'"
$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
$AppRole2 = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName2 -and $_.AllowedMemberTypes -contains "Application"}
$AppRole3 = $GraphServicePrincipal2.AppRoles | Where-Object {$_.Value -eq $PermissionName3 -and $_.AllowedMemberTypes -contains "Application"}


New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $SystemmanagedIdentity -PrincipalId $SystemmanagedIdentity -ResourceId $GraphServicePrincipal.Id -Id $AppRole.Id -AppRoleId $AppRole.Id
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $SystemmanagedIdentity -PrincipalId $SystemmanagedIdentity -ResourceId $GraphServicePrincipal.Id -Id $AppRole2.Id -AppRoleId $AppRole2.Id
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $SystemmanagedIdentity -PrincipalId $SystemmanagedIdentity -ResourceId $GraphServicePrincipal2.Id -Id $AppRole3.Id -AppRoleId $AppRole3.Id