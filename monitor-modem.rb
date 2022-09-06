#!/usr/bin/env ruby

require_relative 'lib/environment'

def log_event(event, payload={})
  LOGGER.info message: event, host: {name: 'localhost'},  **payload
end

log_event('start')


def fetch_modem_data
  ip  = ENV['MODEM_IP'] || '192.168.100.1'
  uri = URI("https://#{ip}")

  Net::HTTP.start(uri.host, uri.port, :use_ssl => true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new uri
    request['Content-Type'] = 'application/json'
    request['SOAPACTION']   = 'http://purenetworks.com/HNAP1/GetMultipleHNAPs'
    request.body = '{"GetMultipleHNAPs":{"GetMotoStatusStartupSequence":"","GetMotoStatusConnectionInfo":"","GetMotoStatusDownstreamChannelInfo":"","GetMotoStatusUpstreamChannelInfo":"","GetMotoLagStatus":"","GetMotoStatusLog":""}}'

    response = http.request(request)
    JSON.parse(response.body)['GetMultipleHNAPsResponse']
  end
end

def parse_modem_table(string, headers=[])
  table = string.split(/\|\+\||\}-\{/) # split into rows
    .map { |row| row.split('^') } # split into columns
    .map do |row| # type cast values
      row.map do |value|
        case value.strip
        when %r{\A\d+\z}
          value.to_i
        when %r{\A\d+\.\d+\z}
          value.to_f
        else
          value
        end
      end
    end

  if headers.present?
    table = table.map { |row| headers.zip(row).to_h }
  end

  table
end

def log_basic_details(modem_data)
  puts "as of time: #{Time.current}"
  puts modem_data
end

DOWNSTREAM_CHANNELS = {}
def log_downstream_channel(channel)
  previous_details = DOWNSTREAM_CHANNELS[channel[:channel]]

  if previous_details.present?
    channel[:corrected_delta]   = channel[:corrected] - previous_details[:corrected]
    channel[:uncorrected_delta] = channel[:uncorrected] - previous_details[:uncorrected]
    channel[:uncorrected_rate]  = channel[:corrected_delta].zero? ? 0 : channel[:uncorrected_delta].to_f / channel[:corrected_delta] * 100.0
  end

  puts channel
  log_event 'downstream.channel.details', channel

ensure
  DOWNSTREAM_CHANNELS[channel[:channel]] = channel
end

def log_upstream_channel(channel)
  log_event 'upstream.channel.details', channel
end

MODEM_TIMEZONE = Time.find_zone(ENV['MODEM_TIMEZONE'] || 'America/Chicago')
$RECENT_EVENT_LINES = []
def log_event_log(line)
  line[:event_time] = MODEM_TIMEZONE.parse(line[:date] + ' ' + line[:time])
  return if line[:event_time] < 2.minutes.ago
  return if $RECENT_EVENT_LINES.include?(line)

  $RECENT_EVENT_LINES << line
  log_event 'event_log', line
end

def flush_stale_logs
  $RECENT_EVENT_LINES = $RECENT_EVENT_LINES.select { |line| line[:event_time] > 3.minutes.ago }
end


loop do
  begin
    puts "---- FETCHING ----"
    modem_data = fetch_modem_data
    downstream_channels = parse_modem_table(modem_data.dig('GetMotoStatusDownstreamChannelInfoResponse', 'MotoConnDownstreamChannel'), [:channel, :lock_status, :modulation, :channel_id, :frequency, :power, :snr, :corrected, :uncorrected])
    upstream_channels   = parse_modem_table(modem_data.dig('GetMotoStatusUpstreamChannelInfoResponse', 'MotoConnUpstreamChannel'), [:channel, :lock_status, :channel_type, :channel_id, :symbol_rate, :frequency, :power])
    event_logs          = parse_modem_table(modem_data.dig('GetMotoStatusLogResponse', 'MotoStatusLogList'), [:time, :date, :event_severity, :event_message])

    puts "---- DETAILS ----"
    log_basic_details(modem_data)

    puts "---- DOWNSTREAM CHANNELS ----"
    downstream_channels.each do |channel|
      log_downstream_channel(channel)
    end
    puts

    puts "---- UPSTREAM CHANNELS ----"
    upstream_channels.each do |channel|
      log_upstream_channel(channel)
    end
    puts

    puts "---- EVENT LOGS ----"
    event_logs.each do |line|
      log_event_log(line)
    end
    flush_stale_logs
    puts

    # binding.pry
    # break

  rescue StandardError => e
    puts e.inspect
    puts e.backtrace
  end

  # sleep until the next minute
  sleep_until = 1.minute.from_now.change(sec: 0)
  sleep_seconds = sleep_until - Time.current
  sleep(sleep_seconds)
end

