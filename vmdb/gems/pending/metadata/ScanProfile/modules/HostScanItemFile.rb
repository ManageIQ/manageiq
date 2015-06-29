$:.push("#{File.dirname(__FILE__)}/../../linux")
require 'LinuxUtils'

module HostScanItemFile
  def parse_data(ssu, data, &blk)
    if data.nil?
      d = self.scan_definition

      st = Time.now
      $log.info "Scanning [Profile-Files] information."
      yield({:msg=>'Scanning Profile-File'}) if block_given?

      fs_files = d["stats"].collect { |s| s["target"] }.uniq

      $log.info "Retrieving file metadata for targets."
      files = ssu.shell_exec("ls -lLd --full-time #{fs_files.join(' ')} 2>/dev/null; true").split("\n")
      files = MiqLinux::Utils.parse_ls_l_fulltime(files)
      files.each do |f|
        f.delete(:hard_links)
        f[:rsc_type] = f.delete(:ftype)
        f[:contents] = nil
      end

      md5_files = files.collect { |f| f[:name] if f[:rsc_type] == 'file' }.compact
      $log.info "Retrieving md5 values for targets."
      md5_files = ssu.shell_exec("md5sum #{md5_files.join(' ')} 2>/dev/null; true").split("\n")
      md5_files.each do |line|
        parts = line.chomp.split(' ')
        md5, fname = parts[0], parts[1..-1].join(' ')
        file = files.find { |f| f[:name] == fname }
        file[:md5] = md5 unless file.nil?
      end

      cat_files = d["stats"].collect { |s| s["target"] if s["content"] }.compact.uniq
      unless cat_files.empty?
        $log.info "Retrieving content for specified targets."
        cat_files = ssu.shell_exec("ls -1d #{cat_files.join(' ')} 2>/dev/null; true").split("\n")
        cat_files.each do |fname|
          fname = fname.chomp
          next if fname.empty?
          file = files.find { |f| f[:name] == fname }
          $log.debug "Retrieving content for #{fname}."
          file[:contents] = ssu.shell_exec("cat #{fname} 2>/dev/null; true")
        end
      end

      d[:data] = files

      $log.info "Scanning [Profile-Files] information ran for [#{Time.now-st}] seconds."
    end
  end
end
