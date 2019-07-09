optionsutils
============

This module implements conveniences for dealing with the `Option` type in
Nim. It is based on
[superfuncs maybe library](https://github.com/superfunc/maybe>) and
[Toccatas novel boolean approach](www.toccata.io/2017/10/No-Booleans.html)
but also implements features found elsewhere.

The goal of this library is to make options in Nim easier and safer to work
with by creating good patterns for option handling. It consists of two files
`optionsutils` which implements all the features, along with `safeoptions`
which exists to provide a safe way to use options. I gives you all the
functionality of the `options` and `optionsutils` modules, but will leave out
`get` and `unsafeGet` so that only the safe patterns from `optionsutils` will
be available for use.

To see what `optionsutils` offers, see the documentation.
