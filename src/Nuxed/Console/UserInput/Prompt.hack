namespace Nuxed\Console\UserInput;

use namespace Nuxed\Console;
use namespace HH\Lib\{C, Str, Vec};

/**
 * The `Prompt` class presents the user with a basic prompt and accepts any input
 * unless predetermined choices are given.
 */
class Prompt extends AbstractUserInput<string> {
    /**
     * If the prompt is set to show value hints, this string contains those hints
     * to output when presenting the user with the prompt.
     */
    protected string $hint = '';

    /**
     * {@inheritdoc}
     */
    <<__Override>>
    public async function prompt(string $prompt): Awaitable<string> {
        $keys = Vec\keys($this->acceptedValues);
        $values = vec<string>($this->acceptedValues);

        if ($this->hint !== '') {
            $message = $prompt.' '.$this->hint;
        } else {
            $message = $prompt;
        }

        await $this->output->write($message, 0, Console\Verbosity::NORMAL);
        $input = await $this->input->getUserInput();

        if ($input === '' && $this->default !== '') {
            $input = $this->default;
        }

        if (C\is_empty($this->acceptedValues)) {
            return $input;
        }

        $intInput = Str\to_int($input);
        if ($intInput is nonnull) {
            $intInput--;

            if (C\contains_key($values, $input)) {
                return $keys[$intInput];
            }

            if ($intInput < 0 || $intInput >= C\count($values)) {
                await $this->output
                    ->error('Invalid menu selection: out of range');
            }
        } else {
            foreach ($values as $index => $val) {
                if ($this->strict) {
                    if ($input === $val) {
                        return $keys[$index];
                    }
                } else {
                    if (Str\lowercase($input) === Str\lowercase($val)) {
                        return $keys[$index];
                    }
                }
            }
        }

        return await $this->prompt($prompt);
    }

    /**
     * Set whether the message presented at the prompt should show the predetermined
     * accepted values (if any).
     */
    public function showHints(bool $showHint = true): this {
        if ($showHint === true) {
            $this->hint = Str\format(
                '[%s]',
                Str\join($this->acceptedValues, '/'),
            );
        } else {
            $this->hint = '';
        }

        return $this;
    }

}
