namespace Nuxed\Console\Feedback;

use namespace Nuxed\Console;
use namespace HH\Lib\{C, Math, Str};

/**
 * The `ProgressBarFeedback` class displays feedback information with a progress bar.
 * Additional information including percentage done, time elapsed, and time
 * remaining is included by default.
 */
final class ProgressBarFeedback extends AbstractFeedback {
  /**
   * The 2-string character format to use when constructing the displayed bar.
   */
  protected vec<string> $characterSequence = vec['=', '>'];

  protected int $increments = 0;

  /**
   * {@inheritdoc}
   */
  <<__Override>>
  protected async function display(bool $finish = false): Awaitable<void> {
    $completed = $this->getPercentageComplete();
    $variables = $this->buildOutputVariables();

    // Need to make prefix and suffix before the bar so we know how long to render it.
    $prefix = $this->insert($this->prefix, $variables);
    $suffix = $this->insert($this->suffix, $variables);
    if (!$this->output->isDecorated()) {
      return;
    }

    $size = $this->terminal->getWidth();
    $size -= Str\length($prefix.$suffix);
    if ($size < 0) {
      $size = 0;
    }

    // Str\slice is needed to trim off the bar cap at 100%
    $bar = Str\repeat(
      $this->characterSequence[0],
      (int)Math\floor($completed * $size),
    ).
      $this->characterSequence[1];
    $bar = Str\slice(Str\pad_right($bar, $size, ' '), 0, $size);

    $variables = dict[
      'prefix' => $prefix,
      'feedback' => $bar,
      'suffix' => $suffix,
    ];

    // format message
    $output = $this->insert($this->format, $variables)
      // pad the output to the terminal width
      |> Str\pad_right($$, $this->terminal->getWidth())
      // append new line charachter
      |> $$.
        (
          $finish
            ? Console\Output\Output::EndOfLine
            : Console\Output\Output::Ctrl
        );

    await $this->output->write(
      $output,
      Console\Output\Verbosity::Normal,
      Console\Output\Type::Normal,
    );
  }

  /**
   * {@inheritdoc}
   */
  <<__Override>>
  public function setCharacterSequence(Container<string> $characters): this {
    if (C\count($characters) !== 2) {
      throw new Console\Exception\InvalidCharacterSequenceException(
        "Display bar must only contain 2 values",
      );
    }

    parent::setCharacterSequence($characters);
    return $this;
  }

}
