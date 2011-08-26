# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

require 'rubygems'
require 'json'
require 'uuid'
require 'cgi'
require 'digest/md5'
require 'uri'

ROOT = File.expand_path(File.dirname(__FILE__))

module SocketIO
  autoload :Logger, "#{ROOT}/logger"
end

autoload :Manager, "#{ROOT}/manager"
autoload :SocketNamespace, "#{ROOT}/namespace"
autoload :Manager, "#{ROOT}/manager"
autoload :Parser, "#{ROOT}/parser"

autoload :Store, "#{ROOT}/store/store"
autoload :FileSession, "#{ROOT}/store/FileSession"
autoload :Memory, "#{ROOT}/store/memory"
autoload :Socket, "#{ROOT}/socket"

require "#{ROOT}/transport"

Manager.new HTTP::server
