module EmsRefresh::Parsers
  class Cloud
    private

    def parse_key_pair(kp)
      name = uid = kp.name

      new_result = {
        :type        => self.class.key_pair_type,
        :name        => name,
        :fingerprint => kp.fingerprint
      }

      return uid, new_result
    end

    def parse_security_group(sg)
      uid = sg.id

      new_result = {
        :type        => self.class.security_group_type,
        :ems_ref     => uid,
        :name        => sg.name,
        :description => sg.description.truncate(255)
      }

      return uid, new_result
    end

    #
    # Helper methods
    #

    def filter_unused_disabled_flavors
      to_delete = @data[:flavors].reject { |f| f[:enabled] || @known_flavors.include?(f[:ems_ref]) }
      to_delete.each do |f|
        @data_index[:flavors].delete(f[:ems_ref])
        @data[:flavors].delete(f)
      end
    end

    def add_instance_disk(disks, size, location, name, controller_type)
      if size > 0
        disk = {
          :device_name     => name,
          :device_type     => "disk",
          :controller_type => controller_type,
          :location        => location,
          :size            => size
        }
        disks << disk
        return disk
      end
      nil
    end
  end
end
