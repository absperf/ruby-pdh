# ruby-pdh
Simple Ruby gem using ffi to interface with Windows PDH

Note that this library works, but it isn't 100% complete.  It was written for a
use-case that fits needs for a specific project.  That said, the code is pretty
succinct and quite readable, so it's easy to read and understand, and not hard
at all to extend.  I'll gladly accept pull requests that fit with the style of
the project.  If you extend the FFI functions, use the Unicode versions of all
functions for consistency and completeness.  There is a helper method to help
with reading UTF-16 NUL-terminated strings.

The main Pdh class does some state-independent method calls (ie. ones that don't
create or work with a handle), while the Counter and Query classes work on their
respective types and help manage their handles.

The generated rdoc documentation for this project lives at
https://absperf.github.io/win32-pdh

This uses required kwargs, so it depends on at least Ruby 2.1

# Installation

Like most gems, installable from the core rubygems repository with

```sh
gem install win32-pdh
```

Or you can put it in your Gemfile like usual.

# Copyright

Copyright 2018 Absolute Performance Inc.

Written by Taylor C. Richberger

MIT Licensed (see LICENSE file for full license text)
