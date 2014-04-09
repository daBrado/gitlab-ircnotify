require 'rubygems'
require 'bundler/setup'
require 'json'
require 'logger'
require_relative 'config'
class IRCNotifier
  def initialize
    @mutex = Mutex.new
    @last = nil
  end
  def run_irc_client
    Thread.new do
      s = UNIXSocket.new IRCNOTIFY_SOCKET
      LOG.info "IRC client thread connected to #{IRCNOTIFY_SOCKET}"
      s.puts({set_name:NAME,set_commands:['commits']}.to_json)
      s.each do |cmd|
        LOG.info "Got IRC command #{cmd.chomp}"
        if @last
          count = @last['commits'].count
          s.puts "#{count} commit#{count!=1?'s':''} to #{@last['repository']['name']} branch #{@last['ref'].split('/')[-1]}"
          @last['commits'].each do |commit|
            s.puts "#{commit['timestamp']} : #{commit['author']['name']} : #{commit['message']}"
          end
        else
          s.puts 'Sorry, there have been no pushes since I started listening.'
        end
      end
    end.abort_on_exception=true
  end
  def call(env)
    req = Rack::Request.new env
    begin
      push = JSON.parse body=req.body.read
    rescue JSON::ParserError
      LOG.error "Cannot parse request #{body}"
      return [400, {}, []]
    end
    s = UNIXSocket.new IRCNOTIFY_SOCKET
    s.puts({set_name:NAME}.to_json)
    count = push['commits'].count
    s.puts "#{push['user_name']} pushed #{count} commit#{count!=1?'s':''} to the #{push['ref'].split('/')[-1]} branch of #{push['repository']['name']}"
    @mutex.synchronize { @last = push }
    LOG.info "Push notification send to #{IRCNOTIFY_SOCKET}"
    [200, {}, []]
  end
end
irc = IRCNotifier.new
irc.run_irc_client
run irc
