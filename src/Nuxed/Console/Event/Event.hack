namespace Nuxed\Console\Event;

use namespace Nuxed\Console;
use namespace Nuxed\EventDispatcher\Event;

/**
 * Allows to inspect input and output of a command.
 */
class Event implements Event\IEvent {
  public function __construct(
    protected Console\Input\IInput $input,
    protected Console\Output\IOutput $output,
    protected ?Console\Command $command,
  ) {}

  public function getInput(): Console\Input\IInput {
    return $this->input;
  }

  public function getOutput(): Console\Output\IOutput {
    return $this->output;
  }

  public function getCommand(): ?Console\Command {
    return $this->command;
  }
}
