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

class RubarbBot
  def initialize(server, port, nick, channels=[], admins=[])
    @channels = channels
    @admins = admins
    @mood = 0
    @nick = nick
    @last_message = ""
    @socket = LoggingTCPSocket.new(server, port)
    @socket.puts "NICK #{nick}"
    @socket.puts "USER #{nick} #{nick} #{nick} #{nick}"
  end

  def autojoin
    @channels.each do |channel|
      @socket.puts "JOIN #{channel}"
    end
  end

  def privmsg(channel, message)
    @socket.puts "PRIVMSG #{channel} :#{message}"
  end

  def handle(command, nick, channel)
    case command.strip
    when "ping"
      "pong"
    when "counter"
      @mood
    when /divide by zero/
      1 / 0
    when /divide (-?[\d.]+) by (-?[\d.]+)/
      $1.to_f / $2.to_f
    when /(useless|suck|dumb|stupid)/
      @mood -= 1
    when /(useful|awesome|rock|smart)/
      @mood += 1
    end
  end

  def handle_admin(command, nick, channel)
    case command.strip
    when /^say (#\S+) (.+)/
      privmsg($1, $2)
    when /^say (.+)/
      privmsg(channel, $1)
    when /^join (.+)/
      @socket.puts "JOIN #{$1}"
    when /^part (.+)/
      @socket.puts "PART #{$1}"
    when /^eval (.+)/
      eval($1).inspect
    when /^spam (\d+) ([\d.]+) (.+)/
      (1..($1.to_i)).each do |i|
        sleep $2.to_f
        privmsg(channel, $3)
      end
    when /^spam (\S+) (\d+) ([\d.]+) (.+)/
      (1..($2.to_i)).each do |i|
        sleep $3.to_i
        privmsg($1, $4)
      end
    when /(\S+)(.*)/
      privmsg(channel, "\x01ACTION #{$1}s#{$2}\x01")
    end
  end

  def respond(nick, user, hostname, channel, message)
    case message
    when /^#{@nick}[:,]\s+(.+)/
      command = $1
      begin
        response = handle(command, nick, channel)
        response = handle_admin(command, nick, channel) if not response and @admins.any? {|admin| "#{nick}!#{user}@#{hostname}" =~ admin}
      rescue
        response = "Error: #{$!} at #{$@.first}"
      end
      privmsg(channel, "#{nick}: #{response}") if response
    when /(-+)/
      @mood -= $1.length
    when /(\++)/
      @mood += $1.length
    end
    @last_message = message
  end

  def run
    while line = @socket.gets
      case line
      when /:[^ ]+ 001/
        autojoin
      when /PING :(.*)/
        @socket.puts "PONG :#{$1}"
      when /:([^!]+)!([^@]+)@(\S+) PRIVMSG (\S+) :(.+)/
        respond($1, $2, $3, $4, $5)
      end
    end
  end
end

bot = RubarbBot.new("irc.ninthbit.net", 6667, "rubarb", ["#bots"], [/^curtis!curtis@.+\.dsl\.bell\.ca$/])
bot.run
