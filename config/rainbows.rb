# socket.io-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
#
# Derived from
# socket.io-node
# Copyright(c) 2011 LearnBoost <dev@learnboost.com>
# MIT Licensed

require "rubygems"

timeout 30

listen "*:8080", :backlog => 2048

preload_app (true)

=begin
before_fork do |server, worker|
end

after_fork do | server, worker |
end
=end

worker_processes 10
Rainbows! do
  use :ThreadPool
  worker_connections 10
  client_max_body_size 2 * 1024 * 1024 * 1024
end
