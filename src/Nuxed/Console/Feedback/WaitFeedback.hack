namespace Nuxed\Console\Feedback;

use namespace Nuxed\Console;
use namespace HH\Lib\{C, Str};

/**
 * The `WaitFeedback` class displays feedback by cycling through a series of characters.
 */
class WaitFeedback extends AbstractFeedback {

  /**
   * {@inheritdoc}
   */
  protected vec<string> $characterSequence = vec[
    '-',
    '\\',
    '|',
    '/',
  ];

  /**
   * {@inheritdoc}
   */
  protected string $prefix = "{:message} ";

  /**
   * {@inheritdoc}
   */
  protected string $suffix = "";

  /**
   * {@inheritdoc}
   */
  public function __construct(
    Console\Output\IOutput $output,
    Console\Terminal $terminal,
    int $total = 0,
    string $message = '',
    int $interval = 100,
  ) {
    parent::__construct($output, $terminal, $total, $message, $interval);
    $this->iteration = 0;
  }

  /**
   * {@inheritdoc}
   */
  <<__Override>>
  public async function display(bool $finish = false): Awaitable<void> {
    $variables = $this->buildOutputVariables();

    $index = $this->iteration++ % C\count($this->characterSequence);
    $feedback = Str\pad_right(
      $this->characterSequence[$index],
      $this->maxLength + 1,
    );

    $prefix = $this->insert($this->prefix, $variables);
    $suffix = $this->insert($this->suffix, $variables);
    if (!$this->output->isDecorated()) {
      return;
    }

    $variables = dict[
      'prefix' => $prefix,
      'feedback' => $feedback,
      'suffix' => $suffix,
    ];

      // format message
    $output = $this->insert($this->format, $variables)
      // pad the output to the terminal width
      |> Str\pad_right($$, $this->terminal->getWidth())
      // append new line charachter
      |> $$.($finish ? Console\Output\Output::LF : Console\Output\Output::CR);

    await $this->output->write(
      $output,
      Console\Output\Verbosity::Normal,
      Console\Output\Type::Normal,
    );
  }
}
