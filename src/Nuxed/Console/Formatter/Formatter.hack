namespace Nuxed\Console\Formatter;

use namespace HH\Lib\{C, Regex, Str};
use namespace Nuxed\Console;

class Formatter implements IWrappableFormatter {
  protected dict<string, Style\IStyle> $styles = dict[];

  protected Style\StyleStack $styleStack;

  /**
   * Escapes "<" special char in given text.
   *
   * @ignore
   */
  public static function escape(string $text): string {
    $text = Regex\replace($text, re"/([^\\\\]?)</", '$1\\<');
    return self::escapeTrailingBackslash($text);
  }

  /**
   * Escapes trailing "\" in given text.
   *
   * @internal
   * @ignore
   */
  public static function escapeTrailingBackslash(string $text): string {
    if (Str\ends_with($text, '\\')) {
      $len = Str\length($text);
      $text = Str\trim_right($text, '\\');
      $text = Str\replace("\0", '', $text);
      $text .= Str\repeat("\0", $len - Str\length($text));
    }

    return $text;
  }


  public function __construct(
    protected Console\Terminal $terminal = new Console\Terminal(),
    KeyedContainer<string, Style\IStyle> $styles = dict[],
  ) {
    $this->styleStack = new Style\StyleStack();

    $this
      ->addStyle('success', new Style\Style(null, Style\ForegroundColor::Green))
      ->addStyle(
        'warning',
        new Style\Style(null, Style\ForegroundColor::Yellow),
      )
      ->addStyle('error', new Style\Style(
        Style\BackgroundColor::White,
        Style\ForegroundColor::Red,
      ))
      ->addStyle('info', new Style\Style(Style\BackgroundColor::Blue))
      ->addStyle('question', new Style\Style(
        Style\BackgroundColor::Black,
        Style\ForegroundColor::Cyan,
      ))
      ->addStyle('bold', new Style\Style(null, null, vec[
        Style\Effect::Bold,
      ]))
      ->addStyle('underline', new Style\Style(null, null, vec[
        Style\Effect::Underline,
      ]))
      ->addStyle('blink', new Style\Style(null, null, vec[
        Style\Effect::Blink,
      ]));

    foreach ($styles as $name => $style) {
      $this->addStyle($name, $style);
    }

  }

  /**
   * {@inheritdoc}
   */
  public function isDecorated(): bool {
    return $this->terminal->isDecorated();
  }

  /**
   * {@inheritdoc}
   */
  public function addStyle(string $name, Style\IStyle $style): this {
    $this->styles[Str\lowercase($name)] = $style;

    return $this;
  }

  /**
   * {@inheritdoc}
   */
  public function hasStyle(string $name): bool {
    return C\contains_key($this->styles, Str\lowercase($name));
  }

  /**
   * {@inheritdoc}
   */
  public function getStyle(string $name): Style\IStyle {
    return $this->styles[Str\lowercase($name)];
  }

  /**
   * {@inheritdoc}
   */
  public function format(string $message, int $width = 0): string {
    $offset = 0;
    $output = '';
    $currentLineLength = 0;
    $matches = vec[];
    \preg_match_all_with_matches(
      "#<(([a-z][^<>]*+) | /([a-z][^<>]*+)?)>#ix",
      $message,
      inout $matches,
      \PREG_OFFSET_CAPTURE,
    );
    foreach ($matches[0] as $i => $match) {
      $pos = (int)$match[1];
      $text = $match[0];
      if (0 !== $pos && '\\' === $message[$pos - 1]) {
        continue;
      }

      // add the text up to the next tag
      $output .= $this->applyCurrentStyle(
        Str\slice($message, $offset, $pos - $offset),
        $output,
        $width,
        inout $currentLineLength,
      );
      $offset = $pos + Str\length($text);
      // opening tag?
      $open = '/' !== $text[1];
      if ($open) {
        $tag = $matches[1][$i][0];
      } else {
        $tag = $matches[3][$i][0] ?? '';

      }

      if (!$open && !$tag) {
        // </>
        $this->styleStack->pop();
      } else {
        $style = $this->createStyleFromString($tag);
        if ($style is null) {
          $output .= $this->applyCurrentStyle(
            $text,
            $output,
            $width,
            inout $currentLineLength,
          );
        } else if ($open) {
          $this->styleStack->push($style);
        } else {
          $this->styleStack->pop($style);
        }
      }
    }

    $output .= $this->applyCurrentStyle(
      Str\slice($message, $offset),
      $output,
      $width,
      inout $currentLineLength,
    );

    if (Str\contains($output, "\0")) {
      $output = Str\replace($output, "\0", '\\');
    }

    return Str\replace($output, '\\<', '<');
  }

