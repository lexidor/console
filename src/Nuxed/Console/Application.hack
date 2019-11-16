namespace Nuxed\Console;

use namespace HH\Lib\{C, Dict, Str, Vec};
use namespace Nuxed\{Environment, EventDispatcher};
use namespace HH\Lib\Experimental\IO;

/**
 * The `Application` class bootstraps and handles Input and Output to process and
 * run necessary commands.
 */
class Application {
  const type Handles = (
    IO\NonDisposableReadHandle,
    IO\NonDisposableWriteHandle,
    IO\NonDisposableWriteHandle,
  );

  /**
   * A decorator banner to `brand` the application.
   */
  protected string $banner = '';

  /**
   * The `CommandLoader` instance to use to lookup commands.
   */
  protected ?CommandLoader\ICommandLoader $loader = null;

  /**
   * Store added commands until we inject them into the `Input` at runtime.
   */
  protected dict<string, Command> $commands = dict[];

  /**
   * The `Terminal` instance.
   */
  protected Terminal $terminal;

  /**
   * The `Input\IInput` instance for the active command.
   */
  protected Input\IInput $input;

  /**
   * The `Output\IOutput` instance for the active command.
   */
  protected Output\IOutput $output;

  /**
   * The IO Handles used for input, output, and error output.
   */
  private this::Handles $handles;

  protected ?EventDispatcher\IEventDispatcher $dispatcher = null;

  protected bool $autoExit = true;

  /**
   * Construct a new `Application` instance.
   */
  public function __construct(
    /**
    * The name of the application.
    */
    protected string $name = '',

    /**
     * The version of the application.
     */
    protected string $version = '',
  ) {
    $this->handles = tuple(
      IO\request_input(),
      IO\request_output(),
      IO\request_error(),
    );
    $this->terminal = new Terminal(
      false,
      $this->handles[0],
      $this->handles[1],
      $this->handles[2],
    );
    $this->input = new Input\Input(
      $this->terminal,
      Vec\drop<string>(
        vec<string>(/* HH_IGNORE_ERROR[2050] */ $GLOBALS['argv']),
        1,
      ),
    );

    $this->output = new Output\Output(
      Output\Verbosity::Normal,
      $this->terminal,
    );
  }

  final public function setDispatcher(
    EventDispatcher\IEventDispatcher $dispatcher,
  ): this {
    $this->dispatcher = $dispatcher;

    return $this;
  }

  /**
   * Add a `Command` to the application to be parsed by the `Input`.
   */
  public function add(Command $command): this {
    if (!$command->isEnabled()) {
      return $this;
    }

    $command->setApplication($this);
    $this->commands[$command->getName()] = $command;

    return $this;
  }

  /**
   * Returns a registered command by name or alias.
   */
  public function get(string $name): Command {
    if (!$this->has($name)) {
      throw new Exception\CommandNotFoundException(
        Str\format('The command "%s" does not exist.', $name),
      );
    }

    $command = $this->commands[$name] ?? null;
    if ($command is null) {
      $command = $this->loader as nonnull->get($name);
    }

    return $command;
  }

  /**
   * Returns true if the command exists, false otherwise.
   */
  public function has(string $name): bool {
    return C\contains_key<string, string, Command>($this->commands, $name) ||
      ($this->loader is nonnull && $this->loader->has($name));
  }

  /**
   * Finds a command by name or alias.
   *
   * Contrary to get, this command tries to find the best
   * match if you give it an abbreviation of a name or alias.
   */
  public function find(string $name): Command {
    foreach ($this->commands as $command) {
      foreach ($command->getAliases() as $alias) {
        if (!$this->has($alias)) {
          $this->commands[$alias] = $command;
        }
      }
    }

    if ($this->has($name)) {
      return $this->get($name);
    }

    $allCommands = $this->loader
      ? Vec\concat<string>(
        $this->loader->getNames(),
        Vec\keys<string, Command>($this->commands),
      )
      : Vec\keys<string, Command>($this->commands);
    $message = Str\format('Command "%s" is not defined.', $name);
    $alternatives = $this->findAlternatives($name, $allCommands);
    if (!C\is_empty<string>($alternatives)) {
      // remove hidden commands
      $alternatives = Vec\filter<string>(
        $alternatives,
        (string $name): bool ==> !$this->get($name)->isHidden(),
      );
      if (1 === C\count<string>($alternatives)) {
        $message .= Str\format(
          "%s%sDid you mean this?%s%s    ",
          Output\IOutput::LF,
          Output\IOutput::LF,
          Output\IOutput::LF,
          Output\IOutput::LF,
        );
      } else {
        $message .= Str\format(
          "%s%sDid you mean one of these?%s%s    ",
          Output\IOutput::LF,
          Output\IOutput::LF,
          Output\IOutput::LF,
          Output\IOutput::LF,
        );
      }

      $message .= Str\join($alternatives, "\n    - ");
    }

    throw new Exception\CommandNotFoundException($message);
  }

