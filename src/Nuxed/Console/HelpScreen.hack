namespace Nuxed\Console;

use namespace HH\Lib\{C, Dict, Math, Str, Vec};
use namespace Nuxed\Console\Input\Bag;

/**
 * The `HelpScreen` class renders out a usage screen given the available `Flag`,
 * `Option`, and `Argument` objects available as well as available commands that
 * can be executed.
 */
final class HelpScreen {

  /**
   * The available `Argument` objects accepted.
   */
  protected Bag\ArgumentBag $arguments;

  /**
   * The current `Command` the `HelpScreen` refers to.
   */
  protected ?Command $command;

  /**
   * The available `Command` objects available.
   */
  protected dict<string, Command> $commands;

  /**
   * The `Console` object to render a help screen for.
   */
  protected Application $app;

  /**
   * The available `Flag` objects accepted.
   */
  protected Bag\FlagBag $flags;

  /**
   * The optional `name` of the application when not outputting a `HelpScreen`
   * for a specific `Command`.
   */
  protected string $name = '';

  /**
   * The available `Option` objects accepted.
   */
  protected Bag\OptionBag $options;

  /**
   * The `Terminal` instance.
   */
  protected Terminal $terminal;

  /**
   * Construct a new instance of the `HelpScreen`.
   */
  public function __construct(Application $app, Terminal $terminal) {
    $this->app = $app;
    $this->terminal = $terminal;

    $input = $app->getInput();
    $this->commands = dict<string, Command>($app->all());
    $this->arguments = $input->getArguments();
    $this->flags = $input->getFlags();
    $this->options = $input->getOptions();
  }

  /**
   * Build and return the markup for the `HelpScreen`.
   */
  public function render(): string {
    $retval = vec[];

    $heading = $this->renderHeading();
    if ($heading !== '') {
      $retval[] = $heading;
    }

    $retval[] = $this->renderUsage();
    if (!C\is_empty($this->arguments->all())) {
      $output = $this->renderSection($this->arguments);
      if ($output) {
        $retval[] = Str\format(
          '<fg=yellow>%s</>%s%s',
          'Arguments',
          Output\IOutput::LF,
          $output,
        );
      }
    }

    if (!C\is_empty($this->flags->all())) {
      $output = $this->renderSection($this->flags);
      if ($output) {
        $retval[] = Str\format(
          '<fg=yellow>%s</>%s%s',
          'Flags',
          Output\IOutput::LF,
          $output,
        );
      }
    }

    if (!C\is_empty($this->options->all())) {
      $output = $this->renderSection($this->options);
      if ($output) {
        $retval[] = Str\format(
          '<fg=yellow>%s</>%s%s',
          'Options',
          Output\IOutput::LF,
          $output,
        );
      }
    }

    if ($this->command is null) {
      if (!C\is_empty($this->commands)) {
        $retval[] = $this->renderCommands();
      }
    }

    return Str\join($retval, Output\IOutput::LF.Output\IOutput::LF).
      Output\IOutput::LF;
  }

