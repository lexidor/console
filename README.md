<p align="center"><img src="https://avatars3.githubusercontent.com/u/45311177?s=200&v=4"></p>

<p align="center">
<a href="https://travis-ci.org/nuxed/console"><img src="https://travis-ci.org/nuxed/console.svg" alt="Build Status"></a>
<a href="https://packagist.org/packages/nuxed/console"><img src="https://poser.pugx.org/nuxed/console/d/total.svg" alt="Total Downloads"></a>
<a href="https://packagist.org/packages/nuxed/console"><img src="https://poser.pugx.org/nuxed/console/v/stable.svg" alt="Latest Stable Version"></a>
<a href="https://packagist.org/packages/nuxed/console"><img src="https://poser.pugx.org/nuxed/console/license.svg" alt="License"></a>
</p>

# Nuxed Console
 
Nuxed Console allows you to create beautiful and testable command line applications easily.

### Installation

This package can be installed with [Composer](https://getcomposer.org).

```console
$ composer require nuxed/console
```

### Example

```hack
use namespace Nuxed\Console;

<<__EntryPoint>>
async function main(): void {
  $application = new Console\Application('nuxed', '0.1');

  await $application->run();
}
```

```console
$ hhvm app.hack --help
```

---

### Security

For information on reporting security vulnerabilities in Nuxed Console, see [SECURITY.md](SECURITY.md).

---

### License

The Nuxed Console library is open-sourced software licensed under the MIT-licensed.
