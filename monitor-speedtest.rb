#!/usr/bin/env ruby

SERVICE = 'monitor-speedtest'
require_relative 'lib/environment'

def speedtest
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

# initial run
speedtest

# then every 10 minutes after that
scheduler do
  every '10m', overlap: false do
    speedtest
  end
end
