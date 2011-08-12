require 'rubygems'
require 'rack'
require 'json'
require 'uuid'
require 'cgi'

module SocketIO
  ROOT = File.expand_path(File.dirname(__FILE__))

  autoload :Logger, "#{ROOT}/logger"
  autoload :Manager, "#{ROOT}/manager"
  autoload :SocketNamespace, "#{ROOT}/namespace"
  autoload :Manager, "#{ROOT}/manager"
  autoload :Parser, "#{ROOT}/parser"
  
  autoload :Store, "#{ROOT}/store/store"
  autoload :FileSession, "#{ROOT}/store/FileSession"
  autoload :Memory, "#{ROOT}/store/memory"

  require "#{ROOT}/trasport"
end
