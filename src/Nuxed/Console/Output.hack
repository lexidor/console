namespace Nuxed\Console;

use namespace HH\Lib\Str;

class Output {
    const string ERASE_DISPLAY = "\033[2J";
    const string ERASE_LINE = "\033[K";
    const string TAB = "\t";
    const string LF = \PHP_EOL;
    const string CR = "\r";

    /**
     * The singleton instance.
     */
    protected static ?Output $instance;

    /**
     * Dictonary containing available styles to apply to output.
     */
    protected dict<string, Style\IStyle> $styles = dict[];

    /**
     * Flag to determine if we should never output ANSI.
     */
    protected bool $suppressAnsi = false;

    /**
     * The global verbosity level for the `Output`.
     */
    protected Verbosity $verbosity;

    /**
     * Construct a new `Output` object.
     */
    public function __construct(
        Verbosity $verbosity = Verbosity::NORMAL,
        private Terminal $terminal = new Terminal(),
    ) {
        $this->verbosity = $verbosity;

        if (self::$instance is null) {
            self::$instance = $this;
        }
    }

    /**
     * Remove a specific element's style.
     */
    public function clearStyle(string $element): this {
        unset($this->styles[$element]);

        return $this;
    }

    /**
     * Send output to the error stream.
     */
    public async function error(
        string $output = '',
        int $newLines = 1,
        Verbosity $verbosity = $this->verbosity,
    ): Awaitable<void> {
        if (!$this->shouldOutput($verbosity)) {
            return;
        }

        $output = $this->format($output);
        $output .= Str\repeat(static::LF, $newLines);

        await $this->terminal->getErrorHandle()->writeAsync($output);

        return;
    }

    /**
     * Format contents by parsing the style tags and applying necessary formatting.
     */
    public function format(string $message): string {
        $isAnsiAllowed = $this->isAnsiAllowed();
        foreach ($this->styles as $style) {
            $message = $style->format($message, $isAnsiAllowed);
        }

        return $message;
    }

    /**
     * Detect the current state of ANSI.
     */
    public function isAnsiAllowed(): bool {
        $allowed = $this->terminal->hasAnsiSupport();

        if ($this->suppressAnsi) {
            $allowed = false;
        }

        return $allowed;
    }

    /**
     * Create and return the singleton instance.
     */
    public static function getInstance(
        ?Verbosity $verbosity = null,
        ?Terminal $terminal = null,
    ): Output {
        $instance = self::$instance is null ? new Output() : self::$instance;
        if ($verbosity is nonnull) {
            $instance->verbosity = $verbosity;
        }

        if ($terminal is nonnull) {
            $instance->terminal = $terminal;
        }

        self::$instance = $instance;
        return $instance;
    }

    /**
     * Send output to the standard output stream.
     */
    public async function write(
        string $output = '',
        int $newLines = 1,
        Verbosity $verbosity = Verbosity::NORMAL,
        string $newlineChar = Output::LF,
    ): Awaitable<void> {
        if (!$this->shouldOutput($verbosity)) {
            return;
        }

        $output = $this->format($output);
        $output .= Str\repeat($newlineChar, $newLines);

        await $this->terminal->getOutputHandle()->writeAsync($output);
    }

    /**
     * Clears all characters
     *
     * @param bool $full - whether or not to erase full display
     *                      `true`  -   Clears the screen and moves the cursor to the home position.
     *                      `false` -   Clears all characters from the cursor position to the end of the line.
     *
     * @see http://ascii-table.com/ansi-escape-sequences.php
     */
    public async function erase(bool $full = false): Awaitable<void> {
        $chr = $full ? static::ERASE_DISPLAY : static::ERASE_LINE;
        await $this->write($chr, 1, Verbosity::NORMAL, Output::CR);
    }

    public function addStyle(Style\IStyle $style): this {
        $this->styles[$style->getName()] = $style;

        return $this;
    }

    /**
     * Set flag if ANSI output should be suppressed.
     */
    public function setSuppressAnsi(bool $suppress): this {
        $this->suppressAnsi = $suppress;

        return $this;
    }

    /**
     * Set the global verbosity of the `Output`.
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
