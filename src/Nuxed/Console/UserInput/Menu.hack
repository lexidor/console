namespace Nuxed\Console\UserInput;

use namespace HH\Lib\{C, Str, Vec};
use namespace Nuxed\Console;

/**
 * The `Menu` class presents the user with a prompt and a list of available
 * options to choose from.
 */
class Menu extends AbstractUserInput<string> {
    /**
     * The message to present at the prompt.
     */
    protected string $message = '';

    /**
     * {@inheritdoc}
     */
    <<__Override>>
    public async function prompt(string $prompt): Awaitable<string> {
        $keys = Vec\keys($this->acceptedValues);
        $values = vec<string>($this->acceptedValues);

        $lastOperation = async {
        };

        if ($this->message !== '') {
            $lastOperation = async {
                await $lastOperation;
                await $this->output->write($this->message);
            };
        }

        foreach ($values as $index => $item) {
            $lastOperation = async {
                await $lastOperation;
                await $this->output
                    ->write(Str\format('  %d. %s', $index + 1, (string)$item));
            };
        }

        await $lastOperation;
        await $this->output->write('');

        return await $this->selection($prompt, $values, $keys);
    }

    private async function selection(
        string $prompt,
        KeyedContainer<int, string> $values,
        KeyedContainer<int, string> $keys,
    ): Awaitable<string> {
        await $this->output->write($prompt.' ', 0, Console\Verbosity::NORMAL);
        $input = await $this->input->getUserInput();
        $input = Str\to_int($input);
        if ($input is nonnull) {
            $input--;

            if (C\contains_key($values, $input)) {
                return $keys[$input];
            }

            if ($input < 0 || $input >= C\count($values)) {
                await $this->output
                    ->error('Invalid menu selection: out of range');
            }
        }

        return await $this->selection($prompt, $values, $keys);
    }

    /**
     * Set the message presented to the user before the options are displayed.
     */
    public function setMessage(string $message): this {
        $this->message = $message;

        return $this;
    }

}
