class MiqEventDefinition < ApplicationRecord
  include UuidMixin

  validates_presence_of     :name
  validates_uniqueness_of   :name
  validates_format_of       :name, :with => /\A[a-z0-9_\-]+\z/i,
    :allow_nil => true, :message => "must only contain alpha-numeric, underscore and hyphen characters without spaces"
  validates_presence_of     :description

  acts_as_miq_set_member
  include ReportableMixin
  acts_as_miq_taggable

  has_many :miq_policy_contents
  has_many :policy_events

  serialize :definition

  attr_accessor :reserved

  def self.all_events
    where(:event_type => "Default")
  end

  def self.all_control_events
    all_events.where.not("name like ?", "%compliance_check").select { |e| e.etype }
  end

  def miq_policies
    p_ids = MiqPolicyContent.where(:miq_event_definition_id => id).uniq.pluck(:miq_policy_id)
    MiqPolicy.where(:id => p_ids).to_a
  end

  def export_to_array
    h = attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    [self.class.to_s => h]
  end

  def self.import_from_hash(event, options = {})
    # The import is only intended to create non-projected event
    # definitions which have a `#definition` of `nil`. The
    # `#definition` attribute is only used for projected event
    # definitions which are not user-defined. The message within the
    # definition gets `eval`d, so it is critical that projected events
    # cannot be created on import. So here any definition attribute
    # keyed with either a string or symbol (AR accepts either) is
    # removed from the hash.
    event.except!("definition", :definition)

    status = {:class => name, :description => event["description"]}
    e = MiqEventDefinition.find_by_name(event["name"])
    msg_pfx = "Importing Event: name=[#{event["name"]}]"

    if e.nil?
      e = MiqEventDefinition.new(event)
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
    memberof.first.tap { |set| _log.error("No type found for event #{name}") if set.nil? }
  end

  def self.etypes
    MiqEventDefinition.sets
  end

  def self.add_elements(_vm, xmlNode)
    # Record vm operational and configuration events
    if xmlNode.root.name == "vmevents"
      xmlNode.find_each("//vmevents/view/rows/row") do |row|
        # Get the record's parts
        eventType = row.attributes["event_type"]
        timestamp = Time.at(row.attributes["timestamp"].to_i)
        eventData = YAML.load(row.attributes["event_data"])
        eventData.delete("id")

        # Remove elements that do not belong in the event table
        %w( src_vm_guid dest_vm_guid vm_guid ).each do |field|
          eventData.delete(field)
        end

        # Write the data to the table
        unless EmsEvent.exists?(:event_type => eventType,
                                :timestamp  => timestamp,
                                :ems_id     => eventData['ems_id'],
                                :chain_id   => eventData['chain_id'])

          EmsEvent.create(eventData)
        end
      end
    end

    # _log.warn "[#{xmlNode}]"
    # add_missing_elements(vm, xmlNode, "Applications/Products/Products", "win32_product", WIN32_APPLICATION_MAPPING)
    File.open("./xfer_#{xmlNode.root.name}.xml", "w") { |f| xmlNode.write(f, 0) }
  rescue
  end

  def self.seed
    MiqEventDefinitionSet.seed
    seed_default_events
    seed_default_definitions
  end

  def self.seed_default_events
    fname = File.join(FIXTURE_DIR, "#{to_s.pluralize.underscore}.csv")
    CSV.foreach(fname, :headers => true, :skip_lines => /^#/, :skip_blanks => true) do |csv_row|
      event = csv_row.to_hash
      set_type = event.delete('set_type')

      rec = find_by_name(event['name'])
      if rec.nil?
        _log.info("Creating [#{event['name']}]")
        rec = create(event)
      else
        rec.attributes = event
        if rec.changed?
          _log.info("Updating [#{event['name']}]")
          rec.save
        end
      end

      es = MiqEventDefinitionSet.find_by_name(set_type)
      rec.memberof.each { |old_set| rec.make_not_memberof(old_set) unless old_set == es } # handle changes in set membership
      es.add_member(rec) if es && !es.members.include?(rec)
    end
  end

  def self.seed_default_definitions
    stats = {:a => 0, :u => 0}

    fname = File.join(FIXTURE_DIR, "miq_event_definitions.yml")
    defns = YAML.load_file(fname)
    defns.each do |event_type, events|
      events[:events].each do |e|
        event = find_by(:name => e[:name], :event_type => event_type.to_s)
        if event.nil?
          _log.info("Creating [#{e[:name]}]")
          event = create(e.merge(:event_type => event_type.to_s, :default => true, :enabled => true))
          stats[:a] += 1
        else
          event.attributes = e
          if event.changed?
            _log.info("Updating [#{e[:name]}]")
            event.save
            stats[:u] += 1
          end
        end
      end
    end
  end
end # class MiqEventDefinition