  /**
   * Gets the commands.
   *
   * The container keys are the full names and the values the command instances.
  */
  public function all(): KeyedContainer<string, Command> {
    if ($this->loader is null) {
      return $this->commands;
    }

    $commands = $this->commands;
    foreach ($this->loader->getNames() as $name) {
      if (
        !C\contains_key<string, string, Command>($commands, $name) &&
        $this->has($name)
      ) {
        $commands[$name] = $this->get($name) as nonnull;
      }
    }

    return $commands;
  }

  /**
   * Gets whether to automatically exit after a command execution or not.
   *
   * @return bool Whether to automatically exit after a command execution or not
   */
  public function isAutoExitEnabled(): bool {
    return $this->autoExit;
  }

  /**
   * Sets whether to automatically exit after a command execution or not.
   */
  public function setAutoExit(bool $boolean): this {
    $this->autoExit = $boolean;

    return $this;
  }


  /**
   * Finds alternative of $name among $collection.
   */
  private function findAlternatives(
    string $name,
    Container<string> $collection,
  ): Container<string> {
    $threshold = 1e3;
    $alternatives = dict[];
    $collectionParts = dict[];
    foreach ($collection as $item) {
      $collectionParts[$item] = Str\split($item, ':');
    }

    foreach (Str\split($name, ':') as $i => $subname) {
      foreach ($collectionParts as $collectionName => $parts) {
        $exists = C\contains_key<string, string, num>(
          $alternatives,
          $collectionName,
        );
        if (!C\contains_key<int, int, string>($parts, $i)) {
          if ($exists) {
            $alternatives[$collectionName] += $threshold;
          }

          continue;
        }

        $lev = \levenshtein($subname, $parts[$i]) as num;
        if (
          $lev <= Str\length($subname) / 3 ||
          '' !== $subname && Str\contains($parts[$i], $subname)
        ) {
          $alternatives[$collectionName] = $exists
            ? $alternatives[$collectionName] + $lev
            : $lev;
        } else if ($exists) {
          $alternatives[$collectionName] += $threshold;
        }
      }
    }

    foreach ($collection as $item) {
      $lev = \levenshtein($name, $item) as num;
      if ($lev <= Str\length($name) / 3 || Str\contains($item, $name)) {
        $alternatives[$item] = C\contains_key<string, string, num>(
          $alternatives,
          $item,
        )
          ? $alternatives[$item] - $lev
          : $lev;
      }
    }

    return Dict\filter<string, num>(
      $alternatives,
      (num $lev): bool ==> $lev < (2 * $threshold),
    )
      |> Dict\sort<string, num>($$)
      |> Vec\keys<string, num>($$);
  }

  /**
   * Bootstrap the `Application` instance with default parameters and global
   * settings.
   */
  protected function bootstrap(): void {
    /*
     * Add global flags
     */
    $this->input->addFlag(
      new Input\Definition\Flag('help', 'Display this help screen.')
        |> $$->setAlias('h'),
    );
    $this->input->addFlag(
      new Input\Definition\Flag('quiet', 'Suppress all output.')
        |> $$->setAlias('q'),
    );
    $this->input->addFlag(
      new Input\Definition\Flag(
        'verbose',
        'Set the verbosity of the application\'s output.',
      )
        |> $$->setAlias('v')
        |> $$->setStackable(true),
    );
    $this->input->addFlag(
      new Input\Definition\Flag('version', 'Display the application\'s version')
        |> $$->setAlias('V'),
    );
    $this->input
      ->addFlag(new Input\Definition\Flag('ansi', 'Force ANSI output'));
    $this->input
      ->addFlag(new Input\Definition\Flag('no-ansi', 'Disable ANSI output'));
  }

  /**
   * Retrieve the application's banner.
   */
  public function getBanner(): string {
    return $this->banner;
  }

  /**
   * Retrieve the console's `Input` object.
   */
  public function getInput(): Input\IInput {
    return $this->input;
  }

  /**
   * Retrieve the application's name.
   */
  public function getName(): string {
    return $this->name;
  }

  /**
   * Retrieve the console's output object.
   */
  public function getOutput(): Output\IOutput {
    return $this->output;
  }

  /**
   * Retrieve the application's version.
   */
  public function getVersion(): string {
    return $this->version;
  }

