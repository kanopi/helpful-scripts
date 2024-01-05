<?php

/**
 * The following script returns a CSV output of the users and their roles.
 * 
 * This can be remotely downloaded using the following commands:
 * 
 * export SCRIPT="https://raw.githubusercontent.com/kanopi/helpful-scripts/main/scripts/users.php";
 * drush php:eval "file_put_contents(\Drupal::service('file_system')->realpath("private://").'/'.basename('${SCRIPT}'), file_get_contents('${SCRIPT}'));"
 * 
 * To run this in Drush put this in the private directory and usually the command will
 * execute like this.
 * 
 * Usage:
 *   drush php:script users.php --script-path=sites/default/files/private/
 * 
 */


$headers = [
	"Username",
	"Email",
	"Active",
	"Roles",
	"Created",
	"Last Active",
];

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

$userStorage = \Drupal::entityTypeManager()->getStorage('user');

$query = $userStorage->getQuery();
$uids = $query
	->accessCheck(TRUE)
	->condition('uid', '0', '>')
	->sort('access', 'DESC')
	->execute();

$users = $userStorage->loadMultiple($uids);

$roles = getRoles();

$line = implode(",", array_fill(0, sizeof($headers), '"%s"'));

echo sprintf(
	$line,
	...$headers
) . PHP_EOL;

foreach ($users AS $user) {
	echo sprintf(
		$line,
		$user->getAccountName(),
		$user->getEmail(),
		$user->isActive() ? 'X' : '',
		implode('; ', array_map(function($role) use ($roles) { return $roles[$role]['label']; }, $user->getRoles(true))),
		$user->getLastLoginTime() != 0 ? date('m/d/Y H:i:s', $user->getLastLoginTime()) : '',
		$user->getLastAccessedTime() != 0 ? date('m/d/Y H:i:s', $user->getLastAccessedTime()) : ''
	) . PHP_EOL;
}
