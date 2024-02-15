#!/usr/bin/env ruby

SERVICE='monitor-healthcheck'
CHECK_INTERVAL = ENV.fetch('INTERVAL', '1m')

require_relative 'lib/environment'

def check!
  uri = URI("https://hc-ping.com/5d4cb729-4c3a-405c-8e6c-c4d8c3d266c5")
  res = Net::HTTP.get_response(uri)

  log_event 'healthcheck', {
    response_code: res.code
  }

rescue StandardError => e
  puts e.inspect
  puts e.backtrace
end

# main script

check!

scheduler do
  every CHECK_INTERVAL, overlap: false do
    check!
  end
end
