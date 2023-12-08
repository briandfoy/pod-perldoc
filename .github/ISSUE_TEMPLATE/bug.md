---
name: bug
about: 'For general bugs'
title: 'Bug report'
labels: 'Type: bug, Status: needs verification'
assignees: 'briandfoy'

---

# What is happening?

# What did you expect to happen?

# What's your environment?

Pod::Perldoc relies on several environment variables to decide how to
act. Knowing your settings can help us reproduce the bug:

- `LANG`
- `LC_ALL`
- `LC_LANG`
- `LESS`
- `MANPAGER`
- `MANWIDTH`
- `MORE`
- `PAGER`
- `PERLDOC`
- `PERLDOC_PAGER`
- `PERLDOCDEBUG`
- `RTFREADER`
- `TERM`

Here's a one-liner that can get what we need (this should work in PowerShell too):

    $ perl -le 'print qq($_: $ENV{$_}) for @ARGV' LANG LC_ALL LC_LANG LESS MANPAGER MANWIDTH MORE PAGER PERLDOC PERLDOC_PAGER PERLDOCDEBUG RTFREADER TERM

# Which version of Pod::Perldoc

Add the output of `perldoc -h` or `perl -MPod::Perldoc -le 'print Pod::Perldoc->VERSION'`

# Run perldoc under debugging:

There are two ways to turn on debugging. The environment variable
`PERLDOCDEBUG` takes a number to decide how verbose to be. Use `5` to
get the most output. Also, `-D` turns on debugging at the lowest
verboisty:

	$ env PERLDOCDBUG=5 prove -D ...

# Perl configuration

Add the output of `perl -V`
