
$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../..")

CREDS = [
  {
    :ems_ip       => "1.2.3.4",
    :ems_username => "",
    :ems_password => ""
  },
  {
    :ems_ip       => "5.6.7.8",
    :ems_username => "",
    :ems_password => ""
  }
]

ACCESSORS = [
  ['Compute', 'servers',                                nil],
  ['Compute', 'servers_for_accessable_tenants',         nil],
  ['Compute', 'flavors',                                nil],
  ['Compute', 'tenants',                                nil],
  ['Compute', 'key_pairs',                              nil],
  ['Network', 'security_groups',                        nil],
  ['Network', 'security_groups_for_accessable_tenants', nil],
  ['Network', 'networks',                               :neutron],
  ['Network', 'floating_ips',                           :neutron],
  ['Image',   'images',                                 nil],
  ['Image',   'images_for_accessable_tenants',          nil]
]

require 'bundler_setup'
require 'openstack_handle'

begin
  CREDS.each do |cred|
    puts
    puts "**** #{cred[:ems_username]}@#{cred[:ems_ip]}"
    os_handle = OpenstackHandle::Handle.new(cred[:ems_username], cred[:ems_password], cred[:ems_ip])

    puts
    puts "\t**** Tenants: #{os_handle.tenants.length}"
    os_handle.tenants.each do |t|
      puts "\t\t#{t.name}\t(#{t.id})"
    end

    puts
    puts "\t**** Accessible Tenants: #{os_handle.accessible_tenants.length}"
    os_handle.accessible_tenants.each do |t|
      puts "\t\t#{t.name}\t(#{t.id})"
    end

    ACCESSORS.each do |acc|
      service, method, req_name = *acc
      puts
      puts "\t#{service}##{method}:"

      if req_name && os_handle.service_name(service) != req_name
        puts "\t\tSkipping, required service: #{req_name}, not available."
        next
      end

      tota = []
      os_handle.service_for_each_accessible_tenant(service) do |svc, t|
        ret = svc.send(method)
        puts "\t\t#{t.name} (#{svc.class.name}): #{ret.length}"
        tota.concat(ret)
      end
      puts "\t\t\t* Total:  #{tota.length}"
      puts "\t\t\t* Unique: #{tota.uniq { |e| e.id }.length}"
    end
  end
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
end
