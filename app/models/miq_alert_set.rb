class MiqAlertSet < ActiveRecord::Base
  acts_as_miq_set

  default_scope { where self.conditions_for_my_region_default_scope }

  before_validation :default_name_to_guid, :on => :create

  include AssignmentMixin

  def self.assigned_to_target(target, options = {})
    self.get_assigned_for_target(target, options)
  end

  def notes
    return self.set_data.kind_of?(Hash) && self.set_data.has_key?(:notes) ? self.set_data[:notes] : nil
  end

  def notes=(data)
    return if data.nil?
    self.set_data ||= {}
    self.set_data[:notes] = data[0..511]
  end

  def active?
    !self.members.all? {|p| !p.active}
  end

  def export_to_array
    h = self.attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    h["MiqAlert"] = self.members.collect { |p| p.export_to_array.first["MiqAlert"] unless p.nil? }
    return [ self.class.to_s => h ]
  end

  def export_to_yaml
    a = export_to_array
    a.to_yaml
  end

  def self.import_from_hash(alert_profile, options={})
    status = {:class => self.name, :description => alert_profile["description"], :children => []}
    ap = alert_profile.delete("MiqAlert") { |k| raise "No Alerts for Alert Profile == #{alert_profile.inspect}" }

    alerts = []
    ap.each { |a|
      alert, s = MiqAlert.import_from_hash(a, options)
      status[:children].push(s)
      alerts.push(alert)
    }

    aset = MiqAlertSet.find_by_guid(alert_profile["guid"])
    msg_pfx = "Importing Alert Profile: guid=[#{alert_profile["guid"]}] description=[#{alert_profile["description"]}]"
    if aset.nil?
      aset = MiqAlertSet.new(alert_profile)
      status[:status] = :add
    else
      status[:old_description] = aset.description
      aset.attributes = alert_profile
      status[:status] = :update
    end

    unless aset.valid?
      status[:status]   = :conflict
      status[:messages] = aset.errors.full_messages
    end

    aset["mode"] ||= "control" # Default "mode" value to true to support older export decks that don't have a value set.

    msg = "#{msg_pfx}, Status: #{status[:status]}"
    msg += ", Messages: #{status[:messages].join(",")}" if status[:messages]
    unless options[:preview] == true
      MiqPolicy.logger.info(msg)
      aset.save!
      alerts.each { |a| aset.add_member(a) }
    else
      MiqPolicy.logger.info("[PREVIEW] #{msg}")
    end

    return aset, status
  end

  def self.import_from_yaml(fd)
    stats = []

    input = YAML.load(fd)

    input.each { |e|
      _a, stat = import_from_hash(e["MiqAlertSet"])
      stats.push(stat)
    }

    return stats
  end
end
