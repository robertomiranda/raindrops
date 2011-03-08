# -*- encoding: binary -*-
require 'raindrops'

# Raindrops middleware should be loaded at the top of Rack
# middleware stack before other middlewares for maximum accuracy.
class Raindrops::Middleware
  attr_accessor :app, :stats, :path, :tcp, :unix

  # :stopdoc:
  Stats = Raindrops::Struct.new(:calling, :writing)
  PATH_INFO = "PATH_INFO"
  require "raindrops/middleware/proxy"
  autoload :TCP, "raindrops/middleware/tcp"
  # :startdoc:

  def initialize(app, opts = {})
    @app = app
    @stats = opts[:stats] || Stats.new
    @path = opts[:path] || "/_raindrops"
    tmp = opts[:listeners]
    if tmp.nil? && defined?(Unicorn) && Unicorn.respond_to?(:listener_names)
      tmp = Unicorn.listener_names
    end
    @tcp = @unix = nil

    if tmp
      @tcp = tmp.grep(/\A.+:\d+\z/)
      @unix = tmp.grep(%r{\A/})
      @tcp = nil if @tcp.empty?
      @unix = nil if @unix.empty?
    end
  end

  # standard Rack endpoint
  def call(env)
    env[PATH_INFO] == @path and return stats_response
    begin
      @stats.incr_calling

      status, headers, body = @app.call(env)
      rv = [ status, headers, Proxy.new(body, @stats) ]

      # the Rack server will start writing headers soon after this method
      @stats.incr_writing
      rv
    ensure
      @stats.decr_calling
    end
  end

  def stats_response
    body = "calling: #{@stats.calling}\n" \
           "writing: #{@stats.writing}\n"

    if defined?(Raindrops::Linux)
      Raindrops::Linux.tcp_listener_stats(@tcp).each do |addr,stats|
        body << "#{addr} active: #{stats.active}\n" \
                "#{addr} queued: #{stats.queued}\n"
      end if @tcp
      Raindrops::Linux.unix_listener_stats(@unix).each do |addr,stats|
        body << "#{addr} active: #{stats.active}\n" \
                "#{addr} queued: #{stats.queued}\n"
      end if @unix
    end

    headers = {
      "Content-Type" => "text/plain",
      "Content-Length" => body.size.to_s,
    }
    [ 200, headers, [ body ] ]
  end
end
