$LOAD_PATH.push("#{File.dirname(__FILE__)}/../../util")
require 'miq-xml'

# iniparse needed to handle duplicate options (inifile will overwrite)
require 'iniparse'

module MiqLinux
  class Systemd
    SYSTEM_DIRS = ['/etc/systemd/system', '/usr/lib/systemd/system']
    USER_DIRS   = ['/etc/systemd/user',   '/usr/lib/systemd/user']

    def self.detected?(fs)
      (SYSTEM_DIRS + USER_DIRS).any? { |dir| fs.fileExists?(dir) }
    end

    def initialize(fs)
      @fs = fs
      parse_systemd
    end

    def toXml(doc)
      @services.each do |service|
        doc.add_element("service", service_xml(service))
        # service_targets_xml(service).each { |tx| node.add_element("target", tx) }
      end
    end

    private

    def parse_systemd
      @services = files('.service').collect { |sf| parse_service(sf) }.compact
      @targets  = files('.target').collect  { |tf| parse_target(tf)  }.compact
    end

    def files(unit_extension)
      (SYSTEM_DIRS + USER_DIRS).flat_map do |dir|
        dir_files = []
        @fs.dirForeach(dir) do |unit|
          dir_files << File.join(dir, unit) if @fs.fileExtname(unit) == unit_extension
        end
        dir_files
      end
    end

    def ini(file)
      fdata = nil
      @fs.fileOpen(file) { |fo| fdata = fo.read }
      IniParse.parse(fdata)
    end

    def parse_service(file)
      return if @fs.fileSymLink?(file)
      debug "Parsing service unit: #{file}"

      unit        = @fs.fileBasename(file)
      name        = unit.gsub(".service", "")
      inif        = ini(file)
      desc        = parse_description(inif)
      wanted_by   = parse_wanted(inif)
      required_by = parse_required(inif)

      {:unit        => unit,
       :name        => name,
       :path        => file,
       :description => desc,
       :wanted_by   => wanted_by,
       :required_by => required_by}

      rescue
        warn "Error parsing: #{file}"
    end

    def parse_description(inif)
      return nil unless inif.has_section?('Unit') && inif['Unit'].has_option?('Description')
      inif['Unit']['Description']
    end

    def parse_wanted(inif)
      return [] unless inif.has_section?('Install') && inif['Install'].has_option?('WantedBy')
      [inif['Install']['WantedBy']].flatten.collect(&:split).flatten
    end

    def parse_required(inif)
      return [] unless inif.has_section?('Install') && inif['Install'].has_option?('RequiredBy')
      [inif['Install']['RequiredBy']].flatten.collect(&:split).flatten
    end

    def parse_target(file)
      return if @fs.fileSymLink?(file)
      debug "Parsing target unit: #{file}"

      unit = @fs.fileBasename(file)
      name = unit.gsub(".target", "")
      inif = ini(file)
      desc = parse_description(inif)

      {:unit        => unit,
       :name        => name,
       :path        => file,
       :description => desc}
      rescue
        warn "Error parsing: #{file}"
    end

    def service_xml(service)
      {"name"        => service[:name],
       "image_path"  => service[:path],
       "description" => service[:description],
       "typename"    => "linux_systemd"}
    end

    def service_targets_xml(service)
      (service[:required_by] + service[:wanted_by]).collect do |tgt|
        {"value" => tgt.gsub(".target", "")}
      end
    end

    def debug(msg)
      $log.debug msg if $log
    end

    def warn(msg)
      $log.warn msg if $log
    end
  end # class Systemd
end # module MiqLinux
