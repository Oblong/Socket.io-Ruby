# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

# This is NOT to transport messages between hosts but instead to save persistent meta 
# information for each host in case something crashes or becomes temporarily unavailable
class Store
  include EventEmitter
  alias subscribe on
  alias publish emit
  alias unsubscribe removeListener

  def initialize(*opts); end
  def getsession(&block); end
end
