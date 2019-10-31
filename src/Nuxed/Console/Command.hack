namespace Nuxed\Console;

use namespace HH\Lib\{Regex, Str};
use namespace Nuxed\Console\Exception;
use namespace Nuxed\Console\Input\{Bag, Definition};

/**
 * A `Command` is a class that configures necessary command line inputs from the
 * user and executes its `run` method when called.
 */
abstract class Command {
    /**
     * The name of the command passed into the command line.
     */
    protected string $name = '';

    /**
     * The aliases for the command name.
     */
    protected Container<string> $aliases = vec[];

    /**
     * The description of the command used when rendering its help screen.
     */
    protected string $description = '';

    protected bool $hidden = false;

    /**
     * Bag container holding all registered `Argument` objects
     */
    protected Bag\ArgumentBag $arguments;

    /**
     * Bag container holding all registered `Flag` objects
     */
    protected Bag\FlagBag $flags;

    /**
     * Bag container holding all registered `Option` objects
     */
    protected Bag\OptionBag $options;

    /**
     * The `Input` object containing all registered and parsed command line
     * parameters.
     */
    <<__LateInit>> protected Input $input;

    /**
     * The `Output` object to handle output to the user.
     */
    <<__LateInit>> protected Output $output;

    /**
     * The `Terminal` object.
     */
    <<__LateInit>> protected Terminal $terminal;

    /**
     * The `Application` that is currently running the command.
     */
    <<__LateInit>> protected Application $application;

    /**
     * Construct a new instance of a command.
     */
    public function __construct(string $name = '') {
        $this->arguments = new Bag\ArgumentBag();
        $this->flags = new Bag\FlagBag();
        $this->options = new Bag\OptionBag();
        $this->setName($name);
        $this->configure();
    }

    /**
     * Checks whether the command is enabled or not in the current environment.
     *
     * Override this to check for x or y and return false if the command can not
     * run properly under the current conditions.
     */
    public function isEnabled(): bool {
        return true;
    }

    /**
     * Checks whether the command should be publicly shown or not
     */
    public function isHidden(): bool {
        return $this->hidden;
    }

    /**
     * The configure method that sets up name, description, and necessary parameters
     * for the `Command` to run.
     */
    abstract public function configure(): void;

    /**
     * The method that stores the code to be executed when the `Command` is run.
     */
    abstract public function run(): Awaitable<void>;

    /**
     * Add a new `Argument` to be registered and parsed with the `Input`.
     */
    public function addArgument(Definition\Argument $argument): this {
        $this->arguments->set($argument->getName(), $argument);

        return $this;
    }

    /**
     * Add a new `Flag` to be registered and parsed with the `Input`.
     */
    public function addFlag(Definition\Flag $flag): this {
        $this->flags->set($flag->getName(), $flag);

        return $this;
    }

    /**
     * Add a new `Option` to be registered and parsed with the `Input`.
     */
    public function addOption(Definition\Option $option): this {
        $this->options->set($option->getName(), $option);

        return $this;
    }

    /**
     * Whether or not the command should be hidden from the list of commands
     */
    public function setHidden(bool $hidden): this {
        $this->hidden = $hidden;
        return $this;
    }

    protected function confirm(string $default = ''): UserInput\Confirm {
        $confirm = new UserInput\Confirm($this->input, $this->output);
        $confirm->setDefault($default);

        return $confirm;
    }

    /**
     * Alias method for sending output through STDERROR.
     */
    protected function error(string $output): Awaitable<void> {
        return $this->output->error($output);
    }

    /**
     * Retrieve an `Argument` value by key.
     */
    protected function getArgument(
        string $key,
        ?string $default = null,
    ): ?string {
        return $this->input->getArgument($key)->getValue($default);
    }

    /**
     * Retrieve all `Argument` objects registered specifically to this command.
     */
    public function getArguments(): Bag\ArgumentBag {
        return $this->arguments;
    }

    /**
     * Retrieve the command's description.
     */
    public function getDescription(): string {
        return $this->description;
    }

    /**
     * Retrieve a `Flag` value by key.
     */
    protected function getFlag(string $key, ?int $default = null): ?int {
        return $this->input->getFlag($key)->getValue($default);
    }

    /**
     * Retrieve all `Flag` objects registered specifically to this command.
     */
    public function getFlags(): Bag\FlagBag {
        return $this->flags;
    }

    /**
     * Retrieve the command's name.
     */
    public function getName(): string {
        return $this->name;
    }

