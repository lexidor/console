namespace Nuxed\Console;

use namespace Nuxed\Environment;
use namespace HH\Lib\Str;
use namespace HH\Lib\Experimental\IO;

class Terminal {

  protected IO\ReadHandle $stdin;

  protected IO\WriteHandle $stdout;

  protected IO\WriteHandle $stderr;

  private ?bool $decorated;

  public function __construct(
    private bool $forceAnsi = false,
    IO\ReadHandle $stdin = IO\request_input(),
    IO\WriteHandle $stdout = IO\request_output(),
    ?IO\WriteHandle $stderr = IO\request_error(),
  ) {
    $this->stdin = $stdin;
    $this->stdout = $stdout;
    $this->stderr = $stderr ?? $stdout;
  }

  /**
   * Return the handle for standard input.
   */
  public function getInputHandle(): IO\ReadHandle {
    return $this->stdin;
  }

  /**
   * Return the handle for standard output.
   */
  public function getOutputHandle(): IO\WriteHandle {
    return $this->stdout;
  }

  /**
   * Return the handle for standard error.
   */
  public function getErrorHandle(): IO\WriteHandle {
    return $this->stderr;
  }

  /**
   * Sets the decorated flag.
   */
  public function setDecorated(bool $decorated): this {
    $this->decorated = $decorated;

    return $this;
  }

  /**
   * Gets the decorated flag.
   *
   * @return bool true if the output will decorate messages, false otherwise
   */
  public function isDecorated(): bool {
    if ($this->decorated is nonnull) {
      return $this->decorated;
    }

    $colors = Environment\get('CLICOLORS');
    if ($colors is nonnull) {
      if (
        $colors === '1' ||
        $colors === 'yes' ||
        $colors === 'true' ||
        $colors === 'on'
      ) {
        $this->decorated = true;
        return $this->decorated;
      }

      if (
        $colors === '0' ||
        $colors === 'no' ||
        $colors === 'false' ||
        $colors === 'off'
      ) {
        $this->decorated = false;
        return $this->decorated;
      }
    }

    if (Environment\get('TRAVIS') is nonnull) {
      $this->decorated = true;
      return $this->decorated;
    }

    if (Environment\get('CIRCLECI') is nonnull) {
      $this->decorated = true;
      return $this->decorated;
    }

    if (Environment\get('TERM') === 'xterm') {
      $this->decorated = true;
      return $this->decorated;
    }

    if (Environment\get('TERM_PROGRAM') === 'Hyper') {
      $this->decorated = true;
      return $this->decorated;
    }

    if ($this->isInteractive()) {
      $this->decorated = Str\contains_ci(
        Environment\get('TERM', '') as string,
        'color',
      );
      return $this->decorated;
    }

    $this->decorated = false;
    return $this->decorated;
  }

  /**
   * Determines whether the current terminal is in interactive mode.
   *
   * In general, this is `true` if the user is directly typing into stdin.
   */
  <<__Memoize>>
  public function isInteractive(): bool {
    $noninteractive = Environment\get('NONINTERACTIVE');
    if ($noninteractive is nonnull) {
      if (
        $noninteractive === '1' ||
        $noninteractive === 'true' ||
        $noninteractive === 'yes'
      ) {
        return false;
      }

      if (
        $noninteractive === '0' ||
        $noninteractive === 'false' ||
        $noninteractive === 'no'
      ) {
        return true;
      }
    }

    // Detects TravisCI and CircleCI; Travis gives you a TTY for STDIN
    $ci = Environment\get('CI');
    if ($ci === '1' || $ci === 'true') {
      return false;
    }

    // Generic
    if (\posix_isatty(\STDIN) && \posix_isatty(\STDOUT)) {
      return true;
    }

    // Fail-safe
    return false;
  }

  /**
   * Retrieve the height of the current terminal window.
   */
  public function getHeight(): int {
    $output = null;
    $ret = null;
    \exec('tput lines', inout $output, inout $ret);

    return (int)$output[0];
  }

  /**
   * Retrieve the width of the current terminal window.
   */
  public function getWidth(): int {
    $output = null;
    $ret = null;
    \exec('tput cols', inout $output, inout $ret);

    return (int)$output[0];
  }
}
