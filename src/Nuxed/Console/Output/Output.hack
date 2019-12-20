namespace Nuxed\Console\Output;

use namespace HH\Lib\Experimental\IO;
use namespace Nuxed\Console;
use namespace Nuxed\Console\Formatter;

final class Output implements IOutput {
  /**
   * Flag to determine if we should never output ANSI.
   */
  protected bool $suppressAnsi = false;

  /**
   * The global verbosity level for the `Output`.
   */
  protected Verbosity $verbosity;

  private Console\Terminal $terminal;

  private Formatter\IFormatter $formatter;

  /**
   * Construct a new `Output` object.
   */
  public function __construct(
    Verbosity $verbosity = Verbosity::Normal,
    ?Console\Terminal $terminal = null,
    ?Formatter\IFormatter $formatter = null,
  ) {
    $terminal ??= new Console\Terminal();
    $this->terminal = $terminal;
    $this->formatter = $formatter ?? new Formatter\Formatter($terminal);
    $this->verbosity = $verbosity;
  }

  /**
   * {@inheritdoc}
   */
  public function format(string $message, Type $type = Type::Normal): string {
    switch ($type) {
      case Type::Normal:
        return $this->formatter->format($message);
      case Type::Raw:
        return $message;
      case Type::Plain:
        return \strip_tags($this->formatter->format($message));
    }
  }

  /**
   * {@inheritdoc}
   */
  public async function writeln(
    string $message,
    Verbosity $verbosity = Verbosity::Normal,
    Type $type = Type::Normal,
  ): Awaitable<void> {
    await $this->writeTo(
      $this->terminal->getOutputHandle(),
      $message.IOutput::EndOfLine,
      $verbosity,
      $type,
    );
  }

  /**
   * {@inheritdoc}
   */
  public async function write(
    string $message,
    Verbosity $verbosity = Verbosity::Normal,
    Type $type = Type::Normal,
  ): Awaitable<void> {
    await $this->writeTo(
      $this->terminal->getOutputHandle(),
      $message,
      $verbosity,
      $type,
    );
  }

  /**
   * {@inheritdoc}
   */
  public async function error(
    string $message,
    Verbosity $verbosity = Verbosity::Normal,
    Type $type = Type::Normal,
  ): Awaitable<void> {
    await $this->writeTo(
      $this->terminal->getErrorHandle(),
      $message,
      $verbosity,
      $type,
    );
  }

  /**
   * @ignore
   */
  private async function writeTo(
    IO\WriteHandle $handle,
    string $message,
    Verbosity $verbosity,
    Type $type = Type::Normal,
  ): Awaitable<void> {
    if (!$this->shouldOutput($verbosity)) {
      return;
    }

    await $handle->writeAsync($this->format($message, $type));

    return;
  }

  /**
   * {@inheritdoc}
   */
  public async function erase(bool $full = false): Awaitable<void> {
    $chr = $full ? static::EraseDisplay : static::EraseLine;
    $chr .= IOutput::Ctrl;
    await $this->write($chr, Verbosity::Normal, Type::Normal);
  }

  /**
   * {@inheritdoc}
   */
  public function setFormatter(Formatter\IFormatter $formatter): this {
    $this->formatter = $formatter;

    return $this;
  }

  /**
   * {@inheritdoc}
   */
  public function getFormatter(): Formatter\IFormatter {
    return $this->formatter;
  }

  /**
   * {@inheritdoc}
   */
  public function isDecorated(): bool {
    return $this->terminal->isDecorated();
  }

  /**
   * {@inheritdoc}
   */
  public function setVerbosity(Verbosity $verbosity): this {
    $this->verbosity = $verbosity;

    return $this;
  }

  /**
   * Determine how the given verbosity compares to the class's verbosity level.
   */
  protected function shouldOutput(Verbosity $verbosity): bool {
    return ($verbosity as int <= $this->verbosity as int);
  }
}
