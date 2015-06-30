require 'open-uri'
require 'pp'
require 'thread'
require 'set'
require 'pp'
require 'mtik'
require 'json'

def mtik *cmd
  response = MTik::command(
    :host => '192.168.133.1',
    :user => 'USER',
    :pass => 'PASSWORD',
    :limit => 100000,
    :command => cmd
  ).first
  r_result = response.select { |x| x.has_key? '!re' }
  r_trap = response.select { |x| x.has_key? '!trap' }
  unless r_trap.empty?
    pp cmd
    pp response
    raise "Mikrotik error #{r_trap.first['message']}"
  end
  r_result
end
                                              
def mtik_remove section, *predicates
  ids = mtik("#{section}/print", *predicates).map { |x| x['.id'] }
  unless ids.empty?
    mtik("#{section}/remove", "=.id=#{ids.join}")
  end
end

cur_hosts = mtik '/ip/dns/static/print'
#{"!re"=>nil,
#  ".tag"=>"3",
#  ".id"=>"*1",
#  "name"=>"router",
#  "address"=>"192.168.88.1",
#  "ttl"=>"1d",
#  "dynamic"=>"false",
#  "regexp"=>"false",
#  "disabled"=>"true"},
# {"!re"=>nil,
#  ".tag"=>"3",
#  ".id"=>"*4",
#  "name"=>"cdn.debian.net",
#  "address"=>"202.8.47.148",
#  "ttl"=>"1m",
#  "dynamic"=>"false",
#  "regexp"=>"false",
#  "disabled"=>"true"}]
ch = {}
cur_hosts.each { |h| ch[h['name']]=h['address'] }

d4m = {}


open('https://dns4me.net/user/hosts_file_api/DNS4ME_UUID') do |f|
  f.each do |l|
    if l =~ /^([0-9\.]+)\s+(\S+)$/
      ip = $1
      name = $2
      d4m[name] = ip
    end
  end
end

d4m.each do |name, ip|
  if ch[name] != ip
    mtik '/ip/dns/static/add', "=name=#{name}", "=address=#{ip}", "=comment=dns4me", "=ttl=1m"
  end
end
rm_list = []
mtik('/ip/dns/static/print').each do |h|
  if h['comment'] == 'dns4me' && !d4m.has_key?(h['name'])
    rm_list << h['.id']
    pp h
  end
end
unless rm_list.empty?
  mtik('/ip/dns/static/remove', "=.id=#{rm_list.join(',')}")
end