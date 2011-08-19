# Socket.IO-ruby

This project is:

 1. A ruby re-interpretation of https://github.com/LearnBoost/socket.io
 1. Meant to be in near sync with the HEAD at LearnBoost/socket.io; although the commit dates may not match up.
 1. Meant to be a rack-based ruby alternative with as few requirements as possible to accomodate large existing infrastructures.

# Requirements

You'll need a Ruby version of the

 * [node.js core EventEmitter](https://github.com/Oblong/EventEmitter-ruby)
 * [node.js code http](https://github.com/Oblong/Http-Ruby)
 * [npm of policyfile](https://github.com/Oblong/flashpolicyd)

## Gems you'll need

 * uuid
 * cgi
 * rack
 * thin
 * json

# Notes

 * Not done yet; don't expect it to work.  It's really close though. (2011-08-18)
 * Wrote in Ruby 1.8.7-p334 on Ubuntu 10.04. That's the testing ground too; your mileage may vary.
