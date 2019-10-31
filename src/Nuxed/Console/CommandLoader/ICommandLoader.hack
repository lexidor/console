namespace Nuxed\Console\CommandLoader;

use namespace Nuxed\Console;

interface ICommandLoader {
  /**
   * Loads a command.
   */
  public function get(string $name): Console\Command;

  /**
   * Checks if a command exists.
   */
  public function has(string $name): bool;

  /**
   * @return string[] All registered command names
   */
  public function getNames(): Container<string>;
}
