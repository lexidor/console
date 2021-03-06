namespace Nuxed\Console\Event;

use namespace Nuxed\Console;

/**
 * Allows to manipulate the exit code of a command after its execution.
 */
final class TerminateEvent extends Event {
  private int $exitCode;

  public function __construct(
    Console\Input\IInput $input,
    Console\Output\IOutput $output,
    ?Console\Command $command,
    int $exitCode,
  ) {
    parent::__construct($input, $output, $command);
    $this->exitCode = $exitCode;
  }

  public function setExitCode(int $exitCode): void {
    $this->exitCode = $exitCode;
  }

  public function getExitCode(): int {
    return $this->exitCode;
  }
}