  public function getStyleStack(): Style\StyleStack {
    return $this->styleStack;
  }

  /**
   * Tries to create new style instance from string.
   */
  private function createStyleFromString(string $string): ?Style\IStyle {
    if (C\contains_key($this->styles, $string)) {
      return $this->styles[$string];
    }
    $style = new Style\Style();
    if (!\preg_match_all('/([^=]+)=([^;]+)(;|$)/', $string, \PREG_SET_ORDER)) {
      return null;
    }
    $matches = vec[];
    \preg_match_all_with_matches(
      '/([^=]+)=([^;]+)(;|$)/',
      $string,
      inout $matches,
      \PREG_SET_ORDER,
    );
    foreach ($matches as $match) {
      $match = vec[$match[1], $match[2], $match[3]];
      $match[0] = Str\lowercase($match[0]);
      if ('fg' === $match[0]) {
        $style->setForeground(
          Style\ForegroundColor::getValues()[Str\capitalize(
            Str\lowercase($match[1]),
          )],
        );
      } else if ('bg' === $match[0]) {
        $style->setBackground(
          Style\BackgroundColor::getValues()[Str\capitalize(
            Str\lowercase($match[1]),
          )],
        );
      } else if ('href' === $match[0]) {
        $style->setHref($match[1]);
      } else if ('effects' === $match[0]) {
        $options = Regex\every_match(Str\lowercase($match[1]), re"([^,;]+)");
        $values = Style\Effect::getValues();
        foreach ($options as $option) {
          $style->setEffect($values[Str\capitalize($option[0])]);
        }
      } else {
        return null;
      }
    }

    return $style;
  }

  /**
   * Applies current style from stack to text, if must be applied.
   */
  private function applyCurrentStyle(
    string $text,
    string $current,
    int $width,
    inout int $currentLineLength,
  ): string {
    if ('' === $text) {
      return '';
    }

    if (0 === $width) {
      return $this->terminal->isDecorated()
        ? $this->styleStack->getCurrent()->apply($text)
        : $text;
    }

    if (0 === $currentLineLength && '' !== $current) {
      $text = Str\trim_left($text);
    }

    if ($currentLineLength > 0) {
      $i = $width - $currentLineLength;
      $prefix = Str\slice($text, 0, $i)."\n";
      $text = Str\slice($text, $i);
    } else {
      $prefix = '';
    }

    $matches = Regex\first_match($text, re"~(\\n)$~");
    /* HH_FIXME[4110] */
    $text = $prefix.Regex\replace($text, '~([^\\n]{'.$width.'})\\ *~', "\$1\n");
    $text = Str\trim_right($text, "\n").($matches[1] ?? '');
    if (
      !$currentLineLength && '' !== $current && "\n" !== Str\slice($current, -1)
    ) {
      $text = "\n".$text;
    }

    $lines = Str\split($text, "\n");
    foreach ($lines as $line) {
      $currentLineLength += \strlen($line);
      if ($width <= $currentLineLength) {
        $currentLineLength = 0;
      }
    }
    if ($this->terminal->isDecorated()) {
      foreach ($lines as $i => $line) {
        $lines[$i] = $this->styleStack->getCurrent()->apply($line);
      }
    }

    return Str\join($lines, "\n");
  }
}
