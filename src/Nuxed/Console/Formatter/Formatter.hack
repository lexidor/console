namespace Nuxed\Console\Formatter;

use namespace HH\Lib\{C, Regex, Str, Vec};
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
        Style\BackgroundColor::Red,
        Style\ForegroundColor::White,
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

    $attributes = Str\replace($string, ';', ' ')
      |> Str\trim($$)
      |> Str\split($$, ' ');

    if (C\is_empty($attributes)) {
      return null;
    }

    $style = new Style\Style();
    $valid = false;
    $backgrounds = Style\BackgroundColor::getValues();
    $foregrounds = Style\ForegroundColor::getValues();
    $effects = Style\Effect::getValues();

    foreach ($attributes as $attribute) {
      if (
        Str\starts_with($attribute, 'bg=') ||
        Str\starts_with($attribute, 'background=')
      ) {
        $background = Str\split($attribute, '=', 2)
          |> C\lastx($$)
          |> Str\replace_every($$, dict['"' => '', '\'' => ''])
          |> Str\capitalize(Str\lowercase($$));
        
        if ('' === $background) {
          continue;
        }

        if (!C\contains_key($backgrounds, $background)) {
          throw new Console\Exception\InvalidCharacterSequenceException(
            Str\format('Background "%s" does not exists.', $background),
          );
        }

        $valid = true;
        $style->setBackground($backgrounds[$background]);
        continue;
      }

      if (
        Str\starts_with($attribute, 'fg=') ||
        Str\starts_with($attribute, 'foreground=')
      ) {
        $foreground = Str\split($attribute, '=', 2)
          |> C\lastx($$)
          |> Str\replace_every($$, dict['"' => '', '\'' => ''])
          |> Str\capitalize(Str\lowercase($$));

        if ('' === $foreground) {
          continue;
        }

        if (!C\contains_key($foregrounds, $foreground)) {
          throw new Console\Exception\InvalidCharacterSequenceException(
            Str\format('Foreground "%s" does not exists.', $foreground),
          );
        }

        $valid = true;
        $style->setForeground($foregrounds[$foreground]);
        continue;
      }

      $effect = Str\capitalize(Str\lowercase($attribute));
      if (!C\contains_key($effects, $effect)) {
        continue;
      }

      $valid = true;
      $style->setEffect($effects[$effect]);
    }

    return $valid ? $style : null;
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
