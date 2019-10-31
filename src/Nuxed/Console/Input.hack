namespace Nuxed\Console;

use namespace HH\Lib\Experimental\IO;
use namespace HH\Lib\{Regex, Str, Vec};
use namespace Nuxed\Console\Input\{Bag, Definition};

/**
 * The `Input` class contains all available `Flag`, `Argument`, `Option`, and
 * `Command` objects available to parse given the provided input.
 */
class Input {
    /**
     * Bag container holding all registered `Argument` objects
     */
    protected Bag\ArgumentBag $arguments;

    /**
     * The active command name (if any) that is parsed from the provided input.
     */
    protected ?string $command;

    /**
     * All available `Command` candidates to parse from the input.
     */
    protected dict<string, Command> $commands = dict[];

    /**
     * Bag container holding all registered `Flag` objects
     */
    protected Bag\FlagBag $flags;

    /**
     * The `Input\Lexer` that will traverse and help parse the provided input.
     */
    protected Input\Lexer $input;

    /**
     * The singleton instance.
     */
    protected static ?Input $instance;

    /**
     * All parameters provided in the input that do not match a given `Command`
     * or `Input\Definition`.
     */
    protected vec<shape(
        'raw' => string,
        'value' => string,
    )> $invalid = vec[];

    /**
     * Bag container holding all registered `Option` objects
     */
    protected Bag\OptionBag $options;

    /**
     * Boolean if the provided input has already been parsed or not.
     */
    protected bool $parsed = false;

    /**
     * Raw input used at creation of the `Input` object.
     */
    protected vec<string> $rawInput;

    /**
     * Stream handle for user input.
     */
    protected IO\ReadHandle $stdin;

    /**
     * The 'strict' value of the `Input` object. If set to `true`, then any invalid
     * parameters found in the input will throw an exception.
     */
    protected bool $strict = false;

    /**
     * The Terminal instance
     */
    protected Terminal $terminal;

    /**
     * Construct a new instance of Input
     */
    public function __construct(
        Terminal $terminal,
        Container<string> $args,
        bool $strict = false,
    ) {
        $this->terminal = $terminal;
        $this->stdin = $terminal->getInputHandle();
        $this->rawInput = vec<string>($args);
        $this->input = new Input\Lexer($args);
        $this->flags = new Bag\FlagBag();
        $this->options = new Bag\OptionBag();
        $this->arguments = new Bag\ArgumentBag();
        $this->strict = $strict;
    }

    /**
     * Add a new `Argument` candidate to be parsed from input.
     */
    public function addArgument(Definition\Argument $argument): this {
        $this->arguments->set($argument->getName(), $argument);

        return $this;
    }

    /**
     * Add a new `Flag` candidate to be parsed from input.
     */
    public function addFlag(Definition\Flag $flag): this {
        $this->flags->set($flag->getName(), $flag);

        return $this;
    }

    /**
     * Add a new `Option` candidate to be parsed from input.
     */
    public function addOption(Definition\Option $option): this {
        $this->options->set($option->getName(), $option);

        return $this;
    }

    /**
     * Parse and retrieve the active command name from the raw input.
     */
    public function getActiveCommand(): ?string {
        if ($this->parsed === true) {
            return $this->command;
        }

        if ($this->command is nonnull) {
            return $this->command;
        }

        $input = $this->rawInput;

        foreach ($input as $index => $value) {
            $command = $value;
            $this->setInput(
                Vec\filter_with_key($input, ($k, $v) ==> $index !== $k),
            );
            $this->command = $command;
            return $this->command;
        }

        return null;
    }

    /**
     * Retrieve an `Argument` by its key or alias. Returns null if none exists.
     */
    public function getArgument(string $key): Definition\Argument {
        $argument = $this->arguments->get($key);
        if ($argument is null) {
            throw new Exception\InvalidInputDefinitionException(
                Str\format("The argument %s doesn't exist.", $key),
            );
        }

        return $argument;
    }

    /**
     * Retrieve all `Argument` candidates.
     */
    public function getArguments(): Bag\ArgumentBag {
        return $this->arguments;
    }

    /**
     * Retrieve a `Flag` by its key or alias. Returns null if none exists.
     */
    public function getFlag(string $key): Definition\Flag {
        $flag = $this->flags->get($key);
        if ($flag is null) {
            throw new Exception\InvalidInputDefinitionException(
                Str\format("The flag %s doesn't exist.", $key),
            );
        }

        return $flag;
    }

    /**
     * Retrieve all `Flag` candidates.
     */
    public function getFlags(): Bag\FlagBag {
        return $this->flags;
    }

    /**
     * Retrieve an `Option` by its key or alias. Returns null if none exists.
     */
    public function getOption(string $key): Definition\Option {
        $option = $this->options->get($key);
        if ($option is null) {
            throw new Exception\InvalidInputDefinitionException(
                Str\format("The option %s doesn't exist.", $key),
            );
        }

        return $option;
    }

    /**
     * Retrieve all `Option` candidates.
     */
    public function getOptions(): Bag\OptionBag {
        return $this->options;
    }

    /**
     * Return whether the `Input` is running in `strict` mode or not.
     */
    public function getStrict(): bool {
        return $this->strict;
    }

    /**
     * Read in and return input from the user.
     */
    public async function getUserInput(): Awaitable<string> {
        return Str\trim(await $this->stdin->readLineAsync());
    }

