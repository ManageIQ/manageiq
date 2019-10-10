module ScanItem::Seeding
  extend ActiveSupport::Concern

  SCAN_ITEMS_DIR = Rails.root.join("product", "scan_items")

  # Default ScanItemSets
  SAMPLE_VM_PROFILE    = {:name => "sample",       :description => "VM Sample",    :mode => 'Vm',   :read_only => true}.freeze
  SAMPLE_HOST_PROFILE  = {:name => "host sample",  :description => "Host Sample",  :mode => 'Host', :read_only => true}.freeze
  DEFAULT_HOST_PROFILE = {:name => "host default", :description => "Host Default", :mode => 'Host'}.freeze

  module ClassMethods
    def seed
      transaction do
        seed_all_scan_items
        seed_scan_item_sets
      end
    end

    # Used for seeding a specific scan_item for test purposes
    def seed_scan_item(name)
      path = seed_files.detect { |f| File.basename(f).include?(name) }
      raise "scan item #{name.inspect} not found" if path.nil?

      seed_record(path, ScanItem.find_by(:filename => seed_filename(path)))
    end

    private

    def seed_all_scan_items
      scan_items = where(:prod_default => 'Default').index_by do |f|
        seed_filename(f.filename)
      end
      seed_files.each do |f|
        seed_record(f, scan_items.delete(seed_filename(f)))
      end

      if scan_items.any?
        _log.info("Deleting the following ScanItems(s) as they no longer exist: #{scan_items.keys.sort.collect(&:inspect).join(", ")}")
        ScanItem.destroy(scan_items.values.map(&:id))
      end
    end

    def seed_scan_item_sets
      vm_profile = ScanItemSet.find_or_initialize_by(:name => SAMPLE_VM_PROFILE[:name])
      vm_profile.update!(SAMPLE_VM_PROFILE)

      # Create sample Host scan profiles
      host_profile = ScanItemSet.find_or_initialize_by(:name => SAMPLE_HOST_PROFILE[:name])
      host_profile.update!(SAMPLE_HOST_PROFILE)

      # Create default Host scan profiles
      host_default = ScanItemSet.find_or_initialize_by(:name => DEFAULT_HOST_PROFILE[:name])
      load_host_default = host_default.new_record?
      host_default.update!(DEFAULT_HOST_PROFILE)

      where(:prod_default => 'Default').each do |s|
        case s.mode
        when "Host"
          host_profile.add_member(s)
          host_default.add_member(s) if load_host_default
        when "Vm"
          vm_profile.add_member(s)
        end
      end
    end

    def seed_record(path, scan_item)
      scan_item ||= ScanItem.new

      # DB and filesystem have different precision so calling round is done in
      # order to eliminate the second fractions diff otherwise the comparison
      # of the file time and the scan_item time from db will always be different.
      mtime = File.mtime(path).utc.round
      scan_item.file_mtime = mtime

      if scan_item.new_record? || scan_item.changed?
        filename = seed_filename(path)

        _log.info("#{scan_item.new_record? ? "Creating" : "Updating"} ScanItem #{filename.inspect}")

        yml  = YAML.load_file(path).symbolize_keys
        name = yml[:name].strip

        attrs = yml.slice(*column_names_symbols)
        attrs.delete(:id)
        attrs[:filename]     = filename
        attrs[:file_mtime]   = mtime
        attrs[:prod_default] = "Default"
        attrs[:name]         = name

        begin
          scan_item.update!(attrs)
        rescue ActiveRecord::RecordInvalid
          duplicate = find_by(:name => name)
          if duplicate&.prod_default == "Custom"
            _log.warn("A custom scan_item already exists with the name #{duplicate.name.inspect}.  Skipping...")
          elsif duplicate
            _log.warn("A default scan_item named '#{duplicate.name.inspect}' loaded from '#{duplicate.filename}' already exists. Updating attributes of existing report...")
            duplicate.update!(attrs)
          else
            raise
          end
        end
      end
    end

    def seed_files
      Dir.glob(SCAN_ITEMS_DIR.join("*.{yml,yaml}")).sort + seed_plugin_files
    end

    def seed_plugin_files
      Vmdb::Plugins.flat_map do |plugin|
        Dir.glob(plugin.root.join("content/scan_items/*.{yml,yaml}")).sort
      end
    end

    def seed_filename(path)
      File.basename(path)
    end
  end
end
