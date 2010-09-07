#!/usr/bin/env ruby

require 'socket'

class LoggingTCPSocket < TCPSocket
  def initialize(host, port, file=STDOUT)
    super(host, port)
    @file = file
  end
  
  def puts(s)
    @file.puts "<<<#{s}"
    super s
  end

  def gets
    super.tap{|s| @file.puts ">>>#{s}" }
  end
end

class ContextBot
  def initialize(server, port, nick, channels=[])
    @channel = channels
    @context = {}
    @socket = LoggingTCPSocket.new(server, port)
    @socket.puts "NICK #{nick}"
    @socket.puts "USER #{nick} #{nick} #{nick} #{nick}"
  end

  def autojoin
    @channel.each do |channel|
      @socket.puts "JOIN #{channel}"
    end
  end

  def notice(user, message)
    @socket.puts "NOTICE #{user} :#{message}"
  end

  def run
    while line = @socket.gets
      case line.strip
      when /:[^ ]+ 001/
        autojoin
      when /^:([^!]+)[^ ]+ PRIVMSG ([^ ]+) :context\?$/
        if @context[$2]
          @context[$2].each do |context|
            notice($1, context)
            sleep 0.5
          end
        end
      when /^:([^!]+)[^ ]+ PRIVMSG ([^ ]+) :\x01ACTION ([^\x01]+)\x01$/
        if @context[$2]
          @context[$2] << "* #{$1} #{$3}"
          if @context[$2].length > 7
            @context[$2] = @context[$2][1..-1]
          end
        else
          @context[$2] = ["* #{$1} #{$3}"]
        end
      when /^:([^!]+)[^ ]+ PRIVMSG ([^ ]+) :(.+)$/
        if @context[$2]
          @context[$2] << "<#{$1}> #{$3}"
          if @context[$2].length > 7
            @context[$2] = @context[$2][1..-1]
          end
        else
          @context[$2] = ["<#{$1}> #{$3}"]
        end
      end
    end
  end
end

bot = ContextBot.new("irc.ninthbit.net", 6667, "context", ["#programming", "#bots", "#offtopic"])
bot.run
