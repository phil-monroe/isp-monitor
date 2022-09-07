require 'bundler/setup'
Bundler.require

require 'net/http'
require 'active_support/core_ext'

LOGGER = LogStashLogger.new(
  type: :multi_delegator,
  outputs: [
    { type: :stdout },
    { type: :tcp, host: 'localhost', port: 50000 }
  ])

def log_event(event, payload={})
  LOGGER.info message: event, service: SERVICE, **payload
end

log_event('start')


def scheduler(&block)
  scheduler = Rufus::Scheduler.new
  scheduler.instance_exec(&block)
  scheduler.join
end