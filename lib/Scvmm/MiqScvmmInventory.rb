$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}/../util/win32")
require 'miq-xml'
require 'miq-powershell'
require 'miq-powershell-daemon'
require 'MiqScvmm'
require 'MiqScvmmHost'
require 'MiqScvmmVm'

class MiqScvmmInventory
  def initialize(server, username, password)
    @server, @username, @password = server, username, password
    self.connect
  end

  def connect()
    @psd = MiqPowerShell::Daemon.new()
    @psd.connect
  end

  def disconnect()
    @psd.disconnect
  end

  def refresh(ps_xml_file=nil)
    ps_objects = MiqPowerShell.ps_xml_to_hash(ps_xml_file) unless ps_xml_file.nil?
    ps_objects = get_objects() if ps_objects.nil?
    if block_given?
      yield ps_objects
    else
      return ps_objects
    end
  end

  def get_objects()
    return collect_full()
  end

  def collect_full()
    ps_script = <<-EOL
    $ems_data = @{}
    $ems_data['ems'] = $scvmm['#{@server}']
    $ems_data['host'] = Get-VmHost -VMMServer $scvmm['#{@server}']
    $ems_data['vm'] = Get-Vm -VMMServer $scvmm['#{@server}']
    $ems_data['network'] = Get-VirtualNetwork -VMMServer $scvmm['#{@server}']
    $ems_data['folder'] = Get-VMHostGroup -VMMServer $scvmm['#{@server}']
    $ems_data
    EOL

    script = self.ps_cache_server_command() + ps_script.chomp!
    @psd.run_script(script, :object)
  end

  def collect_ems_host()
    collect_hash_data(:server)
  end

  def collect_vm_host()
    collect_hash_data(:host)
  end

  def collect_vm()
    collect_hash_data(:vm)
  end

  def collect_network()
    collect_hash_data(:network)
  end

  def collect_folder()
    collect_hash_data(:folder)
  end

  def collect_hash_data(type)
    @psd.run_script(send("load_#{type}_command".to_sym), :object)
  end

  def ps_cache_server_command
    MiqScvmm.ps_cache_server_command(@server, @username, @password)
  end

  def load_server_command()
    self.ps_cache_server_command() + "$scvmm['#{@server}']"
  end

  def load_host_command()
    self.ps_cache_server_command() + "Get-VmHost -VMMServer $scvmm['#{@server}']"
  end

  def load_vm_command()
    self.ps_cache_server_command() + "Get-Vm -VMMServer $scvmm['#{@server}']"
  end

  def load_network_command()
    self.ps_cache_server_command() + "Get-VirtualNetwork -VMMServer $scvmm['#{@server}']"
  end

  def load_folder_command()
    self.ps_cache_server_command() + "Get-VMHostGroup -VMMServer $scvmm['#{@server}']"
  end

  def self.to_inv_h(ems_data)
    ems_data = ems_data[0] if ems_data.kind_of?(Array)
    ems_data[:ems] = ems_data[:ems].to_miq_a
    ems_data[:host] = ems_data[:host].to_miq_a
    ems_data[:vm] = ems_data[:vm].to_miq_a
    ems_data[:network] = ems_data[:network].to_miq_a
    ems_data[:folder] = ems_data[:folder].to_miq_a
    
    ems = {:hosts => [], :storages => [], :vms => [], :folders=>[], :uid_lookup => {}}

    begin
      props = ems_data[:ems][0][:Props]
      ems[:name]=props[:FQDN]
      ems[:emstype]='scvmm'
      ems[:hostname]=props[:FQDN]
      ems[:ipaddress]=props[:Name]

      ems[:uid_lookup][:folders]={}
      ems_data[:folder].each do |f|
        fi = folders_to_inv_h(f)
        ems[:folders] << fi
        ems[:uid_lookup][:folders][fi[:uid_ems]]=fi
      end

      ems[:uid_lookup][:hosts]={}
      ems[:uid_lookup][:storages]={}
      ems_data[:host].each do |h|
        host = MiqScvmmHost.new(nil, h)
        hi = host.to_inv_h
        ems[:uid_lookup][:hosts][hi[:uid_ems]] = hi
        #hi.delete(:uid_ems)
        ems[:hosts] << hi
        hi[:storages].each do |si|
          ems[:storages] << si
          ems[:uid_lookup][:storages][si[:uid_ems]] = si
          si.delete(:uid_ems)
        end
      end

      ems[:uid_lookup][:vms]={}
      ems_data[:vm].each do |v|
        vm = MiqScvmmVm.new(nil, v)
        vi = vm.to_inv_h
        host_uid = vi.delete(:host_uid)
        host = ems[:uid_lookup][:hosts][host_uid]
        host[:vms] << vi
        ems[:vms] << vi
        ems[:uid_lookup][:vms][vi[:vmm_uuid]] = vi
        vi[:host] = host
      end

      # Do linkups
      [:link_folders_to_folders, :link_hosts_to_folders, :link_vm_to_storage]. each do |meth_name|
        self.send(meth_name, ems)
      end

      # Cleanup
      self.delete_uid_ems(ems, :hosts)
    rescue => err
      puts err
      puts err.backtrace.join("\n")
    end
    
    return ems
  end

  def self.delete_uid_ems(ems, type)
    ems[:uid_lookup][type].each {|id, c| 
      c.delete(:uid_ems)
    }
  end

  def self.networks_to_inv_h(inv)
    props = inv[:Props]
    {
      :device_name => props[:Name],
      :device_type => 'ethernet',
      :location => nil,
      :controller_type => 'ethernet',
      :present => true,
      :start_connected => nil,
      :uid_ems => props[:ID].downcase,
      :uid_host => props[:VMHostID]
    }
  end

  def self.folders_to_inv_h(inv)
    props = inv[:Props]
    {
      :name => props[:Name],
      :is_datacenter => false,
      :uid_ems => props[:ID].downcase,
      :full_path => inv[:ToString]
    }
  end

  def self.link_folders_to_folders(ems)
    ems[:folders].each do |f|
      f[:ems_children] ||= {}
      ems[:folders].each do |cf|
        parent_path = File.dirname(cf[:full_path])
        if parent_path == f[:full_path]
          f[:ems_children][:folders] ||= []
          f[:ems_children][:folders] << cf
        end
      end

      # Mark root folder as ems starting point
      ems[:ems_root] = f if f[:full_path].split('\\').length == 1
    end
    ems[:folders].each {|f| f.delete(:full_path)}
  end

  def self.link_hosts_to_folders(ems)
    ems[:hosts].each do |h|
      uid_folder = h.delete(:uid_folder)
      unless uid_folder.nil?
        ems[:uid_lookup][:folders][uid_folder][:ems_children][:hosts] ||= []
        ems[:uid_lookup][:folders][uid_folder][:ems_children][:hosts] << h
      end
    end
  end

  def self.link_vm_to_storage(ems)
    ems[:vms].each do|v|
      s = ems[:storages].detect {|s| v[:location].include?(s[:location])}
      v[:storage] = s
      v[:location] = v[:location][s[:name].length..-1] unless s.nil?
    end
  end
end # class MiqScvmmInventory
