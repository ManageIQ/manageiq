module VMDB
  module MiqAppliance
    def self.status
      status = {}
      status["used_space_db"]  = 0
      status["free_space_db"]  = 0
      status["used_space_log"] = 0
      status["free_space_log"] = 0

      disk_info = `df -B 1`.split("\n")
      disk_info.each{|disk_entry|
        tmp = disk_entry.split(" ")
        if tmp[5] == "/var/lib/data"
          status["used_space_db"] = status["used_space_db"].to_i + tmp[2].to_i
          status["free_space_db"] = status["free_space_db"].to_i + tmp[3].to_i
        end
        if tmp[5] == "/var/www/miq/vmdb/log"
          status["used_space_log"] = status["used_space_log"].to_i + tmp[2].to_i
          status["free_space_log"] = status["free_space_log"].to_i + tmp[3].to_i
        end
      }
      return status
    end
  end
end
