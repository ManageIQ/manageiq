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
  ['Compute', 'flavors',                                nil],
  ['Compute', 'tenants',                                nil],
  ['Compute', 'key_pairs',                              nil],
  ['Compute', 'quotas_for_accessible_tenants',          nil],
  ['Network', 'security_groups',                        nil],
  ['Network', 'networks',                               :neutron],
  ['Network', 'floating_ips',                           :neutron],
  ['Network', 'quotas_for_accessible_tenants',          :neutron],
  ['Compute', 'addresses',                              nil],
  ['Image',   'images',                                 nil],
  ['Volume',  'volumes',                                nil],
  ['Volume',  'list_snapshots',                         nil],
  ['Volume',  'quotas_for_accessible_tenants',          nil],
  ['Storage', 'directories',                            nil],
]

require_relative '../../bundler_setup'
require 'openstack/openstack_handle'

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

      if req_name && os_handle.detect_service(service).name != req_name
        puts "\t\tSkipping, required service: #{req_name}, not available."
        next
      end

      tota = []
      os_handle.service_for_each_accessible_tenant(service) do |svc, t|
        ret = svc.send(method)
        ret = ret.body['snapshots'] if ret.kind_of?(Excon::Response) # only one for now
        puts "\t\t#{t.name} (#{svc.class.name}): #{ret.length}"
        tota.concat(ret)
      end
      puts "\t\t\t* Total:  #{tota.length}"
      puts "\t\t\t* Unique: #{tota.uniq { |e| e.kind_of?(Hash) ? e['id'] : e.id }.length}" unless service == 'Storage'
    end
  end
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
end
