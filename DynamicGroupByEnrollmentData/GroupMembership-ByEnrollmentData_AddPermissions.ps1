Install-Module Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes Application.ReadWrite.All, AppRoleAssignment.ReadWrite.All

$PermissionName = "GroupMember.ReadWrite.All" 
$PermissionName2 = "Device.Read.All"
$PermissionName3 = "DeviceManagementManagedDevices.Read.All"
$SystemmanagedIdentity = "be166005-7100-454c-855c-01c4d63f2cdd" #"<INSERT SYSTEMMANAGED IDENTITY ID HERE>"

$GraphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
$AppRole2 = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName2 -and $_.AllowedMemberTypes -contains "Application"}
$AppRole3 = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName3 -and $_.AllowedMemberTypes -contains "Application"}


New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $SystemmanagedIdentity -PrincipalId $SystemmanagedIdentity -ResourceId $GraphServicePrincipal.Id -Id $AppRole.Id -AppRoleId $AppRole.Id
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $SystemmanagedIdentity -PrincipalId $SystemmanagedIdentity -ResourceId $GraphServicePrincipal.Id -Id $AppRole2.Id -AppRoleId $AppRole2.Id
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $SystemmanagedIdentity -PrincipalId $SystemmanagedIdentity -ResourceId $GraphServicePrincipal.Id -Id $AppRole3.Id -AppRoleId $AppRole3.Id
