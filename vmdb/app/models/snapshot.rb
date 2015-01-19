require 'time'

class Snapshot < ActiveRecord::Base
  acts_as_tree

  belongs_to :vm_or_template

  include ReportableMixin
  include SerializedEmsRefObjMixin

  serialize :disks, Array

  after_create  :after_create_callback

  def after_create_callback
    MiqEvent.raise_evm_event_queue(self.vm_or_template, "vm_snapshot_complete", self.attributes) unless self.is_a_type?(:system_snapshot) || self.not_recently_created?
  end

  def self.add_elements(parentObj, xmlNode)
    # Convert the xml snapshot info into the database table hash
    all_nh = xml_to_hashes(xmlNode, parentObj.id)
    return if all_nh.nil?

    unless parentObj.ems_id.nil?
      add_snapshot_size_for_ems(parentObj, all_nh)
    else
      EmsRefresh.save_snapshots_inventory(parentObj, all_nh)
    end
  end

  def current?
    return self.current == 1
  end

  def get_current_snapshot
    # Find the snapshot that is marked as current
    Snapshot.find_by_vm_or_template_id_and_current(self.vm_or_template_id, 1)
  end

  #
  # EVM Snapshots
  #

  def self.find_all_evm_snapshots(zone = nil)
    zone ||= MiqServer.my_server.zone
    require 'MiqVimVm'
    Snapshot.where(:vm_or_template_id => zone.vm_or_template_ids, :name => MiqVimVm::EVM_SNAPSHOT_NAME).includes(:vm_or_template).to_a
  end

  def is_a_type?(stype)
    require 'MiqVimVm'
    value = case stype.to_sym
    when :evm_snapshot        then MiqVimVm.const_get("EVM_SNAPSHOT_NAME")
    when :consolidate_helper  then MiqVimVm.const_get("CH_SNAPSHOT_NAME")
    when :vcb_snapshot        then MiqVimVm.const_get("VCB_SNAPSHOT_NAME")
    when :system_snapshot     then :system_snapshot
    else
      raise "Unknown snapshot type '#{stype}' for #{self.class.name}.is_a_type?"
    end

    if value == :system_snapshot
      return self.is_a_type?(:evm_snapshot) || self.is_a_type?(:consolidate_helper) || self.is_a_type?(:vcb_snapshot)
    elsif value.kind_of?(Regexp)
      return value =~ self.name ? true : false
    else
      return self.name == value
    end
  end

  def self.evm_snapshot_description(jobid, type)
    "Snapshot for scan job: #{jobid}, EVM Server build: #{Vmdb::Appliance.BUILD} #{type} Server Time: #{Time.now.utc.iso8601}"
  end

  def self.parse_evm_snapshot_description(description)
    return $1, $2 if description =~ /^Snapshot for scan job: ([^,]+), .+? Server Time: (.+)$/
  end

  def self.remove_unused_evm_snapshots(delay)
    self.find_all_evm_snapshots.each do |sn|
      job_guid, timestamp = self.parse_evm_snapshot_description(sn.description)
      unless Job.guid_active?(job_guid, timestamp, delay)
        $log.info "MIQ(Snapshot.remove_unused_evm_snapshots) Removing #{sn.description.inspect} under Vm [#{sn.vm_or_template.name}]"
        sn.vm_or_template.remove_snapshot_queue(sn.id)
      end
    end
  end

  def recently_created?
    @recent_threshold ||= (VMDB::Config.new("vmdb").config.fetch_path(:ems_refresh, :raise_vm_snapshot_complete_if_created_within) || 15.minutes)
    self.create_time >= @recent_threshold.seconds.ago.utc
  end

  def not_recently_created?
    !self.recently_created?
  end

  private

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

  def self.add_snapshot_size_for_ems(parentObj, hashes)
    ss_props = {}
    hashes.each {|h| ss_props[normalize_ss_uid(h[:uid])] = {:total_size => h[:total_size]}}
    parentObj.snapshots.each {|s| s.update_attributes(ss_props[normalize_ss_uid(s[:uid])]) unless ss_props[normalize_ss_uid(s[:uid])].nil?}
  end

  # If the snapshot uid looks like a iso8601 time (2009-09-25T20:11:14.299742Z) drop off the microseconds so
  # we don't skip linking up data because of a format change.  (IE 2009-09-25T20:11:14.000000Z to 2009-09-25T20:11:14.299742Z)
  def self.normalize_ss_uid(uid)
    return uid[0,20] if !uid.nil? && uid.length == 27 && uid[-1,1] == 'Z'
    return uid
  end
end
