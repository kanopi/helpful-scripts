<?php

/**
 * The following script returns a CSV output of the modules that are installed on the
 * site, their current version, and if there is an update needed.
 * 
 * To run this in Drush put this in the private directory and usually the command will
 * execute like this.
 * 
 * Usage:
 *   drush php:script modules.php --script-path=sites/default/files/private/
 * 
 */

use Drupal\update\UpdateFetcherInterface;
use Drupal\update\UpdateManagerInterface;

$headers = [
	"Module",
	"Type",
	"Installed Version",
	"Recommended Version",
	"Security Release",
];

\Drupal::moduleHandler()->loadInclude("update", "compare.inc"); 
$data = update_calculate_project_data(update_get_available(TRUE));

$line = implode(",", array_fill(0, sizeof($headers), '"%s"'));

echo sprintf(
	$line,
	...$headers
) . PHP_EOL;

foreach ($data AS $project) {
  $fetch_failed = FALSE;
  if ($project['status'] === UpdateFetcherInterface::NOT_FETCHED) {
    $fetch_failed = TRUE;
  }


  // Filter out projects which are up to date already.
  if ($project['status'] == UpdateManagerInterface::CURRENT) {
    continue;
  }

  $title = $project['title'];
  $type = '';
  switch ($project['status']) {
    case UpdateManagerInterface::NOT_SECURE:
    case UpdateManagerInterface::REVOKED:
      $title .= ' ' . $this->t('(Security update)');
      $type = 'security';
      break;

    case UpdateManagerInterface::NOT_SUPPORTED:
      $type = 'unsupported';
      $title .= (' (Unsupported)');
      break;

    case UpdateFetcherInterface::UNKNOWN:
    case UpdateFetcherInterface::NOT_FETCHED:
    case UpdateFetcherInterface::NOT_CHECKED:
    case UpdateManagerInterface::NOT_CURRENT:
      $type = 'recommended';
      break;

    default:
      // Jump out of the switch and onto the next project in foreach.
      continue 2;
  }

  echo sprintf(
  	$line,
  	$title,
  	ucwords($type),
  	$project['existing_version'],
  	$project['recommended'],
  	$type == 'security' ? 'X' : ''
  ) . PHP_EOL;
}
