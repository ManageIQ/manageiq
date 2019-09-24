module VMDB
  module Util
    def self.http_proxy_uri(proxy_config = :default)
      proxy = ::Settings.http_proxy[proxy_config].to_hash
      proxy = ::Settings.http_proxy.to_hash unless proxy[:host]
      return nil if proxy[:host].blank?

      user     = proxy.delete(:user)
      user &&= CGI.escape(user)
      password = proxy.delete(:password)
      password &&= CGI.escape(password)
      userinfo = "#{user}:#{password}".chomp(":") unless user.blank?

      proxy[:userinfo]   = userinfo
      proxy[:scheme] ||= "http"
      proxy[:port] &&= proxy[:port].to_i

      URI::Generic.build(proxy)
    end

    def self.compressed_log_patterns
      # From a log file create an array of strings containing the date patterns
      log_dir = File.join(Rails.root, "log")
      gz_pattern = File.join(log_dir, "*[0-9][0-9].gz")
      Dir.glob(gz_pattern).inject([]) do |arr, f|
        f.match(/.+-(\d+\.gz)/)
        name = File.join(log_dir, "*#{$1}")
        arr << name unless $1.nil? || arr.include?(name)
        arr
      end
    end

    # TODO: Move these methods to lib in case they can be used elsewhere
    def self.get_evm_log_for_date(pattern)
      files = Dir.glob(pattern)
      files.find { |f| f.match(/\/evm\.log/) }
    end

    LOG_TIMESTAMP_REGEX = /\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6})\s#/.freeze

    def self.log_timestamp(str)
      return nil unless str
      t  = Time.parse(str)
      Time.utc(t.year, t.month, t.day, t.hour, t.min, t.sec, 0)
    end

    def self.log_duration(filename)
      require 'elif'

      first = File.open(filename, 'r') { |f| find_timestamp(f) }
      last  = Elif.open(filename, 'r') { |f| find_timestamp(f) }

      return first, last
    end

    def self.get_log_start_end_times(filename)
      if filename.nil? || !File.exist?(filename)
        return nil, nil
      elsif filename.ends_with?('.gz')
        log_duration_gz(filename)
      else
        log_duration(filename)
      end
    end

    def self.log_duration_gz(filename)
      require 'zlib'

      begin
        _log.info("Opening filename: [#{filename}], size: [#{File.size(filename)}]")
        Zlib::GzipReader.open(filename) do |gz|
          line_count = 0
          start_time_str = nil
          end_time_str   = nil

          gz.each_line do |line|
            line_count += 1
            next unless line =~ LOG_TIMESTAMP_REGEX
            start_time_str ||= $1
            end_time_str     = $1
          end

          start_time = log_timestamp(start_time_str)
          end_time   = log_timestamp(end_time_str)

          _log.info("Lines in file: [#{line_count}]")
          _log.info("Start Time: [#{start_time.inspect}]")
          _log.info("End   Time: [#{end_time.inspect}]")

          return start_time, end_time
        end
      rescue Exception => e
        _log.error(e.to_s)
        return []
      end
    end

    def self.zip_logs(zip_filename, dirs, userid = "system")
      require 'zip/filesystem'

      zip_dir = Rails.root.join("data", "user", userid)
      FileUtils.mkdir_p(zip_dir) unless File.exist?(zip_dir)

      zfile = zip_dir.join(zip_filename)
      File.delete(zfile) if File.exist?(zfile)
      zfile_display = zfile.relative_path_from(Rails.root)

      zfile = zfile.to_s

      _log.info("Creating: [#{zfile_display}]")
      Zip::File.open(zfile, Zip::File::CREATE) do |zip|
        dirs.each do |dir|
          dir = Rails.root.join(dir) unless Pathname.new(dir).absolute?
          Dir.glob(dir).each do |file|
            begin
              entry, _mtime = add_zip_entry(zip, file, zfile)
            rescue => e
              _log.error("Failed to add file: [#{entry}]. Error information: #{e.message}")
            end
          end
        end
        zip.close
      end
      _log.info("Created: [#{zfile_display}], Size: [#{File.size(zfile)}]")

      zfile
    end

    # TODO: Make a class out of this so we don't have to pass around the zip.
    def self.add_zip_entry(zip, file_path, zfile)
      entry = zip_entry_from_path(file_path)
      mtime = File.mtime(file_path)
      ztime = Zip::DOSTime.at(mtime.to_i)
      if File.directory?(file_path)
        zip.mkdir(entry)
      elsif File.symlink?(file_path)
        zip_entry = Zip::Entry.new(zfile, entry, nil, nil, nil, nil, nil, nil, ztime)
        zip.add(zip_entry, File.realpath(file_path))
      else
        zip_entry = Zip::Entry.new(zfile, entry, nil, nil, nil, nil, nil, nil, ztime)
        zip.add(zip_entry, file_path)
        _log.info("Adding file: [#{entry}], size: [#{File.size(file_path)}], mtime: [#{mtime}]")
      end
      return entry, mtime
    end
    private_class_method :add_zip_entry

    def self.zip_entry_from_path(path)
      rails_root_directories = Rails.root.to_s.split("/")
      within_rails_root = path.split("/")[0, rails_root_directories.length] == rails_root_directories
      entry = within_rails_root ? Pathname.new(path).relative_path_from(Rails.root).to_s : "ROOT#{path}"
      entry
    end
    private_class_method :zip_entry_from_path

    def self.find_timestamp(handle)
      handle
        .lazy
        .take(250)
        .map { |line| log_timestamp($1) if line =~ LOG_TIMESTAMP_REGEX }
        .reject(&:nil?)
        .first
    end
    private_class_method :find_timestamp
  end
end
