#!/usr/bin/env ruby

require 'net/http'
require 'mtik'
require_relative 'loadable_config'

class AppConfig < LoadableConfig
  attributes :routeros_host, :routeros_user, :routeros_password, :d4m_guid
  config_file 'config.yml'
end

def mtik(*cmd)
  response = MTik::command(:host => AppConfig.routeros_host,
                           :user => AppConfig.routeros_user,
                           :pass => AppConfig.routeros_password,
                           :limit => 100000,
                           :command => cmd).first

  r_result = response.select { |x| x.has_key? '!re' }
  r_trap = response.select { |x| x.has_key? '!trap' }

  unless r_trap.empty?
    raise "Mikrotik error #{r_trap.first['message']}"
  end
  r_result
end

d4m_uri = URI.parse("https://dns4me.net/api/v2/get_hosts/hosts/#{AppConfig.d4m_guid}")
d4m_host_file = Net::HTTP.get(d4m_uri)
raise "No hosts retrieved" if d4m_host_file.size.zero?
d4m_hosts = d4m_host_file.each_line.with_object({}) do |l, h|
  if m = /^([0-9\.]+)\s+(\S+)$/.match(l)
    ip, name = m.captures
    ip = '127.0.0.1' if ip == '0.0.0.0'
    h[name] = ip
  end
end

rm_list = []
mtik('/ip/dns/static/print').each do |h|
  next unless h['comment'] == 'dns4me'
  name, address, id = h.values_at('name', 'address', '.id')

  if d4m_hosts[name] != address
    # Old mapping removed or changed: delete
    rm_list << id
  else
    # Mapping already present: ignore
    d4m_hosts.delete(name)
  end
end

unless rm_list.empty?
  puts "Removing #{rm_list.size} mappings"
  mtik('/ip/dns/static/remove', "=.id=#{rm_list.join(',')}")
end

# Add remaining hosts
d4m_hosts.each do |name, ip|
  puts "Adding mapping: #{name} => #{ip}"
  mtik('/ip/dns/static/add', "=name=#{name}", "=address=#{ip}", "=comment=dns4me", "=ttl=1m")
end
