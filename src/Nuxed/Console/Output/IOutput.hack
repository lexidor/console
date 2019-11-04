namespace Nuxed\Console\Output;

use namespace Nuxed\Console\Formatter;

interface IOutput {
  const string ERASE_DISPLAY = "\033[2J";
  const string ERASE_LINE = "\033[K";
  const string TAB = "\t";
  const string LF = \PHP_EOL;
  const string CR = "\r";

  /**
   * Format contents by parsing the style tags and applying necessary formatting.
   */
  public function format(string $message, Type $type = Type::Normal): string;

  /**
   * Send output to the standard output stream with a new line charachter appended to the message.
   */
  public function writeln(
    string $message,
    Verbosity $verbosity = Verbosity::Normal,
    Type $type = Type::Normal,
  ): Awaitable<void>;

  /**
   * Send output to the standard output stream.
   */
  public function write(
    string $message,
    Verbosity $verbosity = Verbosity::Normal,
    Type $type = Type::Normal,
  ): Awaitable<void>;

  /**
   * Send output to the error stream.
   */
  public function error(
    string $message,
    Verbosity $verbosity = Verbosity::Normal,
    Type $type = Type::Normal,
  ): Awaitable<void>;


  /**
   * Clears all characters
   *
   * @param bool $full - whether or not to erase full display
   *                      `true`  -   Clears the screen and moves the cursor to the home position.
   *                      `false` -   Clears all characters from the cursor position to the end of the line.
   *
   * @see http://ascii-table.com/ansi-escape-sequences.php
   */
  public function erase(bool $full = false): Awaitable<void>;

  public function setFormatter(Formatter\IFormatter $formatter): this;

  public function getFormatter(): Formatter\IFormatter;

  public function isDecorated(): bool;

  /**
   * Set the global verbosity of the `Output`.
   */
  public function setVerbosity(Verbosity $verbosity): this;
}
