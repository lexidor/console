namespace Nuxed\Console\UserInput;

/**
 * User input handles presenting a prompt to the user and
 */
interface IUserInput<T> {
  /**
   * Present the user with a prompt and return the inputted value.
   */
  public function prompt(string $message): Awaitable<T>;
}
