module MiqPolicy::ImportExport
  extend ActiveSupport::Concern

  module ClassMethods
    def import_from_hash(policy, options={})
      raise "No Policy to Import" if policy.nil?
      pe = policy.delete("MiqPolicyContent") { |k| raise "No contents for Policy == #{policy.inspect}" }
      pc = policy.delete("Condition") || []

      status = {:class => self.name, :description => policy["description"], :children => []}
      events = []

      actionsHash = {}
      eventsHash  = {}
      e2a         = {}

      pe.each { |e|
        opts = Hash.new
        ["qualifier", "success_sequence", "failure_sequence", "success_synchronous", "failure_synchronous"].each { |k|
          v = e.delete(k)
          opts[k.to_sym] = v unless v.nil?
        }

        akey = nil
        if e["MiqAction"]
          akey = e["MiqAction"]["description"]
          actionsHash[akey] = MiqAction.import_from_hash(e["MiqAction"], options) unless actionsHash.has_key?(akey)
        end

        ekey = e["MiqEvent"]["name"]
        eventsHash[ekey] = MiqEvent.import_from_hash(  e["MiqEvent"],  options) unless eventsHash.has_key?(ekey)

        e2a[ekey] = [] unless e2a.has_key?(ekey)
        e2a[ekey].push([akey, opts])
      }

      e2a.keys.each { |ekey|
        event, event_status = eventsHash[ekey]
        actions = []
        event_status[:children] ||= []
        e2a[ekey].each { |arr|
          akey, opts = arr
          unless akey.nil?
            action, s = actionsHash[akey]
            actions.push([action, opts])
            event_status[:children].push(s)
          end
        }

        events.push([event, actions])
        status[:children].push(event_status)
      }

      conditions = []
      pc.each {|c|
        c.delete("condition_id")
        condition, s = Condition.import_from_hash(c, options)
        status[:children].push(s)
        conditions.push(condition)
      }

      policy["towhat"]  ||= "Vm"      # Default "towhat" value to "Vm" to support older export decks that don't have a value set.
      policy["active"]  ||= true      # Default "active" value to true to support older export decks that don't have a value set.
      policy["mode"]    ||= "control" # Default "mode" value to true to support older export decks that don't have a value set.

      p = MiqPolicy.find_by_guid(policy["guid"])
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
        events.each { |event|
          e, a = event
          if a.empty?
            p.add_event(e) unless p.miq_events.include?(e)
          else
            p.replace_actions_for_event(e, a)
          end
        }
        p.conditions = conditions
        p.save!
      else
        MiqPolicy.logger.info("[PREVIEW] #{msg}")
      end

      return p, status
    end

    def import_from_yaml(fd)
      stats = []

      input = YAML.load(fd)
      input.each { |e|
        p, stat = import_from_hash(e["MiqPolicy"])
        stats.push(stat)
      }

      return stats
    end
  end

  def export_to_array
    h = self.attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    h["MiqPolicyContent"] = self.miq_policy_contents.collect { |pe| pe.export_to_array.first["MiqPolicyContent"] unless pe.nil? }
    h["Condition"] = self.conditions.collect { |c| c.export_to_array.first["Condition"] unless c.nil? }
    return [ self.class.to_s => h ]
  end

  def export_to_yaml
    a = export_to_array
    a.to_yaml
  end
end