  /**
   * Run the application.
   */
  public async function run(bool $catch = true): Awaitable<int> {
    $command = null;
    try {
      Environment\put('LINES', (string)$this->terminal->getHeight());
      Environment\put('COLUMNS', (string)$this->terminal->getWidth());

      $this->bootstrap();

      $commandName = $this->input->getActiveCommand();
      if ($commandName is null) {
        $this->input->parse();
        $this->input->validate();

        if ($this->input->getFlag('version')->getValue() === 1) {
          await $this->renderVersionInformation();
        } else {
          await $this->renderHelpScreen();
        }
      } else {
        $command = $this->find($commandName);
        await $this->runCommand($command);
      }
    } catch (\Throwable $e) {
      if ($catch) {
        $exitCode = $e->getCode() as arraykey;
        if ($exitCode is string) {
          $exitCode = Str\to_int($exitCode) ?? 1;
        } else {
          $exitCode as int;
        }

        if (0 === $exitCode) {
          $exitCode = 1;
        }

        await $this->catch($e);
        return await $this->terminate(
          $this->input,
          $this->output,
          $command,
          $exitCode,
        );
      }

      throw $e;
    }

    return await $this->terminate($this->input, $this->output, $command, 0);
  }

  /**
   * Register and run the `Command` object.
   */
  public async function runCommand(Command $command): Awaitable<int> {
    $command->setInput($this->input);
    $command->setOutput($this->output);
    $command->setTerminal($this->terminal);
    $command->registerInput();
    $this->input->parse();

    if ($this->input->getFlag('help')->getValue() === 1) {
      await $this->renderHelpScreen($command);
      return 0;
    }

    if ($this->input->getFlag('version')->getValue() === 1) {
      await $this->renderVersionInformation();
      return 0;
    }

    if ($this->input->getFlag('ansi')->getValue() === 1) {
      $this->terminal->setDecorated(true);
    } else if ($this->input->getFlag('no-ansi')->getValue() === 1) {
      $this->terminal->setDecorated(false);
    }

    $flag = $this->input->getFlag('quiet');

    $verbositySet = false;

    if ($flag->exists()) {
      $verbositySet = true;
      $this->output->setVerbosity(Output\Verbosity::Quiet);
    }

    if ($verbositySet === false) {
      $flag = $this->input->getFlag('verbose');
      $verbosity = $flag->getValue(0) as int;
      switch ($verbosity) {
        case 0:
          $verbosity = Output\Verbosity::Normal;
          break;
        case 1:
          $verbosity = Output\Verbosity::Verbose;
          break;
        case 2:
          $verbosity = Output\Verbosity::VeryVerbos;
          break;
        default:
          $verbosity = Output\Verbosity::Debug;
          break;
      }

      Environment\put('SHELL_VERBOSITY', (string)$verbosity);
      $this->output->setVerbosity($verbosity);
    }

    $this->input->validate();

    $dispatcher = $this->dispatcher;
    if ($dispatcher is null) {
      return await $command->run();
    }

    $event = new Event\CommandEvent($this->input, $this->output, $command);
    $e = null;
    try {
      await $dispatcher->dispatch<Event\CommandEvent>($event);
      if ($event->commandShouldRun()) {
        $exitCode = await $command->run();
      } else {
        $exitCode = Event\CommandEvent::RETURN_CODE_DISABLED;
      }
    } catch (\Throwable $e) {
      $event = new Event\ErrorEvent($this->input, $this->output, $e, $command);
      await $dispatcher->dispatch<Event\ErrorEvent>($event);
      $e = $event->getError();
      $exitCode = $event->getExitCode();
      if (0 === $exitCode) {
        $e = null;
      }
    }

    $event = new Event\TerminateEvent(
      $this->input,
      $this->output,
      $command,
      $exitCode,
    );
    await $dispatcher->dispatch<Event\TerminateEvent>($event);

    if (null !== $e) {
      throw $e;
    }

    return $event->getExitCode();
  }

  /**
   * Render the help screen for the application or the `Command` passed in.
   */
  protected async function renderHelpScreen(
    ?Command $command = null,
  ): Awaitable<void> {
    $helpScreen = new HelpScreen($this, $this->terminal);
    if ($command is nonnull) {
      $helpScreen->setCommand($command);
    }

    await $this->output->write($helpScreen->render());
  }

  /**
   * Output version information of the current `Application`.
   */
  protected async function renderVersionInformation(): Awaitable<void> {
    $name = Str\format("<fg=green>%s</>", $this->getName());
    $version = $this->getVersion();
    if ($version !== '') {
      $name .= Str\format(" version <fg=yellow>%s</>", $version);
    }

    await $this->output->writeln($name);
  }

  /**
   * Set the banner of the application.
   */
  public function setBanner(string $banner): this {
    $this->banner = $banner;

    return $this;
  }

