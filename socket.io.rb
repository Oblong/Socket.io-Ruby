$base = File.dirname(__FILE__)

$:.unshift $base, $base + '/store/'

require 'rubygems'
require 'rack'
require 'json'
require 'uuid'
require 'cgi'


require 'FileSession'
require 'ipc'
require 'manager'
