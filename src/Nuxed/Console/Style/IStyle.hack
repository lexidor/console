namespace Nuxed\Console\Style;

/**
 * defines how to style output it applies to.
 */
interface IStyle {
  /**
   * Retrieve the name of the style
   */
  public function getName(): string;

  /**
   * Format the contents between the given XML tag with the style.
   *
   * @param string $value     The contents to format
   * @param bool $ansiSupport If we should style the output with ANSI output
   */
  public function format(string $value, bool $ansiSupport = true): string;
}
