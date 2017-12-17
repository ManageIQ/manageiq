module MiqPolicy::ImportExport
  extend ActiveSupport::Concern

  IMPORT_CLASS_NAMES = %w(MiqPolicy MiqPolicySet MiqAlert).freeze

  module ClassMethods
    def import_from_hash(policy, options = {})
      raise _("No Policy to Import") if policy.nil?
      pe = policy.delete("MiqPolicyContent") { |_k| raise "No contents for Policy == #{policy.inspect}" }
      pc = policy.delete("Condition") || []

      status = {:class => name, :description => policy["description"], :children => []}
      events = []

      actionsHash = {}
      eventsHash  = {}
      e2a         = {}

      pe.each do |e|
        opts = {}
        ["qualifier", "success_sequence", "failure_sequence", "success_synchronous", "failure_synchronous"].each do |k|
          v = e.delete(k)
          opts[k.to_sym] = v unless v.nil?
        end

        akey = nil
        if e["MiqAction"]
          akey = e["MiqAction"]["description"]
          actionsHash[akey] = MiqAction.import_from_hash(e["MiqAction"], options) unless actionsHash.key?(akey)
        end

        event = e["MiqEventDefinition"] || e["MiqEvent"]
        ekey = event["name"]
        eventsHash[ekey] = MiqEventDefinition.import_from_hash(event,  options) unless eventsHash.key?(ekey)

        e2a[ekey] = [] unless e2a.key?(ekey)
        e2a[ekey].push([akey, opts])
      end

      e2a.keys.each do |ekey|
        event, event_status = eventsHash[ekey]
        actions = []
        event_status[:children] ||= []
        e2a[ekey].each do |arr|
          akey, opts = arr
          unless akey.nil?
            action, s = actionsHash[akey]
            actions.push([action, opts])
            event_status[:children].push(s)
          end
        end

        events.push([event, actions])
        status[:children].push(event_status)
      end

      conditions = []
      pc.each do |c|
        c.delete("condition_id")
        condition, s = Condition.import_from_hash(c, options)
        status[:children].push(s)
        conditions.push(condition)
      end

      policy["towhat"] ||= "Vm"      # Default "towhat" value to "Vm" to support older export decks that don't have a value set.
      # Default "active" value to true to support older export decks that don't have a value set.
      policy["active"] = true if policy["active"].nil?
      policy["mode"] ||= "control" # Default "mode" value to true to support older export decks that don't have a value set.

      p = MiqPolicy.find_by(:guid => policy["guid"])
      msg_pfx = "Importing Policy: guid=[#{policy["guid"]}] description=[#{policy["description"]}]"
      if p.nil?
        p = MiqPolicy.new(policy)
        status[:status] = :add
      else
        status[:old_description] = p.description
        p.attributes = policy
        status[:status] = :update
      end

      unless p.valid?
        status[:status]   = :conflict
        status[:messages] = p.errors.full_messages
      end

      msg = "#{msg_pfx}, Status: #{status[:status]}"
      msg += ", Messages: #{status[:messages].join(",")}" if status[:messages]
      if options[:save]
        MiqPolicy.logger.info(msg)
        events.each do |event|
          e, a = event
          if a.empty?
            p.add_event(e) unless p.miq_event_definitions.include?(e)
          else
            p.replace_actions_for_event(e, a)
          end
        end
        p.conditions = conditions
        p.save!
      else
        MiqPolicy.logger.info("[PREVIEW] #{msg}")
      end

      return p, status
    end

    def import_from_yaml(fd)
      input = YAML.load(fd)
      input.collect do |e|
        _p, stat = import_from_hash(e["MiqPolicy"])
        stat
      end
    end
  end

  def export_to_array
    h = attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    h["MiqPolicyContent"] = miq_policy_contents.collect { |pe| pe.export_to_array.first["MiqPolicyContent"] unless pe.nil? }
    h["Condition"] = conditions.collect { |c| c.export_to_array.first["Condition"] unless c.nil? }
    [self.class.to_s => h]
  end

  def export_to_yaml
    export_to_array.to_yaml
  end
end
