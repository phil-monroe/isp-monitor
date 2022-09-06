#!/usr/bin/env ruby

require 'pry'
require 'json'
require 'net/http'
require 'net/ping'
require 'active_support'
require 'active_support/core_ext'
require 'logstash-logger'

LOGGER = LogStashLogger.new(
  type: :multi_delegator,
  outputs: [
    { type: :stdout },
    { type: :tcp, host: 'localhost', port: 50000 }
  ])

def log_event(event, payload={})
  LOGGER.info message: event, service: 'monitor-speedtest', **payload
end

log_event('start')

def run_speedtest
  # result = `cat example-speedtest.json`
  result = `speedtest --format json`
  data = JSON.parse(result)

  if data["type"] == "result"
    download_bandwidth = (data.dig("download", "bandwidth") / 125_000.0).round(3)
    upload_bandwidth   = (data.dig("upload", "bandwidth") / 125_000.0).round(3)

    ping_jitter   = data.dig("ping", "jitter")
    ping_latency  = data.dig("ping", "jitter")
    ping_low      = data.dig("ping", "jitter")
    ping_high     = data.dig("ping", "jitter")

    log_event 'speedtest', {
      speedtest_download_mbps:  download_bandwidth,
      speedtest_upload_mbps:    upload_bandwidth,

      ping_jitter:   ping_jitter,
      ping_latency:  ping_latency,
      ping_low:      ping_low,
      ping_high:     ping_high,

      speedtest_data: data
    }
  else
    log_event 'speedtest-error', speedtest_error: data
  end

rescue StandardError => e
  puts e.inspect
  puts e.backtrace
end

loop do
  run_speedtest

  # sleep until the next minute
  sleep_until = 1.minute.from_now.change(sec: 0)
  sleep_seconds = sleep_until - Time.current
  # sleep(sleep_seconds)
  sleep 10.minutes
end

