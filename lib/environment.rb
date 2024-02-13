require 'bundler/setup'
Bundler.require

require 'net/http'
require 'active_support/core_ext'
require 'net/http'
require 'json'

LOGSTASH_HOST = ENV.fetch('LOGSTASH_HOST', '').strip.presence

outputs = [ { type: :stdout } ]
outputs << { type: :tcp, host: LOGSTASH_HOST, port: 50000 } if LOGSTASH_HOST.present?

LOGGER = LogStashLogger.new(type: :multi_delegator, outputs: outputs)

def log_event(event, payload={})
  LOGGER.info message: event, service: SERVICE, **payload
end

log_event('start')


def scheduler(&block)
  scheduler = Rufus::Scheduler.new
  scheduler.instance_exec(&block)
  scheduler.join
end

def http_get_json(url)
  uri = URI(url)
  JSON.parse(Net::HTTP.get(uri), symbolize_names: true)
end
