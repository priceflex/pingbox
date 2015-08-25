#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
# or
#
# require "bundler"
# Bundler.setup
#
# if you use Bundler

require 'amqp'

AMQP.start("amqp://localhost") do |connection|
  ch = AMQP::Channel.new(connection)
  qu = ch.queue("amqpgem.examples.hello_world", :auto_delete => false)
  exchange = ch.default_exchange

  val = "Testing" 
  ch.direct("").publish "#{val}", :routing_key => "amqpgem.examples.hello_world"
  ch.direct("").publish "#{val}", :routing_key => "amqpgem.examples.hello_world"

  #EventMachine.run do
    #exchange.delete
    #connection.close { EventMachine.stop }
  #end
  
  show_stopper = Proc.new {
    connection.close { EventMachine.stop }
  }

  EM.add_timer(0.1, show_stopper)

end