  /**
   * Set the name of the application.
   */
  public function setName(string $name): this {
    $this->name = $name;

    return $this;
  }

  /**
   * Set the version of the application.
   */
  public function setVersion(string $version): this {
    $this->version = $version;

    return $this;
  }

  /**
   * Termination method executed at the end of the application's run.
   */
  protected async function terminate(
    Input\IInput $input,
    Output\IOutput $output,
    ?Command $command,
    int $exitCode,
  ): Awaitable<int> {
    if ($this->dispatcher is nonnull) {
      $dispatcher = $this->dispatcher;
      $event = await $dispatcher->dispatch<Event\TerminateEvent>(
        new Event\TerminateEvent($input, $output, $command, $exitCode),
      );
      $exitCode = $event->getExitCode();
    }

    concurrent {
      await $this->handles[0]->closeAsync();
      await $this->handles[1]->closeAsync();
      await $this->handles[2]->closeAsync();
    }

    if ($exitCode > 255) {
      $exitCode = 255;
    }

    if ($this->autoExit) {
      exit($exitCode);
    }

    return $exitCode;
  }

  /**
  * Basic `Throwable` renderer to handle outputting of uncaught exceptions
  * thrown in `Command` objects.
  */
  protected async function catch(\Throwable $exception): Awaitable<void> {
    $class = \get_class($exception);
    $length = $this->terminal->getWidth() - 4;
    $message = Str\format(
      '[%s] {{BREAK}}{{BREAK}}%s',
      $class,
      $exception->getMessage(),
    );
    $message = Str\split(
      \wordwrap(
        Str\replace($message, Output\IOutput::LF, "{{BREAK}}"),
        $length,
        "{{BREAK}}",
        true,
      ),
      '{{BREAK}}',
    );

    $lastOperation = async {
      await $this->output
        ->error(Str\format(
          '<fg=white bg=red> %s </>%s',
          Str\pad_right('', $length),
          Output\IOutput::LF,
        ));
    };

    foreach ($message as $line) {
      $lastOperation = async {
        await $lastOperation;
        await $this->output
          ->error(Str\format(
            '<fg=white bg=red> %s </>%s',
            Str\pad_right($line, $length),
            Output\IOutput::LF,
          ));
      };
    }

    $lastOperation = async {
      await $lastOperation;
      await $this->output
        ->error(Str\format(
          '<fg=white bg=red> %s </>%s%s',
          Str\pad_right('', $length),
          Output\IOutput::LF,
          Output\IOutput::LF,
        ));
      await $this->output
        ->write(
          Str\format(
            '- <bold>%s:%d</>%s%s',
            $exception->getFile(),
            $exception->getLine(),
            Output\IOutput::LF,
            Output\IOutput::LF,
          ),
          Output\Verbosity::Verbose,
        );
    };

    $frames = Vec\filter<dict<string, string>>(
      Vec\map<darray<string, mixed>, dict<string, string>>(
        /* HH_IGNORE_ERROR[4110] */
        $exception->getTrace(),
        (array<string, mixed> $frame): dict<string, string> ==> {
          unset($frame['args']);
          /* HH_IGNORE_ERROR[4110] */
          return dict<string, string>($frame);
        },
      ),
      (dict<string, string> $frame): bool ==>
        C\contains_key<string, string, string>($frame, 'function') &&
        C\contains_key<string, string, string>($frame, 'file'),
    );

    if (0 !== C\count<dict<string, string>>($frames)) {
      $lastOperation = async {
        await $lastOperation;
        await $this->output
          ->write(
            '<fg=yellow>Exception trace: </>'.
            Output\IOutput::LF.
            Output\IOutput::LF,
            Output\Verbosity::VeryVerbos,
          );
      };

      foreach ($frames as $frame) {
        if (C\contains_key<string, string, string>($frame, 'class')) {
          $call = Str\format(
            ' %s%s%s()',
            $frame['class'],
            $frame['type'],
            $frame['function'],
          );
        } else {
          $call = Str\format(' %s()', $frame['function']);
        }

        $lastOperation = async {
          await $lastOperation;
          await $this->output
            ->writeln($call, Output\Verbosity::VeryVerbos);
          await $this->output
            ->write(
              Str\format(
                ' - <fg=green>%s</>%s%s',
                $frame['file'].
                (
                  C\contains_key<string, string, string>($frame, 'line')
                    ? ':'.$frame['line']
                    : ''
                ),
                Output\IOutput::LF,
                Output\IOutput::LF,
              ),
              Output\Verbosity::VeryVerbos,
            );
        };
      }
    }

    await $lastOperation;
  }
}
