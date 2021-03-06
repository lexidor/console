namespace Nuxed\Console\UserInput;

use namespace Nuxed\Console;

/**
 * `AbstractUserInput` handles core functionality for prompting and accepting
 * the user input.
 */
abstract class AbstractUserInput<T> implements IUserInput<T> {
  /**
   * Input values accepted to continue.
   */
  protected dict<string, T> $acceptedValues = dict[];

  /**
   * Default value if input given is empty.
   */
  protected string $default = '';

  /**
   * If the input should be accepted strictly or not.
   */
  protected bool $strict = true;

  /**
   * Construct a new `UserInput` object.
   */
  public function __construct(
    /**
     * `Input` object used for retrieving user input.
     */
    protected Console\Input\IInput $input,

    /**
     * The output object used for sending output.
     */
    protected Console\Output\IOutput $output,
  ) {}

  /**
   * Set the values accepted by the user.
   */
  public function setAcceptedValues(
    KeyedContainer<string, T> $choices = dict[],
  ): this {
    $this->acceptedValues = dict<string, T>($choices);

    return $this;
  }

  /**
   * Set the default value to use when input is empty.
   */
  public function setDefault(string $default): this {
    $this->default = $default;

    return $this;
  }

  /**
   * Set if the prompt should run in strict mode.
   */
  public function setStrict(bool $strict): this {
    $this->strict = $strict;

    return $this;
  }
}
