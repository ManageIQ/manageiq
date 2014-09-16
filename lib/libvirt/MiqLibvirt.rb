$:.push("#{File.dirname(__FILE__)}/../util")
require 'miq-xml'
require 'miq-extensions'
require 'MiqSshUtil'
require 'MiqLibvirtVm'
require 'runcmd'

module MiqLibvirt
  VIR_DOMAIN_NOSTATE = 0  # no state
  VIR_DOMAIN_RUNNING = 1  # the domain is running
  VIR_DOMAIN_BLOCKED = 2  # the domain is blocked on resource
  VIR_DOMAIN_PAUSED  = 3  # the domain is paused by user
  VIR_DOMAIN_SHUTDOWN= 4  # the domain is being shut down
  VIR_DOMAIN_SHUTOFF = 5  # the domain is shut off

  class Host
    attr_reader :host

    DEBUG_PRINT = false

    def initialize(type, protocol, server, user, pwd)
      @type = type
      @protocol = protocol
      @server = server
      @user = user
      @pwd = pwd
    end

    def connect
    end

    def disconnect
    end

    def is_available?
      load_ssh_shell() do |shell|
        begin
          # System information
          virsh_hypervisor(shell)

          return @version.blank? ? false : true
        rescue
          return false
        end
      end
    end

    def refresh
      puts "[#{debug_time()}] Connecting to [#{@server}] using SSH" if DEBUG_PRINT
      load_ssh_shell() do |shell|
        puts "[#{debug_time()}] Connected to [#{@server}]" if DEBUG_PRINT

        # System information
        virsh_hypervisor(shell)

        # Stroage information
        @storages = virsh_collection('storage', 'pool-', shell)

        # Network information
        @networks = virsh_collection('network', 'net-', shell)

        # VM information
        @domains = virsh_collection('domain', nil, shell)
      end
    end

    def to_inv_h()
      ems = {:hosts => [], :storages => [], :vms => [], :folders=>[], :uid_lookup => {}}

      begin
        self.refresh
        ems[:name]=@hostname
        ems[:emstype]=@type
        ems[:hostname]=@hostname
        ems[:ipaddress]=@server

        ems[:uid_lookup][:storages] = {}
        @storages.sort! {|x,y| x[:target][:path].length <=> y[:target][:path].length}
        @storages.each do |s|
          si = self.storage_to_inv_h(s)
          ems[:storages] << si
          ems[:uid_lookup][:storages][s[:uuid]] = si
        end
        ems[:hosts] << self.host_to_inv_h(ems)
        @domains.each {|d| ems[:vms] << self.vm_to_inv_h(d, ems)}

      rescue => err
        my_logger("MiqLibVirt error: [#{err}]", :error, err)
      end

      return ems
    end

    def virsh_collection(type, cmd_prefix, shell)
      puts "[#{debug_time()}] Collecting [#{type}]" if DEBUG_PRINT
      begin
        libvirt_cmd = "#{cmd_prefix}list --all"
        result = run_virsh_command("#{libvirt_cmd}", shell)
        items = parse_virsh_list(result)

        items.each do |d|
          d[:xml_desc] = run_virsh_command("#{cmd_prefix}dumpxml #{d[:name]}", shell)
          d[:xml_desc] = MiqXml.load(d[:xml_desc])
          d = d.merge!(self.send("parse_#{type}_xml", d[:xml_desc], shell))
        end
        puts "[#{debug_time()}] Collected [#{type}]" if DEBUG_PRINT
      rescue
        my_logger("Error running virsh command #{libvirt_cmd}:  Message:[#{$!}]", :warn, $!)
        items ||= []
      end
      return items
    end

    def virsh_hypervisor(shell)
      puts "[#{debug_time()}] Collecting hostname" if DEBUG_PRINT
      @hostname = run_command("hostname", shell)

      puts "[#{debug_time()}] Collecting os information" if DEBUG_PRINT
      @operating_system = get_os_information(shell)

      result = run_command("ifconfig", shell)
      @networks_host = parse_host_network(result)

      # Basic hypervisor / hardware information
      puts "[#{debug_time()}] Collecting hypervisor version" if DEBUG_PRINT
      result = run_virsh_command("version", shell)
      @version = parse_version(result)

      puts "[#{debug_time()}] Collecting nodeinfo" if DEBUG_PRINT
      result = run_virsh_command("nodeinfo", shell)
      @hardware = parse_nodeinfo(result)

      puts "[#{debug_time()}] Hypervisor complete" if DEBUG_PRINT
    end

    def parse_virsh_list(data)
      items, columns = [], []
      data = data.split("\n")
      return items if data[0].nil?

      # Convert column names to downcased symbols
      data[0].strip.split(' ').each {|c| columns << c.downcase.to_sym}

      data[2..-1].each do |l|
        l = l.strip
        next if l.empty?
        d = l.split(' ')
        items << {columns[0]=>d[0], columns[1]=>d[1], columns[2]=>d[2..-1].join(' ')}
      end
      return items
    end

    def parse_storage_xml(xml, shell=nil)
      props = {}
      root = xml.root
      %w{name uuid capacity allocation available}.each {|attr| props[attr.to_sym] = root.elements[attr].text}
      props[:type] = root.attributes['type'].to_s.upcase
      props[:capacity] = props[:capacity].to_i
      props[:available] = props[:available].to_i

      target = root.elements['target']
      props[:target] = {:path=>target.elements['path'].text, :permissions=>{}}
      target.elements['permissions'].each_element {|e| props[:target][:permissions][e.name.to_sym] = e.text}

      source = root.elements['source']
      if source.has_elements?
        format = source.elements['format']
        props[:type] = format.attributes['type'].to_s.upcase unless format.nil?

        host = source.elements['host']
        if host
          props[:source] = {}
          props[:source][:host] = host.attributes[:name]

          %w{device dir}.each do |type|
            node = source.elements[type]
            if node
              props[:source][:type] = type.to_sym
              props[:source][:path] = node.attributes['path']
            end
          end
        end
      end

      return props
    end

    def parse_network_xml(xml, shell=nil)
      props = {}
      %w{name uuid}.each do |attr|
        props[attr.to_sym] = xml.root.elements[attr].text
      end
      return props
    end

    def parse_domain_xml(xml, shell=nil)
      props = {}
      %w{name uuid memory currentMemory vcpu on_poweroff on_reboot on_crash}.each do |attr|
        props[attr.to_sym] = xml.root.elements[attr].text
      end
      props[:type] = xml.root.attributes['type']
      props[:vcpu] = props[:vcpu].to_i
      props[:memory] = props[:memory].to_i
      props[:currentMemory] = props[:currentMemory].to_i
      props[:devices] = parse_domain_devices(xml, shell)
      props[:saved_state_file] = self.saved_file(props)
      props[:saved_state_exists] = self.file_exist?(props[:saved_state_file], shell) unless props[:saved_state_file].nil?
      return props
    end

    def parse_domain_devices(xml, shell=nil)
      devices = {:disks =>[], :networks=>[]}
      device_node = xml.root.elements['devices']

      # Process disks
      device_node.each_element('disk') do |e|
        d = e.attributes.to_h
        target = e.elements['target']
        d.merge!(target.attributes.to_h) unless target.nil?

        source = e.elements['source']
        unless source.nil?
          d[:source] = source.attributes['dev'] unless source.attributes['dev'].blank?
          d[:source] = source.attributes['file'] unless source.attributes['file'].blank?
          unless shell.nil?
            unless d[:source].blank?
              # Collect data about the disk
              begin
                data = run_command("qemu-img info \"#{d[:source]}\"", shell)
                d.merge!(parse_qemu_img(data))
              rescue
                #puts $!
              end
            end
          end
        end
        devices[:disks] << d
      end

      # Process networks
      device_node.each_element('interface') do |e|
        n = e.attributes.to_h
        e.each_element do |e2|
          h = e2.attributes.to_h
          h[e2.name.to_sym] = h[:type] if h.has_key?(:type)
          n.merge!(h)
        end
        devices[:networks] << n
      end

      return devices
    end

    def parse_qemu_img(data)
      dh = {}
      data.each_line do |l|
        item = l.split(":")
        case item[0]
        when "file format" then dh[:format] = item[1].chomp.strip
        when "virtual size" then dh[:virtual_size] = $1 if item[1] =~ /\((\d+)/
        when "disk size"
          size = item[1].chomp.strip
          dh[:disk_size] = size.to_f
          case size[-1,1]
          when 'G' then dh[:disk_size] = dh[:disk_size] * 1024 * 1024 * 1024
          when 'M' then dh[:disk_size] = dh[:disk_size] * 1024 * 1024
          when 'K' then dh[:disk_size] = dh[:disk_size] * 1024
          end
          dh[:disk_size] = dh[:disk_size].to_i
        end
      end
      return dh
    end

    def parse_version(data)
      version = {}
      data.each_line do |l|
        l = l.chomp
        comma_pos = l.index(':').to_i + 1
        if l.include?('API:')
          version[:api] = l[comma_pos..-1].strip
        elsif l.include?('hypervisor:')
          version[:hypervisor] = l[comma_pos..-1].strip
        elsif l.include?('Using library:')
          version[:libvirt] = l[comma_pos..-1].strip
        end
      end
      return version
    end

    def parse_nodeinfo(data)
      hw = {}
      data.each_line do |l|
        l = l.strip.chomp.downcase
        if l.include?('cpu model:')
          hw[:cpu_model] = l.split(' ')[-1]
        elsif l.include?('cpu(s):')
          hw[:cpus] = l.split(' ')[-1].to_i
        elsif l.include?('frequency:')
          hw[:cpu_frequency] = l.split(' ')[-2].to_i
        elsif l.include?('socket(s):')
          hw[:cpu_sockets] = l.split(' ')[-1].to_i
        elsif l.include?('core(s) per socket:')
          hw[:cores_per_socket] = l.split(' ')[-1].to_i
        elsif l.include?('thread(s) per core:')
          hw[:threads_per_core] = l.split(' ')[-1].to_i
        elsif l.include?('numa cell(s):')
          hw[:numa_cells] = l.split(' ')[-1].to_i
        elsif l.include?('memory size:')
          hw[:memory] = l.split(' ')[-2].to_i * 1024
        end
      end
      return hw
    end

    def get_os_information(shell)
      os = {}
      os[:name] = @hostname

      result = run_command("cat /etc/issue", shell)
      result = result.split("\n")
      os[:product_name] = result[0]

      result = run_command("uname -s", shell)
      os[:product_type] = result

      result = run_command("uname -r", shell)
      os[:version] = result

      return os
    end

    def parse_ifconfig_line(line)
      h = {}
      h[:data] = line.split(' ')
      h[:name] = h[:data][0]
      h[:data].each do |e|
        if e.include?(':')
          a = e.split(':')
          h[a[0].downcase.to_sym] = a[1]
        end
      end
      return h
    end

    def parse_host_network(data)
      networks = []
      device = nil
      data.each_line do |l|
        if l.include?('Link encap:')
          device = parse_ifconfig_line(l)
          networks << {:name=>device[:name], :type=>device[:encap], :macaddr=>device[:data][-1]}
        elsif l.include?('inet addr:')
          ipv4 = parse_ifconfig_line(l)
          networks.last.merge!({:ipaddr=>ipv4[:addr], :bcast=>ipv4[:bcast], :mask=>ipv4[:mask]})
        elsif l.include?('inet6 addr:')
          networks.last.merge!(:ipv6addr=>l.split(' ')[2])
        end
      end
      return networks
    end

    def host_to_inv_h(ems)
      h = {}

      h[:type] = "HostKvm"
      h[:ipaddress] = @server
      h[:power_state] = 'on'
      h[:name] = @hostname
      h[:hostname] = @hostname
      h[:vmm_vendor] = @type.to_s.downcase

      hypervisor = @version[:hypervisor].split(' ')
      h[:vmm_product] = hypervisor[0]
      h[:vmm_version] = hypervisor[1]

      h[:hardware] = self.host_hardware_to_inv_h()
      h[:operating_system] = @operating_system
      h[:storages] = ems[:storages]

      return h
    end

    def host_hardware_to_inv_h()
      h = {}
      h[:cpu_speed] = @hardware[:cpu_frequency]
      h[:memory_cpu] = @hardware[:memory] / (1024*1000)
      h[:logical_cpus] = @hardware[:cpus]
      h[:cores_per_socket] = @hardware[:cores_per_socket]
      h[:cpu_type] = @hardware[:cpu_model]
      h[:numvcpus] = @hardware[:cpu_sockets]

      h[:guest_devices], h[:networks] = host_guest_devices_to_inv_h()

      return h
    end

    def host_guest_devices_to_inv_h()
      gd, net = [], []

      @networks_host.each do |n|
        next unless n.has_key?(:ipaddr) && n[:type] == 'Ethernet'
        ni = {:description => n[:name], :ipaddress => n[:ipaddr], :subnet_mask => n[:mask]}
        dev = {:device_type=>'ethernet',
               :controller_type=>'ethernet',
               :location=>n[:name],
               :address=>n[:macaddr],
               :present=>true,
               :network=>ni}
        gd << dev
        net << ni
      end

      return gd, net
    end

    def vm_to_inv_h(domain, ems)
      v = {}
      v[:type] = "VmKvm"
      v[:connection_state] = 'connected'
      v[:vendor] = domain[:type].to_s.downcase
      v[:name] = domain[:name]
      v[:uid_ems] = domain[:uuid]

      v[:location] = File.path_to_uri("etc/libvirt/qemu/#{v[:name]}.xml", @hostname)
      v[:power_state] = MiqLibvirt::Vm.powerState(domain[:state], domain)

      v[:host] = ems[:hosts][0]
      v[:hardware] = self.vm_hardware_to_inv_h(domain)
      storages = vm_to_storages(domain, ems)
      v[:storage] = storages[0] unless storages.blank?
      return v
    end

    def vm_hardware_to_inv_h(domain)
      h = {}
      h[:memory_cpu] = domain[:currentMemory] / 1024
      h[:numvcpus] = domain[:vcpu]

      h[:guest_devices] = vm_guest_devices_to_inv_h(domain)

      return h
    end

    def vm_guest_devices_to_inv_h(domain)
      devices = []
      domain[:devices][:networks].each do |net|
        devices << {
          :device_type => 'ethernet',
          :controller_type => 'ethernet',
          :start_connected => true,
          :present => true,
          :address => net[:address],
          :device_name => net[:type]
        }
      end
      return devices
    end

    def disk_split_by_type(domain)
      paths = []
      block_dev = []

      domain[:devices][:disks].collect do |d|
        unless d[:source].nil?
          if (d[:type] == 'block')
            block_dev << d[:source]
          else
            paths << File.dirname(d[:source])
          end
        end
      end

      # Return file paths and block devices
      return paths, block_dev
    end

    def vm_to_storages(domain, ems)
      begin
        vm_storages = []
        paths, block_dev = self.disk_split_by_type(domain)

        paths.each do |p|
          #puts "Searching for: [#{p}]"
          storage = nil
          @storages.each do |s|
            if p.include?(s[:target][:path])
              #puts "Match Path:[#{p}] with Storage [#{s[:uuid]}]"
              storage = ems[:uid_lookup][:storages][s[:uuid]]
            end
          end
          vm_storages << storage unless storage.nil?
        end

        block_dev.each do |b|
          @storages.each do |s|
            if b.include?(s[:target][:path])
              if b.include?(s[:source][:host]) && b.include?(s[:source][:path])
                #puts "Match Path:[#{b}] with Storage:[#{s[:target][:path]}] with uuid:[#{s[:uuid]}]"
                vm_storages << ems[:uid_lookup][:storages][s[:uuid]]
              end
            end
          end
        end
      rescue => err
        my_logger("MiqLibVirt error: <#{err}>", :error)
        xml_desc = domain.delete(:xml_desc)
        my_logger("MiqLibVirt error: VM <#{domain[:name]}>  info: <#{domain.inspect}>", :error)
        domain[:xml_desc] = xml_desc
        my_logger("MiqLibVirt error: VM XML: <#{xml_desc.to_s}>", :error)
        my_logger("MiqLibVirt error backtrace: ", :error, err)
      end
      return vm_storages
    end

    def storage_to_inv_h(storage)
      s = {}
      s[:name] = storage[:name]
      s[:store_type] = storage[:type]
      # If the storage is only local to the box make the name unique so it does not conflict with other hosts
      s[:name] = "#{storage[:name]} - #{@hostname}" if ['DIR'].include?(s[:store_type])
      s[:total_space] = storage[:capacity]
      s[:free_space] = storage[:available]
      s[:multiplehostaccess] = false
      s[:location] = storage[:uuid]
      return s
    end

    def saved_file(domain)
      paths, block_dev = self.disk_split_by_type(domain)
      # Return nil if we do not have a place to write the "saved state" file to.
      return nil if paths.blank?

      File.join(paths.first, "#{domain[:name]}.vmss")
    end

    def debug_time()
      Time.now.strftime("%I:%M:%S")
    end

    def start(uuid)
      change_state(:start, uuid)
    end

    def stop(uuid, state_wait=60)
      state = change_state(:shutdown, uuid, state_wait)
      state = change_state(:destroy, uuid) unless state == "shut off"
      return state
    end

    # Save the state of the VM and shutdown
    def save_state(uuid)
      change_state(:save, uuid)
    end

    # Keep VM in memory but stops getting CPU cycles
    def suspend(uuid)
      change_state(:suspend, uuid)
    end

    ##################################################################
    #  Virsh 'state' commands
    #  domstate        domain state
    #  start           start a (previously defined) inactive domain
    #  shutdown        gracefully shutdown a domain
    #  destroy         destroy a domain
    #  reboot          reboot a domain
    #  restore         restore a domain from a saved state in a file
    #  resume          resume a domain
    #  save            save a domain state to a file
    #  suspend         suspend a domain
    ##################################################################
    def change_state(new_state, uuid, state_wait=30)
      libvirt_state= 'unknown'

      load_ssh_shell() do |shell|
        domain_name = run_virsh_command("domname #{uuid}", shell)
        # If the domain name includes the uuid we passed in, they its an error message saying it wasn't found.
        raise "VM with uuid [#{uuid}] was not found on host [#{@server}]" if domain_name.include?(uuid)

        libvirt_state = run_virsh_command("domstate #{uuid}", shell)
        state = MiqLibvirt::Vm.powerState(libvirt_state)

        domain = nil
        # Collect more information so we can tell between "saved state" and off.
        if ["off", "on"].include?(state)
          xml_desc = run_virsh_command("dumpxml #{uuid}", shell)
          xml_desc = MiqXml.load(xml_desc)
          domain = parse_domain_xml(xml_desc, shell)
          state = domain[:state] = MiqLibvirt::Vm.powerState(libvirt_state, domain)
        end

        # Default command to invoke state change (Nay be overridden below)
        virsh_command = "#{new_state} #{domain_name}"

        # Validate current state and modify required action based on state in needed
        case new_state
        when :start
          return libvirt_state if state == 'on'
          if libvirt_state == 'paused'
            new_state = :resume
            virsh_command = "resume #{domain_name}"
          elsif state == 'suspended'
            new_state = :restore
            virsh_command = "restore #{domain[:saved_state_file]}"
          end
        when :save
          return libvirt_state unless state == 'on'
          # If there is no place to create a state file, pause the VM in memory
          if domain[:saved_state_file].nil?
            new_state = :suspend
            virsh_command = "suspend #{domain_name}"
          else
            new_state = :save
            virsh_command = "save #{uuid} #{domain[:saved_state_file]}"
          end
        when :suspend
          return libvirt_state unless state == 'on'
        when :destroy, :shutdown
          return libvirt_state unless state == 'on'
        end

        my_logger("Requesting state change from [#{libvirt_state}] to [#{new_state}] for VM:[#{domain_name}] with uuid:[#{uuid}]")
        result = run_virsh_command(virsh_command, shell)
        my_logger("State change message: [#{result}]")

        # We need to poll the system to watch for the VM state change
        current_state = libvirt_state
        st = Time.now
        loop do
          libvirt_state = run_virsh_command("domstate #{uuid}", shell)
          my_logger("Current libvirt state: [#{libvirt_state}]")
          break if (libvirt_state != current_state) || ((Time.now-st) > state_wait)
          sleep(1)
        end

        # Saved state file cleanup
        if libvirt_state == "running"
          unless domain.nil? || domain[:saved_state_exists]==false
             run_command("rm -f #{domain[:saved_state_file]}", shell)
          end
        elsif libvirt_state == "shut off" && new_state == :save
          libvirt_state = "suspended"
        end
      end

      return libvirt_state
    end

    def run_virsh_command(cmd, shell)
      run_command("virsh -c #{@protocol}:///system #{cmd}", shell)
    end

    # Run the command through the ssh command shell or on the local system
    def run_command(cmd, shell=nil)
      if shell
        shell[0].shell_exec(cmd, shell[1]).chomp.strip
      else
        MiqUtil.runcmd(cmd)
      end
    end

    def file_exist?(file_name, shell=nil)
      if shell
        begin
          shell[0].shell_exec("ls -l #{file_name}", shell[1])
          true
        rescue
          false
        end
      else
        File.exist?(file_name)
      end
    end

    def my_logger(msg, level=:info, err=nil)
        obj, method = STDERR, :puts
        obj, method = $log, level if $log
        obj.send(method, msg)
        obj.send(method, err.backtrace.join("\n")) unless err.nil?
    end

    def load_ssh_shell
      if @user.blank?
        yield(nil)
      else
        t0 = Time.now
        my_logger("Initiating SSH connection to [#{@server}] for [#{@user}]")
        MiqSshUtil.shell_with_su(@server, @user, @pwd, nil, nil, :remember_host=>true) do |*shell|
          my_logger("SSH connection established to [#{@server}] in [#{Time.now-t0}] seconds")
          yield(shell)
        end
      end
    end

    def MonitorEmsEvents(ost)
      require 'EventingOps'
      EmsEventMonitorOps.doEvents(ost, self.class)
      # Does not return
    end

  end
end # MiqLibvirt
