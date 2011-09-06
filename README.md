# Socket.IO-ruby

This project is:

 1. A ruby re-interpretation of https://github.com/LearnBoost/socket.io
 1. Meant to be in near sync with the HEAD at LearnBoost/socket.io; although the commit dates may not match up.
 1. Meant to be a rack-based ruby alternative with as few requirements as possible to accomodate large existing infrastructures.

# Requirements

For convenience, the necessary files below are included in the dep directory in the repository.

 * [node.js core EventEmitter](https://github.com/Oblong/EventEmitter-ruby)
 * [node.js core http](https://github.com/Oblong/Http-Ruby)
 * [npm of policyfile](https://github.com/Oblong/flashpolicyd)
 * [some core JS routines implemented in Ruby](https://github.com/Oblong/js-Ruby)

Since these libraries are being written in response to this project, it can be assumed (2011-09)
that the versions in the repository here are the relevant ones neede and will be updated appropriately.

## Gems you'll need

 * uuid
 * cgi
 * rack
 * json
 * eventmachine
 * A webserver (rainbows! or Thin are good)

## Notes

 * node_modules imported directory from socket.io
 * Wrote in Ruby 1.8.7-p334 on Ubuntu 10.04. That's the testing ground too; your mileage may vary.
 * A number of ancillary libraries had to be created and maintained to reach the design goal.

## Contact
  * [Socket.IO-Ruby Mailing List](http://groups.google.com/group/socketio-ruby)
  * [Socket.IO Main Mailing List](http://groups.google.com/group/socket_io/)

## History

 * 2011-08-25 Handshaking working
 * 2011-08-23 Bootstrapping right. This is big! :)
 * 2011-08-18 Still working on the other libraries.
 * 2011-08-11 Not done yet; don't expect it to work. It's really close though.

