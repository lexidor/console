namespace Nuxed\Console\CommandLoader;

use namespace Nuxed\Console\{Command, Exception};
use namespace His\Container;
use namespace HH\Lib\{C, Str, Vec};

final class ContainerCommandLoader implements ICommandLoader {
  private dict<string, classname<Command\Command>> $commandMap;

  public function __construct(
    private Container\ContainerInterface $container,
    KeyedContainer<string, classname<Command\Command>> $commandMap,
  ) {
    $this->commandMap = dict<string, classname<Command\Command>>($commandMap);
  }

  /**
   * Loads a command.
   */
  public function get(string $name): Command\Command {
    if (!$this->has($name)) {
      throw new Exception\InvalidCommandException(
        Str\format('Command "%s" does not exists', $name),
      );
    }

    return $this->container->get<Command\Command>($this->commandMap[$name]);
  }

  /**
   * Checks if a command exists.
   */
  public function has(string $name): bool {
    if (
      !C\contains_key<string, string, classname<Command\Command>>(
        $this->commandMap,
        $name,
      )
    ) {
      return false;
    }

    return $this->container->has<Command\Command>($this->commandMap[$name]);
  }

  /**
   * @return string[] All registered command names
   */
  public function getNames(): Container<string> {
    return Vec\keys<string, classname<Command\Command>>($this->commandMap);
  }
}
