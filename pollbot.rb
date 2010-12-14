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
    super.tap{|s| @file.puts ">>>#{s}"}
  end
end

class PollBot
  def initialize(server, port, nick, channels=[])
    @channels = channels
    @nick = nick

    @poll_topic = nil
    @poll_choices = []
    @poll_results = {}
    @poll_owner = nil
    @poll_voters = []
    @poll_timeout_thread = nil
    
    @socket = LoggingTCPSocket.new(server, port)
    @socket.puts "NICK #{nick}"
    @socket.puts "USER #{nick} #{nick} #{nick} #{nick}"
  end

  def start_poll(topic, timeout, owner, channel, choices)
    if @poll_topic
      "A poll is already in progress! Use 'end' to end the current poll."
    else
      @poll_topic = topic
      @poll_owner = owner
      @poll_choices = choices
      @poll_results = {}
      @poll_choices.each do |choice|
        @poll_results[choice] = 0
      end
      @poll_voters = []
      @poll_timeout_thread = Thread.new { sleep(timeout * 60); privmsg(channel, end_poll(@poll_owner, true)) }
      "Poll started. Use 'vote' to submit your vote. Use 'end' to end the poll."
    end
  end

  def end_poll(user, auto=false)
    if !@poll_topic
      "There is no poll in progress. Use 'start' to start a new poll."
    else
      if user != @poll_owner
        "Only the person who started this poll can end it!"
      else
        total_votes = @poll_results.values.reduce(:+)
        if total_votes == 0
          results = ["No one voted"]
        else
          results = @poll_results.map do |choice, votes|
            "#{votes} vote#{'s' if votes != 1} for #{choice} (#{(votes.to_f / total_votes.to_f *  100.0).round(2)}%)"
          end
        end
        result = "Results for #{@poll_topic}: #{results.join(', ')}."
        @poll_topic = nil
        @poll_owner = nil
        @poll_choices = []
        @poll_results = {}
        @poll_voters = []
        @poll_timeout_thread.kill unless auto
        result
      end
    end
  end

  def vote(choice, user)
    if !@poll_topic
      "There is no poll in progress. Use 'start' to start a new poll."
    elsif @poll_voters.include?(user)
      "You have already voted in this poll."
    else
      choice = @poll_choices.find{|x| x.downcase == choice.downcase}
      if !choice
        "That is not one of the choices in this poll. Use 'choices' to see a list of choices."
      else
        @poll_results[choice] += 1
        @poll_voters << user
        "Your vote has been recorded."
      end
    end
  end

  def append_choice(choice, user)
    if !@poll_topic
      "There is no poll in progress. Use 'start' to start a new poll."
    elsif user != @poll_owner
      "Only the person who started this poll can add another choice."
    elsif @poll_choices.find{|x| x.downcase == choice.downcase}
      "That is already a choice in this poll."
    else
      @poll_choices << choice
      @poll_results[choice] = 0
      "Choice added."
    end
  end

  def votes(user)
    if !@poll_topic
      "There is no poll in progress. Use 'start' to start a new poll."
    elsif user != @poll_owner
      "Only the person who started this poll can view the current votes."
    else
      total_votes = @poll_results.values.reduce(:+)
      if total_votes == 0
        results = ["No one voted"]
      else
        results = @poll_results.map do |choice, votes|
          "#{votes} vote#{'s' if votes != 1} for #{choice} (#{(votes.to_f / total_votes.to_f *  100.0).round(2)}%)"
        end
      end
      "Current votes for #{@poll_topic}: #{results.join(', ')}."
    end
  end

  def voters(user)
    if !@poll_topic
      "There is no poll in progress. Use 'start' to start a new poll."
    elsif user != @poll_owner
      "Only the person who started this poll can view who has voted."
    else
      "People who voted on this poll: #{@poll_voters.join(', ')}"
    end
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
    when /^start ([^ ]+) or ([^ ]+)$/
      start_poll("#{$1} or #{$2}", 5, nick, channel, [$1, $2])
    when /^start ([^?]+[?])$/
      start_poll($1, 5, nick, channel, ["Yes", "No"])
    when /^start ([\d.]+) ([^:]+): (.+)/
      if $3.include? ";"
        start_poll($2, $1.to_f, nick, channel, $3.split(";").map{|x| x.strip})
      else
        start_poll($2, $1.to_f, nick, channel, $3.split(",").map{|x| x.strip})
      end
    when /^start ([^:]+): (.+)/
      if $2.include? ";"
        start_poll($1, 5, nick, channel, $2.split(";").map{|x| x.strip})
      else
        start_poll($1, 5, nick, channel, $2.split(",").map{|x| x.strip})
      end
    when /^end$/
      end_poll(nick)
    when /^poll\??|topic$/
      if @poll_topic
        "The current poll topic is #{@poll_topic}. Use 'choices' to see a list of poll choices."
      else
        "There is no poll in progress. Use 'start' to start a new poll."
      end
    when /^choices$/
      if @poll_topic
        "The choices for the current poll are: #{@poll_choices.join(', ')}."
      else
        "There is no poll in progress. Use 'start' to start a new poll."
      end
    when /^(append|add) (.+)/
      append_choice($2, nick)
    when /^votes$/
      votes(nick)
    when /^voters$/
      voters(nick)
    when /^owner$/
      if @poll_topic
        "The current poll was started by #{@poll_owner}."
      else
        "There is no poll in progress. Use 'start' to start a new poll."
      end
    when /^vote (.+)/
      vote($1, nick)
    when /^help$/
      "Commands: ping, start, end, topic, choices, add, votes, voters, owner, vote"
    when /^help (.+)$/
      help = {
        "ping" => "Respond with pong. Syntax: ping",
        "start" => "Start a poll. Syntax: start [timeout] <topic>: <choice>; <choice>; ...",
        "end" => "End the current poll. Syntax: end",
        "topic" => "Respond with the current poll topic. Syntax: topic",
        "choices" => "Respond with a list of choices in the current poll. Syntax: choices",
        "add" => "Add a choice to the current poll. (Must be poll owner) Syntax: add <choice>",
        "votes" => "Respond with the current poll results without ending it. (Must be poll owner) Syntax: votes",
        "voters" => "Respond with a list of people who have voted on the current poll. (Must be poll owner) Syntax: voters",
        "owner" => "Respond with the owner of the current poll. Syntax: owner",
        "vote" => "Vote for a choice in the current poll. Syntax: vote <choice>"}
      help[$1]
    else
      vote(command.strip, nick)
    end
  end

  def respond(nick, user, hostname, channel, message)
    if channel == @nick
      privmsg(nick, handle(message, nick, nick))
    else
      case message
      when /^#{@nick}[:,]\s+(.+)/
        privmsg(channel, handle($1, nick, channel))
      end
    end
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

bot = PollBot.new("onyx.ninthbit.net", 6667, "pollbot", ["#offtopic"])
bot.run    