    /**
     * Parse input for all `Flag`, `Option`, and `Argument` candidates.
     */
    public function parse(): void {
        foreach ($this->input as $val) {
            if ($this->parseFlag($val)) {
                continue;
            }
            if ($this->parseOption($val)) {
                continue;
            }

            if ($this->command is null) {
                // If we haven't parsed a command yet, do so.
                $this->command = $val['value'];
                continue;
            }

            if ($this->parseArgument($val)) {
                continue;
            }

            if ($this->strict === true) {
                throw new Exception\InvalidNumberOfArgumentsException(
                    Str\format(
                        "No parameter registered for value %s",
                        $val['value'],
                    ),
                );
            }

            $this->invalid[] = $val;
        }

        if ($this->command is null && $this->strict === true) {
            throw new Exception\InvalidNumberOfCommandsException(
                "No command was parsed from the input.",
            );
        }

        $this->parsed = true;
    }

    public function validate(): void {
        foreach ($this->flags->getIterator() as $name => $flag) {
            if ($flag->getMode() !== Input\Definition\Mode::REQUIRED) {
                continue;
            }

            if ($flag->getValue() is null) {
                throw new Exception\MissingValueException(
                    Str\format("Required flag `%s` is not present.", $name),
                );
            }
        }

        foreach ($this->options->getIterator() as $name => $option) {
            if ($option->getMode() !== Input\Definition\Mode::REQUIRED) {
                continue;
            }

            if ($option->getValue() is null) {
                throw new Exception\MissingValueException(Str\format(
                    "No value present for required option %s",
                    $name,
                ));
            }
        }

        foreach ($this->arguments->getIterator() as $name => $argument) {
            if ($argument->getMode() !== Input\Definition\Mode::REQUIRED) {
                continue;
            }

            if ($argument->getValue() is null) {
                throw new Exception\MissingValueException(Str\format(
                    "No value present for required argument %s",
                    $name,
                ));
            }
        }
    }

    /**
     * Determine if a RawInput matches an `Argument` candidate. If so, save its
     * value.
     */
    protected function parseArgument(
        shape(
            'raw' => string,
            'value' => string,
        ) $input,
    ): bool {
        foreach ($this->arguments as $argument) {
            if ($argument->getValue() is null) {
                $argument->setValue($input['raw']);
                $argument->setExists(true);

                return true;
            }
        }

        return false;
    }

    /**
     * Determine if a RawInput matches a `Flag` candidate. If so, save its
     * value.
     */
    protected function parseFlag(
        shape(
            'raw' => string,
            'value' => string,
        ) $input,
    ): bool {
        $key = $input['value'];
        $flag = $this->flags->get($key);
        if ($flag is nonnull) {
            if ($flag->isStackable()) {
                $flag->increaseValue();
            } else {
                $flag->setValue(1);
            }

            $flag->setExists(true);

            return true;
        }

        foreach ($this->flags->getIterator() as $_name => $flag) {

            if ($key === $flag->getNegativeAlias()) {
                $flag->setValue(0);
                $flag->setExists(true);

                return true;
            }
        }

        return false;
    }

    /**
     * Determine if a RawInput matches an `Option` candidate. If so, save its
     * value.
     */
    protected function parseOption(
        shape(
            'raw' => string,
            'value' => string,
        ) $input,
    ): bool {
        $key = $input['value'];
        $option = $this->options->get($key);
        if ($option is null) {
            return false;
        }

        // Peak ahead to make sure we get a value.
        $nextValue = $this->input->peek();
        if ($nextValue is null) {
            throw new Exception\MissingValueException(Str\format(
                'No value given for the option %s.',
                $input['value'],
            ));
        }

        if (
            !$this->input->end() && $this->input->isArgument($nextValue['raw'])
        ) {
            throw new Exception\MissingValueException(
                Str\format('No value is present for option %s.', $key),
            );
        }

        $this->input->shift();
        $value = $this->input->current();

        $matches = vec[];
        if (Regex\matches($value['raw'], re"#\A\"(.+)\"$#")) {
            $matches = Regex\first_match($value['raw'], re"#\A\"(.+)\"$#")
                as nonnull;
            $value = $matches[1];
        } else if (Regex\matches($value['raw'], re"#\A'(.+)'$#")) {
            $matches = Regex\first_match($value['raw'], re"#\A'(.+)'$#")
                as nonnull;
            $value = $matches[1];
        } else {
            $value = $value['raw'];
        }

        $option->setValue($value);
        $option->setExists(true);

        return true;
    }

    /**
     * Set the arguments of the `Input`. This will override all existing arguments.
     */
    public function setArguments(Bag\ArgumentBag $arguments): this {
        $this->arguments = $arguments;

        return $this;
    }

    /**
     * Set the flags of the `Input`. This will override all existing flags.
     */
    public function setFlags(Bag\FlagBag $flags): this {
        $this->flags = $flags;

        return $this;
    }

    /**
     * Set the input to be parsed.
     */
    public function setInput(Container<string> $args): this {
        $this->rawInput = vec<string>($args);
        $this->input = new Input\Lexer($args);
        $this->parsed = false;
        $this->command = null;

        return $this;
    }

    /**
     * Set the options of the `Input`. This will override all existing options.
     */
    public function setOptions(Bag\OptionBag $options): this {
        $this->options = $options;

        return $this;
    }

    /**
     * Set the strict value of the `Input`
     */
    public function setStrict(bool $strict): this {
        $this->strict = $strict;

        return $this;
    }
}
