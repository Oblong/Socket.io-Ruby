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
require 'eventmachine'

ROOT = File.expand_path(File.dirname(__FILE__))
DEP = ROOT + '/../dep'

require "#{DEP}/js"
autoload :EventEmitter, "#{DEP}/EventEmitter"

module SocketIO
  autoload :Logger, "#{ROOT}/logger"
end

autoload :Manager, "#{ROOT}/manager"
autoload :SocketNamespace, "#{ROOT}/namespace"
autoload :Manager, "#{ROOT}/manager"
autoload :Parser, "#{ROOT}/parser"

autoload :Store, "#{ROOT}/stores"
autoload :Disk, "#{ROOT}/stores/disk"
autoload :Redis, "#{ROOT}/stores/redis"
autoload :FileSession, "#{ROOT}/stores/FileSession"
autoload :Memory, "#{ROOT}/storex/memory"
autoload :Socket, "#{ROOT}/socket"

module Transports
  autoload :Base, "#{ROOT}/transports/base"
  autoload :FlashSocket, "#{ROOT}/transports/flashsocket"
  autoload :HTTPTransport, "#{ROOT}/transports/http"
  autoload :HTMLFile, "#{ROOT}/transports/htmlfile"
  autoload :HttpPolling, "#{ROOT}/transports/http-polling"
  autoload :JsonpPolling, "#{ROOT}/transports/jsonp-polling"
  autoload :WebSocket, "#{ROOT}/transports/websocket"
  autoload :XhrPolling, "#{ROOT}/transports/xhr-polling"
end

Manager.new HTTP::server
