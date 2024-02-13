#!/usr/bin/env ruby

SERVICE='monitor-mifi'
require_relative 'lib/environment'

def check!
  usage = http_get_json("http://192.168.1.1/apps_home/usageinfo")
  log_event 'mifi-usage', usage

rescue StandardError => e
  puts e.inspect
  puts e.backtrace
end

check!

scheduler do
  every '1h', overlap: false do
    check!
  end
end
