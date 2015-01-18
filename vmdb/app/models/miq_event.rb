require 'miq-xml'

class MiqEvent < ActiveRecord::Base
  default_scope { where self.conditions_for_my_region_default_scope }

  include UuidMixin

  validates_presence_of     :name
  validates_uniqueness_of   :name
  validates_format_of       :name, :with => %r{\A[a-z0-9_\-]+\z}i,
    :allow_nil => true, :message => "must only contain alpha-numeric, underscore and hyphen characters without spaces"
  validates_presence_of     :description

  acts_as_miq_set_member
  include ReportableMixin
  acts_as_miq_taggable

  has_many :miq_policy_contents
  has_many :policy_events

  serialize :definition

  attr_accessor :reserved

  FIXTURE_DIR = File.join(Rails.root, "db/fixtures")

  CHILD_EVENTS = {
    :assigned_company_tag   => {
      :Host         => [:vms_and_templates],
      :EmsCluster   => [:all_vms_and_templates],
      :Storage      => [:vms_and_templates],
      :ResourcePool => [:vms_and_templates]
    },
    :unassigned_company_tag => {
      :Host         => [:vms_and_templates],
      :EmsCluster   => [:all_vms_and_templates],
      :Storage      => [:vms_and_templates],
      :ResourcePool => [:vms_and_templates]
    }
  }

  SUPPORTED_POLICY_AND_ALERT_CLASSES = [Host, VmOrTemplate, Storage, EmsCluster, ResourcePool, MiqServer]

  def self.raise_evm_event(target, raw_event, inputs={})
    # Target may have been deleted if it's a worker
    # Target, in that case will be the worker's server.
    # The generic raw_event remains, but client can pass the :type of the worker spawning the event:
    #  ex: MiqEvent.raise_evm_event(w.miq_server, "evm_worker_not_responding", :type => "MiqGenericWorker", :event_details => "MiqGenericWorker with pid 1234 killed due to not responding")
    # Policy, automate, and alerting could then consume this type field along with the details
    if target.kind_of?(Array)
      klass, id = target
      klass = Object.const_get(klass)
      target = klass.find_by_id(id)
      raise "Unable to find object with class: [#{klass}], Id: [#{id}]" unless target
    end

    inputs[:type] ||= target.class.name

    # TODO: Need to be able to pick an event without an expression in the UI
    event = normalize_event(raw_event.to_s)

    # Determine what actions to perform for this event
    actions = event_to_actions(target, raw_event, event)

    results = {}

    if actions[:enforce_policy]
      $log.info("MIQ(Event.raise_evm_event): Event Raised [#{event}]")
      results[:policy] = MiqPolicy.enforce_policy(target, event, inputs)
    end

    if actions[:raise_to_automate]
      $log.info("MIQ(Event.raise_evm_event): Event [#{raw_event}] raised to automation")
      results[:automate] = MiqAeEvent.raise_evm_event(raw_event, target, inputs)
    end

    if actions[:evaluate_alert]
      $log.info("MIQ(Event.raise_evm_event): Alert for Event [#{raw_event}]")
      results[:alert] = MiqAlert.evaluate_alerts(target, event, inputs)
    end

    if actions[:raise_children_events]
      results[:children_events] = raise_event_for_children(target, raw_event, inputs)
    end

    results
  end

  def self.event_to_actions(target, raw_event, event)
    # Old logic:
    #
    # For Host, VmOrTemplate, Storage, EmsCluster, ResourcePool targets:
    #   if it's a known event, we enforce policy and evaluate alerts
    #   if not known but alertable???, we only evaluate alerts
    #   For any of these targets, we then raise an event for the children of the target
    # For any other targets, we raise an raise an event to automate

    # New logic:
    #   Known events:
    #     send to policy (policy can then raise to automate)
    #     evaluate alerts
    #     raise for children
    #   Unknown events:
    #     Alert for ones we care about
    #     raise for children
    #   Not Host, VmOrTemplate, Storage, EmsCluster, ResourcePool events:
    #     Alert if event is alertable
    #     raise to automate (since policy doesn't support these types)

    # TODO: Need to add to automate_expressions in MiqAlert line 345 for alertable events
    actions = Hash.new(false)
    if target.class.base_class.in?(SUPPORTED_POLICY_AND_ALERT_CLASSES)
      actions[:raise_children_events] = true
      if event != "unknown"
        actions[:enforce_policy] = true
        actions[:evaluate_alert] = true
      elsif MiqAlert.event_alertable?(raw_event)
        actions[:evaluate_alert] = true
      else
        $log.debug("MIQ(Event.raise_evm_event): Event [#{raw_event}] does not participate in policy enforcement")
      end
    else
      actions[:raise_to_automate] = true
      actions[:evaluate_alert] = true if MiqAlert.event_alertable?(raw_event)
    end
    actions
  end

  def self.raise_evm_event_queue_in_region(target, raw_event, inputs={})
    MiqQueue.put(
      :zone        => nil,
      :class_name  => self.name,
      :method_name => 'raise_evm_event',
      :args        => [[target.class.name, target.id], raw_event, inputs]
    )
  end

  def self.raise_evm_event_queue(target, raw_event, inputs={})
    MiqQueue.put(
      :class_name  => self.name,
      :method_name => 'raise_evm_event',
      :args        => [[target.class.name, target.id], raw_event, inputs]
    )
  end

  def self.raise_evm_alert_event_queue(target, raw_event, inputs={})
    MiqQueue.put_unless_exists(
      :class_name  => "MiqAlert",
      :method_name => 'evaluate_alerts',
      :args        => [[target.class.name, target.id], raw_event, inputs]
    ) if MiqAlert.alarm_has_alerts?(raw_event)
  end

  def self.raise_evm_job_event(target, options = {}, inputs={})
    # Eg. options = {:type => "scan", ":prefix => "request, :suffix => "abort"}
    options.reverse_merge!(
      :type   => "scan",
      :prefix => nil,
      :suffix => nil
    )
    base_event = [target.class.base_model.name.downcase, options[:type]].join("_")
    evm_event  = [options[:prefix], base_event, options[:suffix]].compact.join("_")
    self.raise_evm_event(target, evm_event, inputs)
  end

  def self.raise_event_for_children(target, raw_event, inputs={})
    child_assocs = CHILD_EVENTS.fetch_path(raw_event.to_sym, target.class.base_class.name.to_sym)
    return if child_assocs.blank?

    child_event = "#{raw_event}_parent_#{target.class.base_model.name.underscore}"
    child_assocs.each do |assoc|
      next unless target.respond_to?(assoc)
      children = target.send(assoc)
      children.each do |child|
        $log.info("MIQ(Event.raise_event_for_children): Raising Event [#{child_event}] for Child [(#{child.class}) #{child.name}] of Parent [(#{target.class}) #{target.name}]")
        self.raise_evm_event_queue(child, child_event, inputs)
      end
    end
  end

  def self.normalize_event(event)
    return event if self.find_by_name(event)
    return "unknown"
  end

  def self.all_events
    self.find_all_by_event_type("Default")
  end

  def self.event_name_for_target(target, event_suffix)
    "#{target.class.base_model.name.underscore}_#{event_suffix}"
  end

  def miq_policies
    p_ids = MiqPolicyContent.where(:miq_event_id => self.id).uniq.pluck(:miq_policy_id)
    MiqPolicy.where(:id => p_ids).to_a
  end

  def export_to_array
    h = self.attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    return [ self.class.to_s => h ]
  end

  def self.import_from_hash(event, options={})
    status = {:class => self.name, :description => event["description"]}
    e = MiqEvent.find_by_name(event["name"])
    msg_pfx = "Importing Event: name=[#{event["name"]}]"

    if e.nil?
      e = MiqEvent.new(event)
      status[:status] = :add
    else
      e.attributes = event
      status[:status] = :update
    end

    unless e.valid?
      status[:status]   = :conflict
      status[:messages] = e.errors.full_messages
    end

    msg = "#{msg_pfx}, Status: #{status[:status]}"
    msg += ", Messages: #{status[:messages].join(",")}" if status[:messages]
    unless options[:preview] == true
      MiqPolicy.logger.info(msg)
      e.save!
    else
      MiqPolicy.logger.info("[PREVIEW] #{msg}")
    end

    return e, status
  end

  def etype
    set = self.memberof.first
    raise "unexpected error, no type found for event #{self.name}" if set.nil?
    set
  end

  def self.etypes
    MiqEvent.sets
  end

  def self.add_elements(vm, xmlNode)
    begin
      # Record vm operational and configuration events
      if xmlNode.root.name == "vmevents"
        xmlNode.find_each("//vmevents/view/rows/row") do |row|
          # Get the record's parts
          eventType = row.attributes["event_type"]
          timestamp = Time.at(row.attributes["timestamp"].to_i)
          eventData = YAML.load(row.attributes["event_data"])
          eventData.delete("id")

          # Remove elements that do not belong in the event table
          %w{ src_vm_guid dest_vm_guid vm_guid }.each do |field|
            eventData.delete(field)
          end

          # Write the data to the table
          unless EmsEvent.exists?(:event_type => eventType,
            :timestamp => timestamp,
            :ems_id => eventData['ems_id'],
            :chain_id => eventData['chain_id'])

            EmsEvent.create(eventData)
          end
        end
      end

      #$log.warn "GMM Events.add_elements [#{xmlNode}]"
      #add_missing_elements(vm, xmlNode, "Applications/Products/Products", "win32_product", WIN32_APPLICATION_MAPPING)
      File.open("./xfer_#{xmlNode.root.name}.xml", "w") {|f| xmlNode.write(f,0)}
    rescue
    end
  end

  def self.seed
    MiqEventSet.seed
    MiqRegion.my_region.lock do
      self.seed_default_events
      self.seed_default_definitions
    end
  end

  def self.seed_default_events
    fname = File.join(FIXTURE_DIR, "#{self.to_s.pluralize.underscore}.csv")
    data  = File.read(fname).split("\n")
    cols  = data.shift.split(",")

    data.each do |e|
      next if e =~ /^#.*$/ # skip commented lines

      arr = e.split(",")

      event = {}
      cols.each_index {|i| event[cols[i].to_sym] = arr[i]}
      set_type = event.delete(:set_type)

      next if event[:name].blank?

      rec = self.find_by_name(event[:name])
      if rec.nil?
        $log.info("MIQ(MiqEvent.seed_default_events) Creating [#{event[:name]}]")
        rec = self.create(event)
      else
        rec.attributes = event
        if rec.changed?
          $log.info("MIQ(MiqEvent.seed_default_events) Updating [#{event[:name]}]")
          rec.save
        end
      end

      es = MiqEventSet.find_by_name(set_type)
      rec.memberof.each {|old_set| rec.make_not_memberof(old_set) unless old_set == es} # handle changes in set membership
      es.add_member(rec) if es && !es.members.include?(rec)
    end
  end

  def self.seed_default_definitions
    stats = {:a => 0, :u => 0}

    fname = File.join(FIXTURE_DIR, "miq_event_definitions.yml")
    defns = YAML.load_file(fname)
    defns.each do |event_type, events|
      events[:events].each do |e|
        event = self.find_by_name_and_event_type(e[:name], event_type.to_s)
        if event.nil?
          $log.info("MIQ(MiqEvent.seed_default_definitions) Creating [#{e[:name]}]")
          event = self.create(e.merge(:event_type => event_type.to_s, :default => true, :enabled => true))
          stats[:a] += 1
        else
          event.attributes = e
          if event.changed?
            $log.info("MIQ(MiqEvent.seed_default_definitions) Updating [#{e[:name]}]")
            event.save
            stats[:u] += 1
          end
        end
      end
    end
  end
end # class MiqEvent
