module MiqLinux
  class Utils
    def self.parse_ls_l_fulltime(lines)
      ret = []
      return ret if lines.nil? || lines.empty?

      lines.each do |line|
        line = line.chomp
        parts = line.split(' ')
        next unless parts.length >= 9

        perms, ftype = permissions_to_octal(parts[0])

        ret << {
          :ftype       => ftype,
          :permissions => perms,
          :hard_links  => perms[1],
          :owner       => parts[2],
          :group       => parts[3],
          :size        => parts[4],
          :mtime       => Time.parse(parts[5..7].join(' ')).utc,
          :name        => parts[8..-1].join(' '),
        }
      end

      ret
    end

    def self.permissions_to_octal(perms)
      if perms.length == 9
        ftype = nil
      elsif perms.length == 10
        ftype = perms[0, 1]
        perms = perms[1..-1]
      elsif perms.length == 11
        # TODO: when se-linux is present, the format is like this '-rw-rw-r--.', . means an SELinux ACL. (+ means a
        # general ACL.). I need to figure out where to store this fact, ignoring it for now
        ftype = perms[0, 1]
        perms = perms[1..-2]
      else
        raise "Invalid perms length"
      end

      unless ftype.nil?
        ftype = case ftype
                when 'd' then 'dir'
                when 'l' then 'link'
                else          'file'
                end
      end

      octal = [0, 0, 0, 0]
      perms.split(//).each_with_index do |c, i|
        # puts [c, i, i % 3, 2 - (i % 3), 2 ** (2 - (i % 3)), i / 3, 2 - (i / 3), 2 ** (2 - (i / 3))].inspect
        octal[i / 3 + 1] += 2**(2 - (i % 3)) unless %w(- S T).include?(c)
        # puts octal.inspect
        octal[0] += 2**(2 - (i / 3)) if %w(s t S T).include?(c)
        # puts octal.inspect
      end
      octal = octal.join

      return octal, ftype
    end

    def self.octal_to_permissions(octal, ftype = nil)
      perms = ""

      unless ftype.nil?
        ftype = ftype[0, 1]
        ftype = '-' if ftype == 'f'
        perms << ftype
      end

      octal = octal.to_i(8) if octal.kind_of?(String)

      perms << (octal & 00400 != 0 ? 'r' : '-')
      perms << (octal & 00200 != 0 ? 'w' : '-')
      perms << (octal & 04000 != 0 ? (octal & 00100 != 0 ? 's' : 'S') : octal & 00100 != 0 ? 'x' : '-')
      perms << (octal & 00040 != 0 ? 'r' : '-')
      perms << (octal & 00020 != 0 ? 'w' : '-')
      perms << (octal & 02000 != 0 ? (octal & 00010 != 0 ? 's' : 'S') : octal & 00010 != 0 ? 'x' : '-')
      perms << (octal & 00004 != 0 ? 'r' : '-')
      perms << (octal & 00002 != 0 ? 'w' : '-')
      perms << (octal & 01000 != 0 ? (octal & 00001 != 0 ? 't' : 'T') : octal & 00001 != 0 ? 'x' : '-')

      perms
    end

    def self.parse_chkconfig_list(lines)
      ret = []
      return ret if lines.nil? || lines.empty?

      lines.each_line do |line|
        line = line.chomp
        parts = line.split(' ')
        next unless parts.length >= 8

        enable_level = []
        disable_level = []

        parts[1..-1].each do |part|
          level, state = part.split(':')
          case state
          when 'on'  then enable_level << level
          when 'off' then disable_level << level
          end
        end

        nh = {:name => parts[0]}
        nh[:enable_run_level]  = enable_level.empty? ? nil : enable_level.sort
        nh[:disable_run_level] = disable_level.empty? ? nil : disable_level.sort

        ret << nh
      end

      ret
    end

    def self.parse_systemctl_list(lines)
      return [] if lines.nil? || lines.empty?

      lines.each_line.map do |line|
        line = line.chomp
        parts = line.split(' ')
        next if (/^.*?\.service$/ =~ parts[0]).nil?

        name, = parts[0].split('.')

        # TODO(lsmola) investigate adding systemd targets, which are used instead of runlevels. Drawback, it's not
        # returned by any command, so we would have to parse the dir structure of /etc/systemd/system/
        # There is already MiqLinux::Systemd.new(@systemFs) called from class MIQExtract, we should leverage that
        {:name              => name,
         :systemd_load      => parts[1],
         :systemd_active    => parts[2],
         :systemd_sub       => parts[3],
         :typename          => 'linux_systemd',
         :description       => parts[4..-1].join(" "),
         :enable_run_level  => nil,
         :disable_run_level => nil,
         :running           => parts[3] == 'running'}
      end.compact
    end

    def self.collect_interface(interfaces, interface)
      mac_addr = interface[:mac_address]
      return if mac_addr.blank?

      existing_interface = interfaces[mac_addr]
      if existing_interface.blank?
        interfaces[mac_addr] = interface
      else
        interface[:name] += "," + existing_interface[:name]
        existing_interface.merge!(interface)
      end
    end

    def self.parse_network_interface_list(lines)
      return [] if lines.blank?

      interfaces = {}
      interface = {}
      lines.each_line do |line|
        if /^\d+\:\s([\w-]+)\:.*?mtu\s(\d+).*?$/ =~ line
          collect_interface(interfaces, interface) unless interface.blank?
          interface = {:name => $1}
        elsif /^.*?link.*?((\w\w\:)+\w\w).*?$/ =~ line
          interface[:mac_address] = $1
        elsif /^.*?inet\s((\d+\.)+\d+).*?$/ =~ line
          interface[:fixed_ip] = $1
        elsif /^.*?inet6\s((\w*\:+)+\w+).*?$/ =~ line
          interface[:fixed_ipv6] = $1
        end
      end
      collect_interface(interfaces, interface)

      interfaces.values
    end

    def self.parse_openstack_status(lines)
      lines.to_s.split("\n")
        .slice_before do |line|
        # get section for each OpenStack service
        line.start_with?('== ') && line.end_with?(' ==')
      end.map do |section|
        {
          # OpenStack service section name
          'name'     => section.first.delete('=').strip,
          # get array of services
          'services' => section[1..-1].map do |service_line|
            # split service line by :, ( and ) and strip white space from results
            service_line.split(/[:\(\)]/).map(&:strip)
          end.map do |service|
            {
              'name'    => service.first,
              'active'  => service[1] == 'active',
              'enabled' => !(service[2] =~ /disabled/)
            }
          end
        }
      end.reject do |service|
        # we omit Keystone users section
        service['name'] == 'Keystone users'
      end
    end
  end
end
