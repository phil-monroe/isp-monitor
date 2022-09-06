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
  LOGGER.info message: event, service: 'monitor-ping', **payload
end

log_event('start')


def ping(target, count: 10)
  icmp = Net::Ping::ICMP.new(target)

  response_times = []
  ping_fails = 0

  count.times.each do
    begin
      if icmp.ping
        response_times << icmp.duration
      else
        ping_fails += 1
      end
    rescue StandardError => e
      puts e.inspect
      ping_fails += 1
    end
  end

  avg_rtt = if response_times.present?
    (response_times.sum / response_times.count).round(4)
  end

  jitter = if response_times.count >= 2
    jitter_diffs = response_times.each_cons(2).map { |a,b| (a-b).abs }
    (jitter_diffs.sum / jitter_diffs.count).round(4)
  end

  packet_loss = (ping_fails.to_f / count.to_f * 100.0).round(2)

  log_event 'ping', {
    ping_target:      target,
    ping_avg_rtt:     avg_rtt,
    ping_avg_jitter:  jitter,
    ping_packet_loss: packet_loss,
    ping_attempts:    count,
    ping_fails:       ping_fails
  }

rescue StandardError => e
  puts e.inspect
  puts e.backtrace
end

loop do
  ARGV.each do |ping_target|
    ping ping_target
  end

  # sleep until the next minute
  sleep_until = 1.minute.from_now.change(sec: 0)
  sleep_seconds = sleep_until - Time.current
  # sleep(sleep_seconds)
  sleep 10
end

