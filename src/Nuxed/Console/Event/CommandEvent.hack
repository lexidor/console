namespace Nuxed\Console\Event;

/**
 * Allows to do things before the command is executed, like skipping the command or changing the input.
 */
final class CommandEvent extends Event {
  /**
   * The return code for skipped commands, this will also be passed into the terminate event.
   */
  const int RETURN_CODE_DISABLED = 113;

  /**
   * Indicates if the command should be run or skipped.
   */
  private bool $commandShouldRun = true;

  /**
   * Disables the command, so it won't be run.
   */
  public function disableCommand(): bool {
    return $this->commandShouldRun = false;
  }

  /**
   * Enable the command, so it would run.
   */
  public function enableCommand(): bool {
    return $this->commandShouldRun = true;
  }

  /**
   * Returns true if the command is runnable, false otherwise.
   */
  public function commandShouldRun(): bool {
    return $this->commandShouldRun;
  }
}
