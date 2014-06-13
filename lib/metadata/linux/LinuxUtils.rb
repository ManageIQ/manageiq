module MiqLinux
  class Utils
    def self.parse_ls_l_fulltime(lines)
      ret = []
      return ret if lines.nil? || lines.empty?

      lines.each do |line|
        line = line.chomp
        parts = line.split(' ')
        next unless parts.length >= 9

        perms, ftype = self.permissions_to_octal(parts[0])

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

      return ret
    end

    def self.permissions_to_octal(perms)
      if perms.length == 10
        ftype = perms[0, 1]
        perms = perms[1..-1]
      elsif perms.length == 9
        ftype = nil
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
        #puts [c, i, i % 3, 2 - (i % 3), 2 ** (2 - (i % 3)), i / 3, 2 - (i / 3), 2 ** (2 - (i / 3))].inspect
        octal[i / 3 + 1] += 2 ** (2 - (i % 3)) unless %w{- S T}.include?(c)
        #puts octal.inspect
        octal[0] += 2 ** (2 - (i / 3)) if %w{s t S T}.include?(c)
        #puts octal.inspect
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
      perms << (octal & 04000 != 0 ? (octal & 00100 != 0 ? 's' : 'S' ) : octal & 00100 != 0 ? 'x' : '-')
      perms << (octal & 00040 != 0 ? 'r' : '-')
      perms << (octal & 00020 != 0 ? 'w' : '-')
      perms << (octal & 02000 != 0 ? (octal & 00010 != 0 ? 's' : 'S' ) : octal & 00010 != 0 ? 'x' : '-')
      perms << (octal & 00004 != 0 ? 'r' : '-')
      perms << (octal & 00002 != 0 ? 'w' : '-')
      perms << (octal & 01000 != 0 ? (octal & 00001 != 0 ? 't' : 'T' ) : octal & 00001 != 0 ? 'x' : '-')

      return perms
    end

    def self.parse_chkconfig_list(lines)
      ret = []
      return ret if lines.nil? || lines.empty?

      lines.each do |line|
        line = line.chomp
        parts = line.split(' ')
        next unless parts.length >= 8

        enable_level = []
        disable_level = []

        parts[1..-1].each do |part|
          level, state = part.split(':')
          case state
          when 'on'  then enable_level  << level
          when 'off' then disable_level << level
          end
        end

        nh = {:name => parts[0]}
        nh[:enable_run_level]  = enable_level.empty?  ? nil : enable_level.sort
        nh[:disable_run_level] = disable_level.empty? ? nil : disable_level.sort

        ret << nh
      end

      return ret
    end
  end
end
