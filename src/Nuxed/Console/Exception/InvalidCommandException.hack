namespace Nuxed\Console\Exception;

/**
 * Exception thrown when the command used in the application doesn't exist.
 */
final class InvalidCommandException
  extends \OutOfBoundsException
  implements IException {

}