    /**
     * Retrieve an `Option` value by key.
     */
    protected function getOption(
        string $key,
        ?string $default = null,
    ): ?string {
        return $this->input->getOption($key)->getValue($default);
    }

    /**
     * Retrieve all `Option` objects registered specifically to this command.
     */
    public function getOptions(): Bag\OptionBag {
        return $this->options;
    }

    /**
     * Returns the aliases for the command.
     */
    public function getAliases(): Container<string> {
        return $this->aliases;
    }

    public function getApplication(): ?Application {
        return $this->application;
    }

    /**
     * Construct and return a new `Menu` object given the choices and display
     * message.
     */
    protected function menu(
        KeyedContainer<string, string> $choices,
        string $message = '',
    ): UserInput\Menu {
        $menu = new UserInput\Menu($this->input, $this->output);
        $menu->setAcceptedValues($choices)->setMessage($message);

        return $menu;
    }

    /**
     * Alias method for sending output through STDOUT.
     */
    protected function write(string $output): Awaitable<void> {
        return $this->output->write($output);
    }

    /**
     * Construct and return a new instance of `ProgressBarFeedback`.
     */
    protected function progress(
        int $total = 0,
        string $message = '',
        int $interval = 100,
    ): Feedback\ProgressBarFeedback {
        return new Feedback\ProgressBarFeedback(
            $this->output,
            $this->terminal,
            $total,
            $message,
            $interval,
        );
    }

    /**
     * Construct and return a new `Prompt` object given the accepted choices and
     * default value.
     *
     * @param KeyedContainer<string, string> $choices   Accepted values
     * @param string                         $default   Default value
     */
    protected function prompt(
        KeyedContainer<string, string> $choices = dict[],
        string $default = '',
    ): UserInput\Prompt {
        $prompt = new UserInput\Prompt($this->input, $this->output);
        $prompt->setAcceptedValues($choices)->setDefault($default);

        return $prompt;
    }

    /**
     * {@inheritdoc}
     */
    public function registerInput(): this {
        $arguments = (new Bag\ArgumentBag())->add($this->arguments->all());
        foreach (
            $this->input->getArguments()->getIterator() as $name => $argument
        ) {
            $arguments->set($name, $argument);
        }
        $this->input->setArguments($arguments);

        $flags = (new Bag\FlagBag())->add($this->flags->all());
        foreach ($this->input->getFlags()->getIterator() as $name => $flag) {
            $flags->set($name, $flag);
        }
        $this->input->setFlags($flags);

        $options = (new Bag\OptionBag())->add($this->options->all());
        foreach (
            $this->input->getOptions()->getIterator() as $name => $option
        ) {
            $options->set($name, $option);
        }
        $this->input->setOptions($options);

        return $this;
    }

    /**
     * Set the command's description.
     */
    public function setDescription(string $description): this {
        $this->description = $description;

        return $this;
    }

    /**
     * {@inheritdoc}
     */
    public function setInput(Input $input): this {
        $this->input = $input;

        return $this;
    }

    /**
     * Set the command's name.
     */
    public function setName(string $name): this {
        $this->validateName($name);

        $this->name = $name;

        return $this;
    }

    /**
     * Sets the aliases for the command.
     */
    public function setAliases(Container<string> $aliases): this {
        foreach ($aliases as $alias) {
            $this->validateName($alias);
        }

        $this->aliases = $aliases;
        return $this;
    }

    /**
     * {@inheritdoc}
     */
    public function setOutput(Output $output): this {
        $this->output = $output;

        return $this;
    }

    public function setTerminal(Terminal $terminal): this {
        $this->terminal = $terminal;

        return $this;
    }

    public function setApplication(Application $application): this {
        $this->application = $application;

        return $this;
    }

    /**
     * Construct and return a new `WaitFeedback` object.
     *
     * @param int    $total     The total number of cycles of the process
     * @param string $message   The message presented with the feedback
     * @param int    $interval  The time interval the feedback should update
     */
    protected function wait(
        int $total = 0,
        string $message = '',
        int $interval = 100,
    ): Feedback\WaitFeedback {
        return new Feedback\WaitFeedback(
            $this->output,
            $this->terminal,
            $total,
            $message,
            $interval,
        );
    }

    /**
     * Validates a command name.
     *
     * It must be non-empty and parts can optionally be separated by ":".
     */
    private function validateName(string $name): void {
        if (!Regex\matches($name, re"/^[^\:]++(\:[^\:]++)*$/")) {
            throw new Exception\InvalidCharacterSequenceException(
                Str\format('Command name "%s" is invalid.', $name),
            );
        }
    }
}
