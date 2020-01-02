namespace Nuxed\Console\Tree;

use namespace Nuxed\Console;
use namespace HH\{Asio, Lib};
use namespace HH\Lib\{C, Str, Vec};

/**
 * Build a human readable ASCII tree given an infinitely nested data structure.
 */
final class AsciiTree<Tk as arraykey, Tv> extends AbstractTree<Tk, Tv> {
  /**
   * {@inheritdoc}
   */
  <<__Override>>
  protected async function build(
    KeyedContainer<Tk, Tv> $tree,
    string $prefix = '',
  ): Awaitable<string> {
    $output = new Lib\Ref<vec<Awaitable<string>>>(vec[]);
    $keys = Vec\keys<Tk, Tv>($this->data);
    $branch = vec<Tv>($this->data);

    for ($i = 0, $count = C\count($branch); $i < $count; ++$i) {
      $itemPrefix = $prefix;
      $next = $branch[$i];

      if ($i === $count - 1) {
        if ($next is Container<_>) {
          $itemPrefix .= '└─┬ ';
        } else {
          $itemPrefix .= '└── ';
        }
      } else {
        if ($next is Container<_>) {
          $itemPrefix .= '├─┬ ';
        } else {
          $itemPrefix .= (0 === $i && '' === $prefix)
            ? '┌── '
            : '├── ';
        }
      }

      if ($branch[$i] is Container<_>) {
        $output->value[] = async {
          return $itemPrefix.(string)$keys[$i];
        };
      } else {
        $output->value[] = async {
          return $itemPrefix.(string)$branch[$i];
        };
      }

      if ($next is Container<_>) {
        if (!$next is KeyedContainer<_, _>) {
          $next = vec($next);
        }

        $tree = new self<arraykey, mixed>($next);
        $output->value[] = $tree->build(
          $next,
          $prefix.($i === $count - 1 ? '  ' : '│ '),
        );
      }
    }

    $result = await Asio\v<string>($output->value);
    return Str\join($result, Console\Output\IOutput::EndOfLine);
  }
}
