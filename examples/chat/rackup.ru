# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

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
