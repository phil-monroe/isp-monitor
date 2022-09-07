#!/usr/bin/env ruby

SERVICE = 'monitor-ip-address'
require_relative 'lib/environment'
require 'socket'

def public_ipv4
  Resolv::DNS.open(nameserver: 'ns1.google.com') do |dns|
    dns.timeouts = 3
    dns.getresource('o-o.myaddr.l.google.com', Resolv::DNS::Resource::IN::TXT).strings.first
  end
rescue StandardError => e
  puts e.inspect
  puts e.backtrace
  nil
end

def private_ips
  addr_infos = Socket.getifaddrs
  addr_infos.map do |addr_info|
    next unless addr_info.name =~ /\Aen/
    next unless addr_info.addr.present?

    if addr_info.addr.ipv4?
      [ "private_#{addr_info.name}_ipv4", addr_info.addr.ip_address.to_s ]
    elsif addr_info.addr.ipv6?
      [ "private_#{addr_info.name}_ipv6", addr_info.addr.ip_address.to_s ]
    end
  end.compact.to_h
end


def log_ips
  log_event 'ip-address', { public_ipv4: public_ipv4, **private_ips }
end



# initial run
log_ips

# # then every 10 minutes after that
scheduler do
  every '10s', overlap: false do
    log_ips
  end
end