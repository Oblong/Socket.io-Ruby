# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

# node transport.js is in transports/base.rb
module Transports
  autoload :Base, 'transports/base'
  autoload :FlashSocket, 'transports/flashsocket'
  autoload :HTTP, 'transports/http'
  autoload :HTMLFile, 'transports/htmlfile'
  autoload :HTTPPolling, 'transports/http-polling'
  autoload :JSONPPolling, 'transports/jsonp-polling'
  autoload :WebSocket, 'transports/websocket'
  autoload :XhrPolling, 'transports/xhr-polling'
end
