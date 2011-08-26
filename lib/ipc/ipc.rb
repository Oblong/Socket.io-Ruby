# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

class Ipc
  attr :session, true
  attr :client, true

  def initialize(session = nil, client = nil); end

  def isMine(protein); end

  def get; end

  def put(oper, param2=nil); end

  def error(type, data); end

end
