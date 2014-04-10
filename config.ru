require 'rubygems'
require 'bundler/setup'
require 'json'
require 'logger'
require 'date'
require_relative 'config'
class String; def qty(n); "#{n} #{self}"+(n!=1?'s':''); end; end
class IRCNotifier
  def initialize
    @mutex = Mutex.new
    @last = nil
    @irc = nil
  end
  def notify(push, max_lines:nil)
    commits = push['commits']
    count = commits.size
    msg = []
    msg << [
      push['repository']['name'],
      push['ref'].split('/')[-1],
      push['user_name'],
      'commit'.qty(count),
      SHOW_URLS ? "#{push['repository']['homepage']}/compare/#{push['before']}...#{push['after']}" : nil
    ].join(' | ')
    msg.push(*commits.map{|commit|
      "  " + [
        commit['author']['name'],
        DateTime.parse(commit['timestamp']).strftime('%a %b %_2d %H:%M %Y'),
        commit['message'],
        SHOW_URLS ? commit['url'] : nil
      ].compact.join(' : ')
    })
    LOG.info msg
    if max_lines && msg.count > max_lines
      dropped = 1 + msg.count - max_lines
      msg = msg[0...max_lines-1]
      msg << "  (not showing remaining #{'commit'.qty(dropped)}; use !commits to see them all)"
    end
    @mutex.synchronize { msg.each{|l|@irc.puts(l)} }
    LOG.info "Push notification sent to #{IRCNOTIFY_SOCKET}"
  end
  def connect
    @irc = UNIXSocket.new IRCNOTIFY_SOCKET
    @irc.puts({set_name:NAME,set_commands:['commits']}.to_json)
    LOG.info "Connected to ircnotify @ #{IRCNOTIFY_SOCKET}"
    Thread.new do
      @irc.each do |cmd|
        LOG.info "IRC command #{cmd.chomp}"
        push = @mutex.synchronize { @last }
        if push
          notify push
        else
          @irc.puts 'no push since startup of this service'
        end
      end
    end.abort_on_exception=true
    self
  end
  def call(env)
    req = Rack::Request.new env
    begin
      push = JSON.parse body=req.body.read
    rescue JSON::ParserError
      LOG.error "Cannot parse request #{body}"
      return [400, {}, []]
    end
    @mutex.synchronize { @last = push }
    notify push, max_lines:MAX_LINES
    [200, {}, []]
  end
end
run IRCNotifier.new.connect
