namespace Nuxed\Console\Event;

use namespace Nuxed\Console;

/**
 * Allows to handle throwables thrown while running a command.
 */
final class ErrorEvent extends Event {
  private ?int $exitCode;

  public function __construct(
    Console\Input\IInput $input,
    Console\Output\IOutput $output,
    private \Throwable $error,
    ?Console\Command $command,
  ) {
    parent::__construct($input, $output, $command);
  }

  public function getError(): \Throwable {
    return $this->error;
  }

  public function setError(\Throwable $error): void {
    $this->error = $error;
  }

  public function setExitCode(int $exitCode): void {
    $this->exitCode = $exitCode;

    $r = new \ReflectionProperty($this->error, 'code');
    $r->setAccessible(true);
    $r->setValue($this->error, $this->exitCode);
  }

  public function getExitCode(): int {
    if ($this->exitCode is nonnull) {
      return $this->exitCode;
    }

    $code = $this->error->getCode();
    if ($code is int && $code !== 0) {
      return $code;
    }

    return 1;
  }
}
