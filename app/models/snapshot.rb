require 'time'

class Snapshot < ApplicationRecord
  acts_as_tree :dependent => :nullify

  belongs_to :vm_or_template

  serialize :disks, Array

  after_create  :after_create_callback

  EVM_SNAPSHOT_NAME = "EvmSnapshot".freeze

  def after_create_callback
    MiqEvent.raise_evm_event_queue(vm_or_template, "vm_snapshot_complete", attributes) unless self.is_a_type?(:system_snapshot) || self.not_recently_created?
  end

  def self.add_elements(parentObj, xmlNode)
    # Convert the xml snapshot info into the database table hash
    all_nh = xml_to_hashes(xmlNode, parentObj.id)
    return if all_nh.nil?

    if parentObj.ems_id.nil?
      EmsRefresh.save_snapshots_inventory(parentObj, all_nh)
    else
      add_snapshot_size_for_ems(parentObj, all_nh)
    end
  end

  def current?
    current == 1
  end

  def get_current_snapshot
    # Find the snapshot that is marked as current
    Snapshot.find_by(:vm_or_template_id => vm_or_template_id, :current => 1)
  end

  #
  # EVM Snapshots
  #

  def self.find_all_evm_snapshots(zone = nil)
    zone ||= MiqServer.my_server.zone
    Snapshot.where(:vm_or_template_id => zone.vm_or_template_ids, :name => EVM_SNAPSHOT_NAME).includes(:vm_or_template).to_a
  end

  def is_a_type?(stype)
    value = case stype.to_sym
            when :evm_snapshot        then EVM_SNAPSHOT_NAME
            when :system_snapshot     then :system_snapshot
            else
              raise "Unknown snapshot type '#{stype}' for #{self.class.name}.is_a_type?"
            end

    if value == :system_snapshot
      return self.is_a_type?(:evm_snapshot)
    elsif value.kind_of?(Regexp)
      return !!(value =~ name)
    else
      return name == value
    end
  end

  def self.evm_snapshot_description(jobid, type)
    "Snapshot for scan job: #{jobid}, EVM Server build: #{Vmdb::Appliance.BUILD} #{type} Server Time: #{Time.now.utc.iso8601}"
  end

  def self.parse_evm_snapshot_description(description)
    return $1, $2 if description =~ /^Snapshot for scan job: ([^,]+), .+? Server Time: (.+)$/
  end

  def self.remove_unused_evm_snapshots(delay)
    _log.debug("Called")
    find_all_evm_snapshots.each do |sn|
      job_guid, timestamp = parse_evm_snapshot_description(sn.description)
      unless Job.guid_active?(job_guid, timestamp, delay)
        _log.info("Removing #{sn.description.inspect} under Vm [#{sn.vm_or_template.name}]")
        sn.vm_or_template.remove_evm_snapshot_queue(sn.id)
      end
    end
  end

  def recently_created?
    create_time >= ::Settings.ems_refresh.raise_vm_snapshot_complete_if_created_within.to_i_with_method
                   .seconds.ago.utc
  end

  def not_recently_created?
    !self.recently_created?
  end

  def self.xml_to_hashes(xmlNode, vm_or_template_id)
    return nil unless MiqXml.isXmlElement?(xmlNode)

    all_nh = []

    numsnapshots = xmlNode.attributes['numsnapshots'].to_i
    unless numsnapshots.zero?
      current = xmlNode.attributes['current']

      # Store the create times of each snapshot, so we can use that as the uid
      # to keep in sync with what is used during EMS inventory scan.
      uid_to_create_time = {}

      xmlNode.each_element do |e|
        # Extra check here to be sure we do not pull in too many elements from the xml if the xml is incorrect
        break if all_nh.length == numsnapshots

        nh = {}
        # Calculate the size taken up by this snapshot, including snapshot metadata file.
        total_size = e.attributes['size_on_disk'].to_i
        nh[:disks] = []
        e.each_recursive do |e1|
          total_size += e1.attributes['size_on_disk'].to_i
          if e1.name == "disk"
            nh[:disks] << e1.attributes.to_h

            # If we do not get a snapshot create time in the header use the file create time
            if e.attributes['create_time'].blank? && nh[:create_time].blank?
              nh[:create_time] = e1.attributes['cdate_on_disk'] unless e1.attributes['cdate_on_disk'].blank?
            end
          end
        end

        nh[:uid] = e.attributes['uid']
        nh[:parent_uid] = e.attributes['parent'] unless e.attributes['parent'].blank?
        nh[:name] = e.attributes['displayname']
        nh[:filename] = e.attributes['filename']
        nh[:description] = e.attributes['description']
        nh[:create_time] = e.attributes['create_time'] unless e.attributes['create_time'].blank?
        nh[:current] = current == e.attributes['uid'] ? 1 : 0
        nh[:total_size] = total_size
        # We are setting the vm_or_template_id relationship here because the tree relationship
        # will only set it for this first element in the chain.
        nh[:vm_or_template_id] = vm_or_template_id

        uid_to_create_time[nh[:uid]] = nh[:create_time]

        all_nh << nh
      end

      # Update all of the UIDs with their respective create_times
      all_nh.each do |nh|
        nh[:uid] = uid_to_create_time[nh[:uid]] unless nh[:uid].nil?
        nh[:parent_uid] = uid_to_create_time[nh[:parent_uid]] unless nh[:parent_uid].nil?
      end

      # Sort the snapshots so that we can properly build the parent-child relationship
      all_nh.sort! { |x, y| (x[:uid].nil? ? '' : x[:uid]) <=> (y[:uid].nil? ? '' : y[:uid]) }
    end

    all_nh
  end
  private_class_method :xml_to_hashes

  def self.add_snapshot_size_for_ems(parentObj, hashes)
    ss_props = {}
    hashes.each { |h| ss_props[normalize_ss_uid(h[:uid])] = {:total_size => h[:total_size]} }
    parentObj.snapshots.each { |s| s.update(ss_props[normalize_ss_uid(s[:uid])]) unless ss_props[normalize_ss_uid(s[:uid])].nil? }
  end
  private_class_method :add_snapshot_size_for_ems

  # If the snapshot uid looks like a iso8601 time (2009-09-25T20:11:14.299742Z) drop off the microseconds so
  # we don't skip linking up data because of a format change.  (IE 2009-09-25T20:11:14.000000Z to 2009-09-25T20:11:14.299742Z)
  def self.normalize_ss_uid(uid)
    return uid[0, 20] if !uid.nil? && uid.length == 27 && uid[-1, 1] == 'Z'
    uid
  end
  private_class_method :normalize_ss_uid
end
