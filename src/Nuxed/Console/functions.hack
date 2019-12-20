namespace Nuxed\Console;

use namespace HH;
use namespace HH\Lib\{C, Vec};

function argv(): vec<string> {
  $argv = HH\global_get('argv') as Traversable<_>;
  $arguments = vec[];
  foreach ($argv as $argument) {
    $arguments[] = $argument as string;
  }

  return Vec\drop<string>($arguments, 1);
}

function argc(): int {
  return C\count(argv());
}
