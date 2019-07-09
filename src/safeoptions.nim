## This module exists to provide a safe way to use options. Importing this
## module will give you all the functionality of the `options` and
## `optionsutils` modules, but will leave out `get` and `unsafeGet` so that
## only the safe patterns from `optionsutils` will be available for use.
import options, optionsutils
export options except get, unsafeGet
export optionsutils
