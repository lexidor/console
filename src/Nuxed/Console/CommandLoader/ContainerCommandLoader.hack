namespace Nuxed\Console\CommandLoader;

use namespace Nuxed\Console;
use namespace His\Container;
use namespace HH\Lib\{C, Str, Vec};

final class ContainerCommandLoader implements ICommandLoader {
  private dict<string, classname<Console\Command>> $commandMap;

  public function __construct(
    private Container\ContainerInterface $container,
    KeyedContainer<string, classname<Console\Command>> $commandMap,
  ) {
    $this->commandMap = dict<string, classname<Console\Command>>($commandMap);
  }

  /**
   * Loads a command.
   */
  public function get(string $name): Console\Command {
    if (!$this->has($name)) {
      throw new Console\Exception\InvalidCommandException(
        Str\format('Command "%s" does not exists', $name),
      );
    }

    return $this->container->get<Console\Command>($this->commandMap[$name]);
  }

  /**
   * Checks if a command exists.
   */
  public function has(string $name): bool {
    if (
      !C\contains_key<string, string, classname<Console\Command>>(
        $this->commandMap,
        $name,
      )
    ) {
      return false;
    }

    return $this->container->has<Console\Command>($this->commandMap[$name]);
  }

  /**
   * @return string[] All registered command names
   */
  public function getNames(): Container<string> {
    return Vec\keys<string, classname<Console\Command>>($this->commandMap);
  }
}
