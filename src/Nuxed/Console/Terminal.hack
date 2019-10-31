namespace Nuxed\Console;

use namespace Nuxed\Environment;
use namespace HH\Lib\Str;
use namespace HH\Lib\Experimental\IO;

class Terminal {
    /**
     * The handle for standard input.
     */
    private IO\ReadHandle $stdin;

    /**
     * The handle for standard error.
     */
    protected IO\WriteHandle $stderr;

    /**
     * The handle for standard output.
     */
    protected IO\WriteHandle $stdout;

    private ?bool $colorSupport;

    public function __construct(private bool $forceAnsi = false) {
        $this->stdin = IO\request_input();
        $this->stdout = IO\request_output();
        $this->stderr = IO\request_error();
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
     * Set whether ANSI output should be forced or to only output ANSI if the
     * command line terminal supports it.
     */
    public function forceAnsiSupport(bool $force = true): this {
        $this->forceAnsi = $force;

        return $this;
    }

    public function hasAnsiSupport(): bool {
        if ($this->forceAnsi === true) {
            return true;
        }

        if ($this->colorSupport is nonnull) {
            return $this->colorSupport;
        }

        $colors = Environment\get('CLICOLORS');
        if ($colors is nonnull) {
            if (
                $colors === '1' ||
                $colors === 'yes' ||
                $colors === 'true' ||
                $colors === 'on'
            ) {
                return $this->colorSupport = true;
            }

            if (
                $colors === '0' ||
                $colors === 'no' ||
                $colors === 'false' ||
                $colors === 'off'
            ) {
                return $this->colorSupport = false;
            }
        }

        if (Environment\get('TRAVIS') is nonnull) {
            return $this->colorSupport = true;
        }

        if (Environment\get('CIRCLECI') is nonnull) {
            return $this->colorSupport = true;
        }

        if (Environment\get('TERM') === 'xterm') {
            return $this->colorSupport = true;
        }

        if (Environment\get('TERM_PROGRAM') === 'Hyper') {
            return $this->colorSupport = true;
        }

        if ($this->isInteractive()) {
            return $this->colorSupport = Str\contains_ci(
                Environment\get('TERM', '') as string,
                'color',
            );
        }

        return $this->colorSupport = false;
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
