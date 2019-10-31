namespace Nuxed\Console\Style;

use namespace HH\Lib\{C, Regex, Str, Vec};

/**
 * defines how to style output it applies to.
 */
class Style implements IStyle {
  /**
   * The various effects to apply.
   */
  protected vec<Effect> $effectsList = vec[];

  public function __construct(
    /**
     * The name of the style.
     */
    protected string $name,

    /**
     * The foreground color to apply.
     */
    protected ?ForegroundColor $fgColor = null,

    /**
     * The background color to apply.
     */
    protected ?BackgroundColor $bgColor = null,

    /**
     * The various effects to apply.
     */
    Container<Effect> $effectsList = vec[],
  ) {
    $this->effectsList = vec($effectsList);
  }

  public function getName(): string {
    return $this->name;
  }

  /**
   * Format the contents between the given XML tag with the style Style.
   *
   * @param string $value     The contents to format
   * @param bool $ansiSupport If we should style the output with ANSI output
   */
  public function format(string $value, bool $ansiSupport = true): string {
    $values = $this->getValueBetweenTags($value);
    $retval = $value;
    foreach ($values as $val) {
      if ($ansiSupport === false) {
        $retval = Str\replace(
          $retval,
          '<'.$this->name.'>'.$val.'</'.$this->name.'>',
          $val,
        );
        continue;
      }

      $valueResult = $this->replaceTagColors($val);

      $retval = Str\replace(
        $retval,
        '<'.$this->name.'>'.$val.'</'.$this->name.'>',
        $valueResult,
      );
    }

    return $retval;
  }

  /**
   * Retrieve the start code of the `Style`.
   */
  protected function getStartCode(): string {
    $code = $this->getBackgroundColor().';'.$this->getForegroundColor();
    $effects = $this->getParsedStringEffects();
    $code .= $effects is nonnull ? ';'.$effects : '';
    return Str\format("\033[%sm", $code);
  }

  /**
   * Retrieve the background color of the `Style`.
   */
  protected function getBackgroundColor(): ?BackgroundColor {
    return $this->bgColor;
  }

  /**
   * Retrieve the foreground color of the `Style`.
   */
  protected function getForegroundColor(): ?ForegroundColor {
    return $this->fgColor;
  }

  /**
   * Retrieve the effects of the `Style`.
   */
  protected function getEffects(): Container<Effect> {
    return $this->effectsList;
  }

  /**
   * Retrieve the code to end the `Style`.
   */
  protected function getEndCode(): string {
    return "\033[0m";
  }

  /**
   * Retrieve the string of effects to apply for the `Style`.
   */
  protected function getParsedStringEffects(): ?string {
    if (0 === C\count($this->effectsList)) {
      return null;
    }

    $effects = vec[];

    foreach ($this->effectsList as $effect) {
      $effects[] = $effect as string;
    }

    return Str\join($effects, ';');
  }

  /**
   * Parse and return contents between the XML tag.
   */
  protected function getValueBetweenTags(string $stringToParse): vec<string> {
    $regexp = '#<'.$this->name.'>(.*?)</'.$this->name.'>#s';
    /* HH_IGNORE_ERROR[4110] */
    $tagsMatched = Regex\every_match($stringToParse, $regexp);
    return Vec\map<_, string>(
      $tagsMatched,
      ($match): string ==> $match[1] as string,
    );
  }

  /**
   * Return the styled text.
   */
  protected function replaceTagColors(string $text): string {
    if (Str\contains($text, $this->getEndCode())) {
      $endCodePosition = Str\search_last($text, $this->getEndCode()) as int;
      $endCodeLength = Str\length($this->getEndCode());
      $beforeEndCode = Str\slice($text, 0, $endCodePosition);
      $afterEndCode = Str\slice($text, $endCodePosition + $endCodeLength);

      return Str\format(
        '%s%s%s%s%s',
        $this->getStartCode(),
        $beforeEndCode,
        $this->getStartCode(),
        $afterEndCode,
        $this->getEndCode(),
      );
    }

    return Str\format(
      "%s%s%s",
      $this->getStartCode(),
      $text,
      $this->getEndCode(),
    );
  }
}
