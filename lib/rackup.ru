$:.unshift '../dep/'
require 'http'

use HTTP::FromRack

map '/' do
  require 'socket.io'
end
