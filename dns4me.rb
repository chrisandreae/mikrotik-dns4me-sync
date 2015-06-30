require 'net/http'
require 'mtik'

ROUTEROS_HOST     = 
ROUTEROS_USER     = 
ROUTEROS_PASSWORD = 
D4M_GUID          = 

def mtik(*cmd)
  response = MTik::command(:host => ROUTEROS_HOST,
                           :user => ROUTEROS_USER,
                           :pass => ROUTEROS_PASSWORD,
                           :limit => 100000,
                           :command => cmd).first

  r_result = response.select { |x| x.has_key? '!re' }
  r_trap = response.select { |x| x.has_key? '!trap' }

  unless r_trap.empty?
    raise "Mikrotik error #{r_trap.first['message']}"
  end
  r_result
end

d4m_uri = URI.parse("https://dns4me.net/user/hosts_file_api/#{D4M_GUID}")
d4m_hosts = Net::HTTP.get(d4m_uri).each_line.with_object({}) do |l, h|
  if m = /^([0-9\.]+)\s+(\S+)$/.match(l)
    ip, name = m.captures
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
  mtik('/ip/dns/static/remove', "=.id=#{rm_list.join(',')}")
end

# Add remaining hosts
d4m_hosts.each do |name, ip|
  puts "Adding mapping: #{name} => #{ip}"
  mtik('/ip/dns/static/add', "=name=#{name}", "=address=#{ip}", "=comment=dns4me", "=ttl=1m")
end
