class MiqPolicySet < ApplicationRecord
  acts_as_miq_set

  before_validation :default_name_to_guid, :on => :create
  before_destroy    :destroy_policy_tags

  attr_accessor :reserved

  def notes
    set_data.kind_of?(Hash) && set_data.key?(:notes) ? set_data[:notes] : nil
  end

  def notes=(data)
    return if data.nil?
    self.set_data ||= {}
    self.set_data[:notes] = data[0..511]
  end

  def active?
    !members.all? { |p| !p.active }
  end

  def destroy_policy_tags
    # handle policy assignment removal for deleted policy profile
    tag = "/miq_policy/assignment/#{self.class.to_s.underscore}/#{id}"
    Tag.remove(tag, :ns => "*")
  end

  def add_to(ids, db)
    model = db.respond_to?(:constantize) ? db.constantize : db
    ids.each do|id|
      rec = model.find_by_id(id)
      next unless rec

      rec.add_policy(self)
    end
  end

  def remove_from(ids, db)
    model = db.respond_to?(:constantize) ? db.constantize : db
    ids.each do|id|
      rec = model.find_by_id(id)
      next unless rec

      rec.remove_policy(self)
    end
  end

  def export_to_array
    h = attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    h["MiqPolicy"] = members.collect { |p| p.export_to_array.first["MiqPolicy"] unless p.nil? }
    [self.class.to_s => h]
  end

  def export_to_yaml
    a = export_to_array
    a.to_yaml
  end

  def self.import_from_hash(policy_profile, options = {})
    status = {:class => name, :description => policy_profile["description"], :children => []}
    pp = policy_profile.delete("MiqPolicy") { |_k| raise "No Policies for Policy Profile == #{policy_profile.inspect}" }

    policies = []
    pp.each do |p|
      policy, s = MiqPolicy.import_from_hash(p, options)
      status[:children].push(s)
      policies.push(policy)
    end

    pset = MiqPolicySet.find_by_guid(policy_profile["guid"])
    msg_pfx = "Importing Policy Profile: guid=[#{policy_profile["guid"]}] description=[#{policy_profile["description"]}]"
    if pset.nil?
      pset = MiqPolicySet.new(policy_profile)
      status[:status] = :add
    else
      status[:old_description] = pset.description
      pset.attributes = policy_profile
      status[:status] = :update
    end

    unless pset.valid?
      status[:status]   = :conflict
      status[:messages] = pset.errors.full_messages
    end

    pset["mode"] ||= "control" # Default "mode" value to true to support older export decks that don't have a value set.

    msg = "#{msg_pfx}, Status: #{status[:status]}"
    msg += ", Messages: #{status[:messages].join(",")}" if status[:messages]
    unless options[:preview] == true
      MiqPolicy.logger.info(msg)
      pset.save!
      policies.each { |p| pset.add_member(p) }
    else
      MiqPolicy.logger.info("[PREVIEW] #{msg}")
    end

    return pset, status
  end

  def self.import_from_yaml(fd)
    stats = []

    input = YAML.load(fd)

    input.each do |e|
      p, stat = import_from_hash(e["MiqPolicySet"])
      stats.push(stat)
    end

    stats
  end

  def self.seed
    all.each do |ps|
      if ps.mode.nil?
        _log.info("Updating [#{ps.name}]")
        ps.update_attribute(:mode, "control")
      end
    end
  end
end # class MiqPolicySet