  /**
   * Build the list of available `Command` objects that can be called and their
   * descriptions.
   */
  protected function renderCommands(): string {
    $this->commands = Dict\sort_by_key($this->commands);

    $indentation = 0;
    $maxLength = Math\max(
      Vec\map<string, int>(
        Vec\keys<string, Command>($this->commands),
        ($key) ==> {
          $indentation = new \HH\Lib\Ref<int>(0);
          Vec\map<string, void>(
            Str\chunk($key),
            (string $char): void ==> {
              $indentation->value += $char === ':' ? 1 : 0;
            },
          );

          $key = Str\repeat('  ', $indentation->value).$key;

          return Str\length($key);
        },
      ),
    ) ??
      0;
    $descriptionLength = $this->terminal->getWidth() - 4 - $maxLength;

    $output = vec[];
    $nestedNames = vec[];
    foreach ($this->commands as $name => $command) {
      $nested = Str\split($name, ':')
        |> Vec\take<string>($$, C\count<string>($$) - 1);

      if (C\count<string>($nested) > 0) {
        $nest = '';
        foreach ($nested as $piece) {
          $nest = $nest ? ":".$piece : $piece;

          if (!C\contains($nestedNames, $nest)) {
            // If we get here, then we need to list the name, but it isn't
            // actually a command.
            $nestedNames[] = $nest;

            $indentation = new \HH\Lib\Ref<int>(0);
            Vec\map<string, void>(
              Str\chunk($name),
              (string $char): void ==> {
                $indentation->value += $char === ':' ? 1 : 0;
              },
            );

            $output[] = Str\format(
              '<bold>%s</>',
              Str\repeat('  ', $indentation->value).
              Str\pad_right($nest, $maxLength),
            );
          }
        }
      } else {
        $nestedNames[] = $name;
      }

      $indentation = new \HH\Lib\Ref<int>(0);
      Vec\map<string, void>(
        Str\chunk($name),
        (string $char): void ==> {
          $indentation->value += $char === ':' ? 1 : 0;
        },
      );

      $formatted = Str\format(
        '<success>%s</>',
        Str\repeat('  ', $indentation->value).
        Str\pad_right($name, $maxLength - (2 * $indentation->value)),
      );

      $description = Str\split(
        \wordwrap(
          $command->getDescription(),
          $descriptionLength,
          '{{NC-BREAK}}',
        ),
        '{{NC-BREAK}}',
      );
      $formatted .= '  '.C\first<string>($description);
      $description = Vec\drop<string>($description, 1);

      $pad = Str\repeat(' ', $maxLength + 4);
      foreach ($description as $desc) {
        $formatted .= Output\IOutput::LF.$pad.$desc;
      }

      $output[] = '  '.$formatted;
    }

    return Str\format(
      '<fg=yellow>Available Commands:</>%s%s',
      Output\IOutput::LF,
      Str\join($output, Output\IOutput::LF),
    );
  }

  /**
   * Build and return the markup for the heading of the `HelpScreen`. This is
   * either the name of the application (when not rendering for a specific
   * `Command`) or the name and description of the `Command`.
   */
  protected function renderHeading(): string {
    $retval = vec[];

    if ($this->command is nonnull) {
      $command = $this->command;
      $description = $command->getDescription();
      if ($description !== '') {
        $retval[] = $command->getName().' - '.$description;
      } else {
        $retval[] = $command->getName();
      }
    } else if ($this->app->getName() !== '') {
      $banner = $this->app->getBanner();
      if ($banner !== '') {
        $retval[] = $banner;
      }

      $name = Str\format('<fg=green>%s</>', $this->app->getName());
      $version = $this->app->getVersion();
      if ($version !== '') {
        $name .= Str\format(' version <fg=yellow>%s</>', $version);
      }

      $retval[] = $name;
    }

    return Str\join($retval, Output\IOutput::LF);
  }

  /**
   * Build and return a specific section of available `Input` objects the user
   * may specify.
   */
  protected function renderSection<T as Input\Definition\IDefinition>(
    Input\AbstractBag<T> $arguments,
  ): string {
    $entries = dict[];
    foreach ($arguments as $argument) {
      $name = $argument->getFormattedName($argument->getName());
      $alias = $argument->getAlias();
      if (!Str\is_empty($alias)) {
        $name = $argument->getFormattedName($alias).', '.$name;
      }

      $entries[$name] = $argument->getDescription();
    }

    $maxLength = Math\max(
      Vec\map<string, int>(
        Vec\keys<string, string>($entries),
        (string $key): int ==> Str\length($key),
      ),
    ) as nonnull;
    $descriptionLength = $this->terminal->getWidth() - 6 - $maxLength;

    $output = vec[];
    foreach ($entries as $name => $description) {
      $formatted = '  '.Str\pad_right($name, $maxLength);
      $formatted = Str\format('<fg=green>%s</>', $formatted);
      $description = Str\split(
        \wordwrap($description, $descriptionLength, '{{NC-BREAK}}'),
        '{{NC-BREAK}}',
      );
      $formatted .= '  '.C\first<string>($description);
      $description = Vec\drop<string>($description, 1);
      $pad = Str\repeat(' ', $maxLength + 6);
      foreach ($description as $desc) {
        $formatted .= Output\IOutput::LF.$pad.$desc;
      }

      $output[] = '  '.$formatted;
    }

    return Str\join($output, Output\IOutput::LF);
  }

