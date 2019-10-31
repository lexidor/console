namespace Nuxed\Console\CommandLoader;

use namespace HH\Lib\{C, Str, Vec};
use namespace Nuxed\Console;

/**
 * A simple command loader using factories to instantiate commands lazily.
 */
final class FactoryCommandLoader implements ICommandLoader {
  private dict<string, (function(): Console\Command)> $factories;

  public function __construct(
    KeyedContainer<string, (function(): Console\Command)> $factories,
  ) {
    $this->factories = dict<string, (function(): Console\Command)>($factories);
  }

  /**
   * Loads a command.
   */
  public function get(string $name): Console\Command {
    if (!$this->has($name)) {
      throw new Console\Exception\InvalidCommandException(
        Str\format('Command "%s" doesn\'t exists', $name),
      );
    }

    $factory = $this->factories[$name];
    return $factory();
  }

  /**
   * Checks if a command exists.
   */
  public function has(string $name): bool {
    return C\contains_key($this->factories, $name);
  }

  /**
   * @return string[] All registered command names
   */
  public function getNames(): Container<string> {
    return Vec\keys($this->factories);
  }
}
