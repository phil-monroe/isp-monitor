#!/usr/bin/env ruby

SERVICE='monitor-download'
CHECK_INTERVAL = ENV.fetch('INTERVAL', '1h')

require_relative 'lib/environment'

def check!
  details = download("https://gist.githubusercontent.com/khaykov/a6105154becce4c0530da38e723c2330/raw/41ab415ac41c93a198f7da5b47d604956157c5c3/gistfile1.txt")

  log_event 'download-speed', details

rescue StandardError => e
  puts e.inspect
  puts e.backtrace
end

def download(url)
  uri = URI(url)

  start_at = nil
  end_at = nil
  size_bytes = 0

  res = Net::HTTP.start(uri.hostname, use_ssl: uri.scheme == "https") do |http|
    req = Net::HTTP::Get.new(uri)
    start_at = Time.current

    http.request(req) do |res|
      res.read_body do |chunk|
        size_bytes += chunk.bytesize
      end
      end_at = Time.current
    end
  end

  duration_s = end_at - start_at
  bits = size_bytes * 8
  throughput_bps = bits / duration_s
  size_mb = size_bytes / 1024.0 / 1024.0
  throughput_mbps = throughput_bps / 1000.0 / 1000.0

  {
    url:,
    hostname: uri.hostname,
    duration_s:,
    size_bytes:,
    size_mb: size_mb.round(2),
    throughput_bps: throughput_bps.round(2),
    throughput_mbps: throughput_mbps.round(2),
    response_code: res.code,
    response_headers: res.to_hash,
  }
end

# main script

check!

scheduler do
  every CHECK_INTERVAL, overlap: false do
    check!
  end
end
