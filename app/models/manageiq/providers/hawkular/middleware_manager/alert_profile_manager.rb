module ManageIQ::Providers
  class Hawkular::MiddlewareManager::AlertProfileManager
    require 'hawkular/hawkular_client'

    def initialize(ems)
      @alerts_client = ems.connect.alerts
    end

    def process_alert_profile(operation, miq_alert_profile)
      profile_id = miq_alert_profile[:id]
      old_alerts_ids = miq_alert_profile[:old_alerts_ids]
      new_alerts_ids = miq_alert_profile[:new_alerts_ids]
      old_assignments_ids = miq_alert_profile[:old_assignments_ids]
      new_assignments_ids = miq_alert_profile[:new_assignments_ids]
      case operation
      when :update_alerts
        update_alerts(profile_id, old_alerts_ids, new_alerts_ids, old_assignments_ids)
      when :update_assignments
        update_assignments(profile_id, old_alerts_ids, old_assignments_ids, new_assignments_ids)
      end
    end

    def update_alerts(profile_id, old_alerts_ids, new_alerts_ids, old_assignments_ids)
      unless old_assignments_ids.empty?
        to_remove_alerts_ids = old_alerts_ids - new_alerts_ids
        to_add_alerts_ids = new_alerts_ids - old_alerts_ids
        to_remove_alerts_ids.each do |alert_id|
          group_trigger = @alerts_client.get_single_trigger "MiQ-#{alert_id}", true
          unassign_members(group_trigger, profile_id, old_assignments_ids)
        end
        to_add_alerts_ids.each do |alert_id|
          group_trigger = @alerts_client.get_single_trigger "MiQ-#{alert_id}", true
          assign_members(group_trigger, profile_id, old_assignments_ids)
        end
      end
    end

    def update_assignments(profile_id, old_alerts_ids, old_assignments_ids, new_assignments_ids)
      to_unassign_ids = old_assignments_ids - new_assignments_ids
      to_assign_ids = new_assignments_ids - old_assignments_ids
      if to_unassign_ids.any? || to_assign_ids.any?
        old_alerts_ids.each do |alert_id|
          group_trigger = @alerts_client.get_single_trigger "MiQ-#{alert_id}", true
          unassign_members(group_trigger, profile_id, to_unassign_ids) unless to_unassign_ids.empty?
          assign_members(group_trigger, profile_id, to_assign_ids) unless to_assign_ids.empty?
        end
      end
    end

    def unassign_members(group_trigger, profile_id, members_ids)
      context, profiles = unassign_members_context(group_trigger, profile_id)
      group_trigger.context = context
      @alerts_client.update_group_trigger(group_trigger)
      if profiles.empty?
        members_ids.each do |member_id|
          @alerts_client.orphan_member("#{group_trigger.id}-#{member_id}")
          @alerts_client.delete_trigger("#{group_trigger.id}-#{member_id}")
        end
      end
    end

    def unassign_members_context(group_trigger, profile_id)
      context = group_trigger.context.nil? ? {} : group_trigger.context
      profiles = context['miq.alert_profiles'].nil? ? [] : context['miq.alert_profiles'].split(",")
      profiles -= [profile_id.to_s]
      context['miq.alert_profiles'] = profiles.uniq.join(",")
      [context, profiles]
    end

    def assign_members(group_trigger, profile_id, members_ids)
      group_trigger.context = assign_members_context(group_trigger, profile_id)
      @alerts_client.update_group_trigger(group_trigger)
      members = @alerts_client.list_members group_trigger.id
      current_members_ids = members.collect(&:id)
      members_ids.each do |member_id|
        next if current_members_ids.include?("#{group_trigger.id}-#{member_id}")
        create_new_member(group_trigger, member_id)
      end
    end

    def assign_members_context(group_trigger, profile_id)
      context = group_trigger.context.nil? ? {} : group_trigger.context
      profiles = context['miq.alert_profiles'].nil? ? [] : context['miq.alert_profiles'].split(",")
      profiles.push(profile_id.to_s)
      context['miq.alert_profiles'] = profiles.uniq.join(",")
      context
    end

    def create_new_member(group_trigger, member_id)
      server = MiddlewareServer.find(member_id)
      new_member = ::Hawkular::Alerts::Trigger::GroupMemberInfo.new
      new_member.group_id = group_trigger.id
      new_member.member_id = "#{group_trigger.id}-#{member_id}"
      new_member.member_name = "#{group_trigger.name} for #{server.name}"
      new_member.member_context = {'resource_path' => server.ems_ref.to_s}
      new_member.data_id_map = calculate_member_data_id_map(server, group_trigger)
      @alerts_client.create_member_trigger(new_member)
    end

    def calculate_member_data_id_map(server, group_trigger)
      data_id_map = {}
      prefix = group_trigger.context['dataId.hm.prefix'].nil? ? '' : group_trigger.context['dataId.hm.prefix']
      group_trigger.conditions.each do |condition|
        data_id_map[condition.data_id] = "#{prefix}MI~R~[#{server.feed}/#{server.nativeid}]~MT~#{condition.data_id}"
        unless condition.data2_id.nil?
          data_id_map[condition.data2_id] = "#{prefix}MI~R~[#{server.feed}/#{server.nativeid}]~MT~#{condition.data2_id}"
        end
      end
      data_id_map
    end
  end
end
