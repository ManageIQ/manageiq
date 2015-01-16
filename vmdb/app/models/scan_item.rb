class ScanItem < ActiveRecord::Base
  default_scope { where self.conditions_for_my_region_default_scope }

  serialize :definition
  acts_as_miq_set_member
  include UuidMixin

  YAML_DIR = File.expand_path(File.join(Rails.root, "product/scan_items"))
  Dir.mkdir YAML_DIR unless File.exist?(YAML_DIR)

  SAMPLE_VM_PROFILE    = {:name => "sample",       :description => "VM Sample",       :mode => 'Vm',   :read_only => true, }.freeze
  SAMPLE_HOST_PROFILE  = {:name => "host sample",  :description => "Host Sample",  :mode => 'Host', :read_only => true}.freeze
  DEFAULT_HOST_PROFILE = {:name => "host default", :description => "Host Default", :mode => 'Host'}.freeze

  def self.sync_from_dir
    self.find(:all, :conditions => "prod_default = 'Default'").each {|f|
      next unless f.filename
      unless File.exist?(File.join(YAML_DIR, f.filename))
        $log.info("Scan Item: file [#{f.filename}] has been deleted from disk, deleting from model")
        f.destroy
      end
    }

    Dir.glob(File.join(YAML_DIR, "*.yaml")).sort.each {|f|
      self.sync_from_file(f)
    }
  end

  def self.sync_from_file(filename)
    fd = File.open(filename)
    item = YAML.load(fd.read)
    fd.close

    item[:filename] = filename.sub(YAML_DIR + "/", "")
    item[:file_mtime] = File.mtime(filename).utc
    item[:prod_default] = "Default"

    rec = self.find_by_name_and_filename(item[:name], item[:filename])

    if rec
      if rec.filename && (rec.file_mtime.nil? || rec.file_mtime.utc < item[:file_mtime])
        $log.info("Scan Item: [#{rec.name}] file has been updated on disk, synchronizing with model")
        rec.update_attributes(item)
        rec.save
      end
    else
      $log.info("Scan Item: [#{item[:name]}] file has been added to disk, adding to model")
      self.create(item)
    end
  end

  def self.seed
    MiqRegion.my_region.lock do
      self.sync_from_dir
      self.preload_default_profile
    end
  end

  def self.preload_default_profile
    # Create sample VM scan profiles
    vm_profile = ScanItemSet.find_or_initialize_by_name(SAMPLE_VM_PROFILE)
    vm_profile.update_attributes(SAMPLE_VM_PROFILE)

    # Create sample Host scan profiles
    host_profile = ScanItemSet.find_or_initialize_by_name(SAMPLE_HOST_PROFILE)
    host_profile.update_attributes(SAMPLE_HOST_PROFILE)

    # Create default Host scan profiles
    host_default = ScanItemSet.find_or_initialize_by_name(DEFAULT_HOST_PROFILE)
    load_host_default = host_default.new_record?
    host_default.update_attributes(DEFAULT_HOST_PROFILE)

    self.find(:all, :conditions => {:prod_default => 'Default'}).each do |s|
      case s.mode
      when "Host"
        host_profile.add_member(s) unless host_profile.members.include?(s)
        host_default.add_member(s) if load_host_default && !host_default.members.include?(s)
      when "Vm"
        vm_profile.add_member(s) unless vm_profile.members.include?(s)
      end
    end
  end

  def self.get_default_profiles()
    self.get_profile('default')
  end

  def self.get_profile(set_name)
    profiles = []
    si = ScanItemSet.find_by_name(set_name)
    if si
      y = si.attributes
      y["definition"] = []
      si.members.each do |m|
        y["definition"] << m.attributes
      end
      profiles << y
    end
    return profiles
  end

  def self.add_elements(vm, xmlNode)
    el = xmlNode.root
    return nil unless MiqXml.isXmlElement?(el)
    return nil unless el.name == 'scan_profiles'

    el.each_element do |profile|
      guid = profile.attributes['guid']
      sis = ScanItemSet.find_by_guid(guid)
      if sis.nil?
        $log.warn "MIQ(scan_item-add_elements): Unable to find ScanItemSet [guid: #{guid}] in the database."
        next
      end

      profile.each_element do |e|
        item_type = e.attributes['item_type']
        guid = e.attributes['guid']

        si = ScanItem.find_by_guid(guid)
        if si.nil?
          $log.warn "MIQ(scan_item-add_elements): Unable to find ScanItem [guid: #{guid} type: #{item_type}] in the database."
          next
        end

        case item_type
        when 'file'
          Filesystem.add_elements(sis, si, vm, e)
        when 'registry'
          RegistryItem.add_elements(sis, si, vm, e)
        when 'category'
          $log.debug "MIQ(scan_item-add_elements): Skipping ScanItem [guid: #{guid} type: #{item_type}] as it is not expected in the data."
        when 'nteventlog'
          EventLog.add_elements(vm, e)
        else
          $log.debug "MIQ(scan_item-add_elements): Unknown ScanItem type [#{item_type}]"
        end
      end
    end
  end
end
