namespace Nuxed\Console\Feedback;

/**
 * A `IFeedback` class handles the displaying of progress information to the user
 * for a specific task.
 */
interface IFeedback {
  /**
   * Progress the feedback display.
   */
  public function advance(int $increment = 1): Awaitable<void>;

  /**
   * Force the feedback to end its output.
   */
  public function finish(): Awaitable<void>;

  /**
   * Set the frequency the feedback should update.
   */
  public function setInterval(int $interval): this;

  /**
   * Set the message presented to the user to signify what the feedback
   * is referring to.
   */
  public function setMessage(string $message): this;

  /**
   * A template string used to construct additional information displayed before
   * the feedback indicator. The supported variables include message, percent,
   * elapsed, and estimated. These variables are denoted in the template '{:}'
   * notation. (i.e., '{:message} {:percent}').
   */
  public function setPrefix(string $prefix): this;

  /**
   * A template string used to construct additional information displayed after
   * the feedback indicator. The supported variables include message, percent,
   * elapsed, and estimated. These variables are denoted in the template '{:}'
   * notation. (i.e., '{:message} {:percent}').
   */
  public function setSuffix(string $suffix): this;

  /**
   * Set the total number of cycles (`advance` calls) the feedback should be
   * expected to take.
   */
  public function setTotal(int $total): this;
}
