require 'rubygems'
require 'rack'
require 'yaml'
$:.unshift '../../dep/', '../../lib'
require 'http'

use HTTP::FromRack, :paths => [ '/socket.io' ]

map '/' do
  run Rack::Directory.new(File.dirname(__FILE__))
end

map '/socket.io' do
  require 'socket.io'
end
