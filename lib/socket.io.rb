require 'rubygems'
require 'json'
require 'uuid'
require 'cgi'
require 'digest/md5'

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
  autoload :Socket, "#{ROOT}/socket"

  require "#{ROOT}/transport"
end
