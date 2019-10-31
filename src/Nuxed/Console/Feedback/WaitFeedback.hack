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
        '/'
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
    public function __construct(Console\Output $output, Console\Terminal $terminal, int $total = 0, string $message = '', int $interval = 100) {
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
        $feedback = Str\pad_right($this->characterSequence[$index], $this->maxLength + 1);

        $prefix = $this->insert($this->prefix, $variables);
        $suffix = $this->insert($this->suffix, $variables);
        if (!$this->output->isAnsiAllowed()) {
            return;
        }

        $variables = dict[
            'prefix'   => $prefix,
            'feedback' => $feedback,
            'suffix'   => $suffix,
        ];

        await $this->output->write(
            Str\pad_right(
                $this->insert($this->format, $variables),
                $this->terminal->getWidth(),
            ),
            1,
            Console\Verbosity::NORMAL,
            $finish ? Console\Output::LF :  Console\Output::CR,
        );
    }
}
