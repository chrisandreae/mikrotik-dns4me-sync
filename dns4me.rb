#!/usr/bin/env ruby

require 'net/http'
require 'mtik'
require 'loadable_config'

class AppConfig < LoadableConfig
  attributes :routeros_host, :routeros_user, :routeros_password, :d4m_guid
  config_file 'config.yml'
end

@mt = MTik::Connection.new(host: AppConfig.routeros_host,
                           user: AppConfig.routeros_user,
                           pass: AppConfig.routeros_password,
                           ssl: true)

def mtik(cmd, *args)
  response = @mt.get_reply(cmd, *args)

  r_result = response.select { |x| x.has_key? '!re' }
  r_trap = response.select { |x| x.has_key? '!trap' }

  unless r_trap.empty?
    raise "Mikrotik error #{r_trap.first['message']}"
  end
  r_result
end

d4m_uri = URI.parse("https://dns4me.net/api/v2/get_hosts/hosts/#{AppConfig.d4m_guid}")
# openssl 1.0.2 incorrectly picks an expired certificate chain. modern openssl doesn't work with mtik gem.
# give up and shell out to curl
d4m_host_file = `curl -s #{d4m_uri}`
raise "No hosts retrieved" if d4m_host_file.size.zero?

d4m_hosts = d4m_host_file.each_line.with_object({}) do |l, h|
  if m = /^([0-9\.]+)\s+(\S+)$/.match(l)
    ip, name = m.captures
    ip = '127.0.0.1' if ip == '0.0.0.0'
    h[name] = ip
  end
end

puts "Retrieved #{d4m_hosts.size} mappings"

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


if rm_list.empty?
  puts "No hosts to remove"
else
  print "Removing #{rm_list.size} mappings"
  rm_list.each_slice(100) do |slice|
    print '.'
    mtik('/ip/dns/static/remove', "=.id=#{slice.join(',')}")
  end
  puts '.'
end

# Add remaining hosts
if d4m_hosts.empty?
  puts "No hosts to add"
else
  d4m_hosts.each do |name, ip|
    puts "Adding mapping: #{name} => #{ip}"
    mtik('/ip/dns/static/add', "=name=#{name}", "=address=#{ip}", "=comment=dns4me", "=ttl=1m")
  end
end