  /**
   * When rendering a for a `Command`, this method builds and returns the usage.
   */
  protected function renderUsage(): string {
    $usage = vec[];
    if ($this->command is nonnull) {
      $command = $this->command;

      $usage[] = $command->getName();

      foreach ($command->getFlags() as $flag) {
        $flg = $flag->getFormattedName($flag->getName());
        $alias = $flag->getAlias();
        if (!Str\is_empty($alias)) {
          $flg .= '|'.$flag->getFormattedName($alias);
        }

        if ($flag->getMode() === Input\Definition\Mode::Optional) {
          $usage[] = '['.$flg.']';
        } else {
          $usage[] = $flg;
        }
      }
      foreach ($command->getOptions() as $option) {
        $opt = $option->getFormattedName($option->getName());
        $alias = $option->getAlias();
        if (!Str\is_empty($alias)) {
          $opt .= '|'.$option->getFormattedName($alias);
        }

        $opt = $opt.'="..."';
        if ($option->getMode() === Input\Definition\Mode::Optional) {
          $usage[] = '['.$opt.']';
        } else {
          $usage[] = $opt;
        }
      }
      foreach ($command->getArguments() as $argument) {
        $arg = $argument->getName();
        $alias = $argument->getAlias();
        if (!Str\is_empty($alias)) {
          $arg .= '|'.$argument->getFormattedName($alias);
        }

        $arg = '<'.$arg.'>';
        if ($argument->getMode() === Input\Definition\Mode::Optional) {
          $usage[] = '['.$arg.']';
        } else {
          $usage[] = $arg;
        }
      }
    } else {
      $usage[] = 'command';
      $usage[] = '[--flag|-f]';
      $usage[] = '[--option|-o="..."]';
      $usage[] = '[<argument>]';
    }

    return Str\format(
      '<fg=yellow>Usage</>%s  %s',
      Output\IOutput::LF,
      Str\join($usage, ' '),
    );
  }

  /**
   * Set the `Argument` objects to render information for.
   */
  public function setArguments(Bag\ArgumentBag $arguments): this {
    $this->arguments = $arguments;

    return $this;
  }

  /**
   * Set the `Command` to render a the help screen for.
   */
  public function setCommand(Command $command): this {
    $this->command = $command;

    return $this;
  }

  /**
   * Set the `Command` objects to render information for.
   */
  public function setCommands(KeyedContainer<string, Command> $commands): this {
    $this->commands = dict<string, Command>($commands);

    return $this;
  }

  /**
   * Set the `Flag` objects to render information for.
   *
   * @param Bag\FlagBag $flags The `Flag` objects avaiable
   *
   * @return $this
   */
  public function setFlags(Bag\FlagBag $flags): this {
    $this->flags = $flags;

    return $this;
  }

  /**
   * Set the `Input` the help screen should read all avaiable parameters and
   * commands from.
   */
  public function setInput(Input\IInput $input): this {
    $this->arguments = $input->getArguments();
    $this->flags = $input->getFlags();
    $this->options = $input->getOptions();

    return $this;
  }

  /**
   * Set the name of the application
   */
  public function setName(string $name): this {
    $this->name = $name;

    return $this;
  }

  /**
   * Set the `Option` objects to render information for.
   */
  public function setOptions(Bag\OptionBag $options): this {
    $this->options = $options;

    return $this;
  }
}
