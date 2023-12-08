---
name: Report a bug
about: 'For general bugs'
title: 'Bug report'
labels: 'Type: bug, Status: needs verification'
assignees: 'briandfoy'

---

# What is happening?

# What did you expect to happen?

# Collect some info

You can use the `util/perldoc-bug` program in the repository to collect a bunch 
of information. That program does not submit information automatically but you can
save the JSON output and attach it to this issue. Check the JSON to ensure that 
it doens't expose anything you want to protect.

## What's your terminal

What platform and terminal software are you using? Sometimes that matters.
We'll get the TERM settings from the environment.

## What's your environment?

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

## Which version of Pod::Perldoc

Add the output of `perldoc -h` or `perl -MPod::Perldoc -le 'print Pod::Perldoc->VERSION'`

## Run perldoc under debugging:

There are two ways to turn on debugging. The environment variable
`PERLDOCDEBUG` takes a number to decide how verbose to be. Use `5` to
get the most output. Also, `-D` turns on debugging at the lowest
verboisty:

	$ env PERLDOCDBUG=5 prove -D ...

It can also help to provide a straight dump with B<hexdump>, B<od>, or
a similar tool:

	$ ...| hexdump -C

You may also get intermediate format files left over from debugging,
like C<podman.out.$$.txt>. Clear out any existing ones, run perldoc again
under debugging, and provide any new output files that show up.

# Perl configuration

Add the output of `perl -V`
