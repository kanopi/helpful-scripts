<?php

/**
 * The following script returns a CSV output of the modules their permissions that can
 * then be used to put in a csv file.
 * 
 * This can be remotely downloaded using the following commands:
 * 
 * export SCRIPT="https://raw.githubusercontent.com/kanopi/helpful-scripts/main/scripts/permissions.php";
 * drush php:eval "file_put_contents(\Drupal::service('file_system')->realpath("private://").'/'.basename('${SCRIPT}'), file_get_contents('${SCRIPT}'));"
 * 
 * To run this in Drush put this in the private directory and usually the command will
 * execute like this.
 * 
 * Usage:
 *   drush php:script permissions.php --script-path=sites/default/files/private/
 * 
 */

$headers = [
	"Module",
	"Permission",
	"Sensitive",
	"Roles",
];

function permissionsByProvider(): array {
    $permissions = \Drupal::service('user.permissions')->getPermissions();
    $permissions_by_provider = [];
    foreach ($permissions as $permission_name => $permission) {
      $permissions_by_provider[$permission['provider']][$permission_name] = $permission;
    }

    // Move the access content permission to the Node module if it is installed.
    // @todo Add an alter so that this section can be moved to the Node module.
    if (\Drupal::service('module_handler')->moduleExists('node')) {
      // Insert 'access content' before the 'view own unpublished content' key
      // in order to maintain the UI even though the permission is provided by
      // the system module.
      $keys = array_keys($permissions_by_provider['node']);
      $offset = (int) array_search('view own unpublished content', $keys);
      $permissions_by_provider['node'] = array_merge(
        array_slice($permissions_by_provider['node'], 0, $offset),
        ['access content' => $permissions_by_provider['system']['access content']],
        array_slice($permissions_by_provider['node'], $offset)
      );
      unset($permissions_by_provider['system']['access content']);
    }

    return $permissions_by_provider;
}

function getRoles(): array {
	$roles = \Drupal::entityTypeManager()->getStorage('user_role')->loadMultiple();
	$role_names = [];
    foreach ($roles as $role_name => $role) {
      // Retrieve role names for columns.
      $role_names[$role_name] = [
      	'label' => $role->label(), 
      	'permissions' => $role->getPermissions(),
      	'admin' => $role->isAdmin(),
  	  ];
    }

    return $role_names;
}


function permissionRoles($roles, $perm): string {
	$filteredRoles = array_filter($roles, function($var) use ($perm) {
		return in_array($perm, $var['permissions']) || $var['admin'];
	});

	return implode('; ', array_map(function ($value) {
		return $value['label'];
	}, $filteredRoles));	

}

$roles = getRoles();

$line = implode(",", array_fill(0, sizeof($headers), '"%s"'));

echo sprintf(
	$line,
	...$headers
) . PHP_EOL;

foreach (permissionsByProvider() AS $provider => $permissions) {
	$moduleName = \Drupal::service('module_handler')->getName($provider);
	foreach ($permissions AS $perm => $perm_item) {
		echo sprintf(
			$line,
			$moduleName,
			strip_tags($perm_item['title']),
			!empty($perm_item['restrict access']) ? 'X' : '',
			permissionRoles($roles, $perm)
		) . PHP_EOL;
	}
}
