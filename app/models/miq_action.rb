require 'awesome_spawn'

class MiqAction < ApplicationRecord
  include UuidMixin
  before_validation :default_name_to_guid, :on => :create
  before_destroy    :check_policy_contents_empty_on_destroy
  before_save       :round_if_memory_reconfigured

  silence_warnings do
    const_set("TYPES",
              "create_snapshot"         => N_("Create a Snapshot"),
              "email"                   => N_("Send an E-mail"),
              "snmp_trap"               => N_("Send an SNMP Trap"),
              "tag"                     => N_("Tag"),
              "reconfigure_memory"      => N_("Reconfigure Memory"),
              "reconfigure_cpus"        => N_("Reconfigure CPUs"),
              "custom_automation"       => N_("Invoke a Custom Automation"),
              "evaluate_alerts"         => N_("Evaluate Alerts"),
              "assign_scan_profile"     => N_("Assign Profile to Analysis Task"),
              "set_custom_attribute"    => N_("Set a Custom Attribute in vCenter"),
              "inherit_parent_tags"     => N_("Inherit Parent Tags"),
              "remove_tags"             => N_("Remove Tags"),
              "delete_snapshots_by_age" => N_("Delete Snapshots by Age"),
              "run_ansible_playbook"    => N_("Run Ansible Playbook")
             )
  end

  validates_presence_of     :name, :description, :action_type
  validates_uniqueness_of   :name, :description
  validates_format_of       :name, :with => /\A[a-z0-9_\-]+\z/i,
    :allow_nil => true, :message => "must only contain alpha-numeric, underscore and hyphen chatacters without spaces"

  acts_as_miq_taggable
  acts_as_miq_set_member

  has_many :miq_policy_contents

  serialize :options, Hash

  # Add a instance method to store the sequence and synchronous values from the policy contents
  attr_accessor :sequence, :synchronous, :reserved

  SCRIPT_DIR = Rails.root.join("product/conditions/scripts").expand_path
  SCRIPT_DIR.mkpath

  RE_SUBST = /\$\{([^}]+)\}/

  RC_HASH = {
    0  => "MIQ_OK",
    4  => "MIQ_WARN",
    8  => "MIQ_STOP",
    16 => "MIQ_ABORT"
  }

  SH_PREAMBLE = begin
    preamble = "\#!/bin/sh\n"
    RC_HASH.each { |k, v| preamble += "#{v}=#{k}\n" }
    preamble
  end

  RB_PREAMBLE = "
    RC_HASH = #{RC_HASH.inspect}
    RC_HASH.each {|k, v| eval(\"\#{v} = \#{k}\")}
  "

  virtual_column :v_synchronicity,         :type => :string
  virtual_column :action_type_description, :type => :string

  def v_synchronicity
    synchronous ? "Synchronous" : "Asynchronous"
  end

  def action_type_description
    TYPES[action_type] || description
  end

  def validate
    case action_type
    when "email"
      self.options ||= {}
      self.options[:to] ||= ""
      [:from, :to].each do |k|
        if self.options && self.options[k]
          next if k == :from && self.options[k].blank? # allow blank from addres, we use the default.
          match = self.options[k] =~ /^\A([\w\.\-\+]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z$/i
          errors.add(k, "must be a valid email address") unless match
        end
      end
    when "tag"
      errors.add("tag", "no tags provided") unless self.options && self.options[:tags]
    when "snapshot_create"
      errors.add("snapshot_create", "no snapshot name provided") unless self.options && self.options[:name]
    when "reconfigure_cpus"
      errors.add("reconfigure_cpus", "CPUs valie must be 1, 2 or 4") unless self.options && [1, 2, 4].include?(self.options[:value].to_i)
    when "reconfigure_memory"
      errors.add("reconfigure_cpus", "Memory value must be between 4 and 65,536") unless self.options && self.options[:value].to_i >= 4 && self.options[:value].to_i <= 65536
    end
  end

  def miq_policies
    miq_policy_contents.collect(&:miq_policy).uniq
  end

  def self.invoke_actions(apply_policies_to, inputs, succeeded, failed)
    deferred = []
    results = {}

    begin
      failed.each do |p|
        actions = case p
                  when MiqPolicy then p.actions_for_event(inputs[:event], :failure).uniq
                  else            p.actions_for_event
                  end

        actions.each do |a|
          # merge in the synchronous flag and possibly the sequence if not already sorted by this
          inputs = inputs.merge(:policy => p, :result => false, :sequence => a.sequence, :synchronous => a.synchronous)
          _log.debug("action: [#{a.name}], seq: [#{a.sequence}], sync: [#{a.synchronous}], inputs to action: seq: [#{inputs[:sequence]}], sync: [#{inputs[:synchronous]}]")

          if a.name == "prevent"
            deferred.push([a, apply_policies_to, inputs])
            next
          end

          name = a.action_type == "default" ? a.name.to_sym : a.action_type.to_sym
          results[name] ||= []
          results[name] << {:policy_id => p.kind_of?(MiqPolicy) ? p.id : nil, :policy_status => :failure, :result => a.invoke(apply_policies_to, inputs)}
        end
      end

      succeeded.each do |p|
        next unless p.kind_of?(MiqPolicy) # built-in policies are OpenStructs whose actions will be invoked only on failure
        actions = p.actions_for_event(inputs[:event], :success).uniq
        actions.each do |a|
          inputs = inputs.merge(:policy => p, :result => true, :sequence => a.sequence, :synchronous => a.synchronous)
          _log.debug("action: [#{a.name}], seq: [#{a.sequence}], sync: [#{a.synchronous}], inputs to action: seq: [#{inputs[:sequence]}], sync: [#{inputs[:synchronous]}]")

          if a.name == "prevent"
            deferred.push([a, apply_policies_to, inputs])
            next
          end

          name = a.action_type == "default" ? a.name.to_sym : a.action_type.to_sym
          results[name] ||= []
          results[name] << {:policy_id => p.kind_of?(MiqPolicy) ? p.id : nil, :policy_status => :success, :result => a.invoke(apply_policies_to, inputs)}
        end
      end

      deferred.each do |arr|
        a, apply_policies_to, inputs = arr
        a.invoke(apply_policies_to, inputs)
      end
    rescue MiqException::StopAction => err
      MiqPolicy.logger.error("MIQ(action-invoke) Stopping action invocation [#{err.message}]")
      return
    rescue MiqException::UnknownActionRc => err
      MiqPolicy.logger.error("MIQ(action-invoke) Aborting action invocation [#{err.message}]")
      raise
    rescue MiqException::PolicyPreventAction => err
      MiqPolicy.logger.info("MIQ(action-invoke) [#{err}]")
      raise
    end

    results
  end

  def invoke(rec, inputs)
    atype = action_type
    atype = name if atype.nil? || atype == "default"
    method = "action_" + atype
    unless self.respond_to?(method)
      MiqPolicy.logger.info("MIQ(action-invoke) '#{name}', not supported")
      return
    end

    if inputs[:result]
      phrase = "for successful policy"
    else
      phrase = "for failed policy"
    end
    MiqPolicy.logger.info("MIQ(action-invoke) Invoking action [#{description}] #{phrase} [#{inputs[:policy].description}], event: [#{inputs[:event].description}], entity name: [#{rec.name}], entity type: [#{Dictionary.gettext(rec.class.to_s, :type => :model)}], sequence: [#{inputs[:sequence]}], synchronous? [#{inputs[:synchronous]}]")
    send(method.to_sym, self, rec, inputs)
  end

  def invoke_action_for_built_in_policy(rec, inputs)
    atype = action_type
    atype ||= name
    method = "action_" + atype
    unless self.respond_to?(method)
      MiqPolicy.logger.info("MIQ(action-invoke) '#{name}', not supported")
      return
    end

    MiqPolicy.logger.info("MIQ(action-invoke) Invoking action [#{description}] for built-in policy [#{inputs[:built_in_policy]}], event: [#{inputs[:event]}], entity name: [#{rec.name}], entity type: [#{Dictionary.gettext(rec.class.to_s, :type => :model)}]")
    send(method.to_sym, self, rec, inputs)
  end

  def action_prevent(_action, _rec, _inputs)
    raise MiqException::PolicyPreventAction, "preventing current process from proceeding due to policy failure"
  end

  def action_log(_action, rec, inputs)
    if inputs[:result]
      MiqPolicy.logger.info("MIQ(action-log): Policy success: policy: [#{inputs[:policy].description}], event: [#{inputs[:event].description}], entity name: [#{rec.name}], entity type: [#{Dictionary.gettext(rec.class.to_s, :type => :model)}]")
    else
      MiqPolicy.logger.warn("MIQ(action-log): Policy failure: policy: [#{inputs[:policy].description}], event: [#{inputs[:event].description}], entity name: [#{rec.name}], entity type: [#{Dictionary.gettext(rec.class.to_s, :type => :model)}]")
    end
  end

  def action_audit(_action, rec, inputs)
    msg = inputs[:result] ? "success" : "failure"
    AuditEvent.send(msg,
                    :event        => inputs[:event].name,
                    :target_id    => rec.id,
                    :target_class => rec.class.base_class.name,
                    :message      => "Policy #{msg}: policy: [#{inputs[:policy].description}], event: [#{inputs[:event].description}]")
  end

  def action_run_ansible_playbook(action, rec, inputs)
    service_template = ServiceTemplate.find(action.options[:service_template_id])
    dialog_options = { :hosts => target_hosts(action, rec) }
    request_options = { :manageiq_extra_vars => { 'event_target' => rec.href_slug,
                                                  'event_name'   => inputs[:event].try(:name) },
                        :initiator           => 'control' }
    service_template.provision_request(target_user(rec), dialog_options, request_options)
  end

  def action_snmp_trap(action, rec, inputs)
    # Validate SNMP Version
    snmp_version = action.options[:snmp_version]
    snmp_version = 2 if action.options[:snmp_version] == "v2"
    snmp_version = 1 if action.options[:snmp_version] == "v1"
    snmp_version = 1 unless [1, 2].include?(snmp_version)
    method_name = "trap_v#{snmp_version}"

    snmp_inputs = {}
    snmp_inputs[:host] = action.options[:host]
    trap_id_key = (snmp_version == 1) ? :specific_trap : :trap_oid
    snmp_inputs[trap_id_key]  = action.options[:trap_id]

    vars = []
    action.options[:variables].each do |h|
      value = h[:value]

      value = value.gsub(RE_SUBST) do |_s|
        # s  is ${anything_in_between}
        # $1 is   anything_in_between
        subst = ""
        what, method = $1.strip.split(".")

        what   = what.strip.downcase   unless what.nil?
        method = method.strip.downcase unless method.nil?
        # ${Cause.Description}
        if what == "cause"
          if method == "description"
            subst = "Policy: #{inputs[:policy].description}" if inputs[:policy].kind_of?(MiqPolicy)
            subst = "Alert: #{inputs[:policy].description}"  if inputs[:policy].kind_of?(MiqAlert)
          end
        end

        # ${Object.method}
        if what == "object"
          if method == "type"
            subst = rec.class.to_s
          elsif method == "ems" && rec.respond_to?(:ext_management_system)
            ems = rec.ext_management_system
            subst = "vCenter #{ems.hostname}/#{ems.ipaddress}" unless ems.nil?
          elsif rec.respond_to?(method)
            subst = rec.send(method)
          end
        end

        subst
      end unless value.nil?

      h[:value] = value
      vars << h
    end unless action.options[:variables].nil?

    snmp_inputs[:object_list] = vars

    invoke_or_queue(
      inputs[:synchronous], __method__, "notifier", nil, MiqSnmp, method_name, [snmp_inputs],
      "SNMP Trap [#{rec[:name]}]")
  end

  def action_email(action, rec, inputs)
    return unless MiqRegion.my_region.role_assigned?('notifier')

    action.options[:from] = ::Settings.smtp.from if action.options[:from].blank?

    email_options = {
      :to   => action.options[:to],
      :from => action.options[:from],
    }
    if inputs[:policy].kind_of?(MiqPolicy)
      presult = inputs[:result] ? "Succeeded" : "Failed"
      email_options[:subject] = "Policy #{presult}: #{inputs[:policy].description}, for (#{rec.class.to_s.upcase}) #{rec.name}"
      email_options[:miq_action_hash] = {
        :header            => inputs[:result] ? "Policy Succeeded" : "Policy Failed",
        :policy_detail     => "Policy '#{inputs[:policy].description}', #{presult}",
        :event_description => inputs[:event].description,
        :entity_type       => rec.class.to_s,
        :entity_name       => rec.name
      }
    elsif inputs[:policy].kind_of?(MiqAlert)
      email_options[:subject] = "Alert Triggered: #{inputs[:policy].description}, for (#{rec.class.to_s.upcase}) #{rec.name}"
      email_options[:miq_action_hash] = {
        :header            => "Alert Triggered",
        :policy_detail     => "Alert '#{inputs[:policy].description}', triggered",
        :event_description => inputs[:event].description,
        :event_details     => Notification.notification_text(inputs[:triggering_type], inputs[:triggering_data]),
        :entity_type       => rec.class.to_s,
        :entity_name       => rec.name
      }
    end

    invoke_or_queue(inputs[:synchronous], __method__, "notifier", nil, MiqAction, 'queue_email', [email_options])
  end

  def self.queue_email(options)
    GenericMailer.deliver_queue(:policy_action_email, options)
  rescue Exception => err
    MiqPolicy.logger.log_backtrace(err)
  end

  def action_evm_event(action, rec, inputs)
    default_options = {
      :event_type => "EVMAlertEvent",
      :message    => "#{inputs[:policy].kind_of?(MiqAlert) ? "Alert:" : "Policy:"} #{inputs[:policy].description}",
      :is_task    => false,
      :source     => inputs[:policy].class.name,
      :timestamp  => Time.now.utc
    }
    opts = default_options.merge(action.options || {})
    opts[:target] = rec

    opts[:ems_id] = rec.ext_management_system.id if rec.respond_to?(:ext_management_system) && rec.ext_management_system
    case rec
    when VmOrTemplate
      opts[:vm_or_template_id] = rec.id
      opts[:vm_name]           = rec.name
      opts[:vm_location]       = rec.location
      unless rec.host.nil?
        opts[:host_id]    = rec.host.id
        opts[:host_name]  = rec.host.name
      end
    when Host
      opts[:host_id]    = rec.id
      opts[:host_name]  = rec.name
    when EmsCluster
      opts[:ems_cluster_id]    = rec.id
      opts[:ems_cluster_name]  = rec.name
      opts[:ems_cluster_uid]   = rec.uid_ems
    end

    MiqEvent.create(opts)
  end

  def action_compliance_failed(action, rec, _inputs)
    # Nothing to do here. This action will get added to the :actions list in results and will be acted on by the Compliance.check_compliance methods
    MiqPolicy.logger.info("MIQ(action_compliance_failed): Now executing [#{action.description}] of #{rec.class.name} [#{rec.name}]")
  end

  def action_check_compliance(action, rec, inputs)
    unless rec.respond_to?(:check_compliance_queue)
      MiqPolicy.logger.error("MIQ(action_check_compliance): Unable to perform action [#{action.description}], object [#{rec.inspect}] does not support compliance checking")
      return
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_check_compliance): Now executing [#{action.description}] of #{rec.class.name} [#{rec.name}]")
      rec.check_compliance
    else
      MiqPolicy.logger.info("MIQ(action_vm_migrate): Queueing [#{action.description}] of #{rec.class.name} [#{rec.name}]")
      rec.check_compliance_queue
    end
  end

  def action_tag(action, rec, _inputs)
    MiqPolicy.logger.info("MIQ(action_tag): Applying tags [#{action.options[:tags].inspect}] to [(#{rec.class}) #{rec.name}]")
    action.options[:tags].each { |t| Classification.classify_by_tag(rec, t) }
  end

  def action_tag_inherit(_action, rec, inputs)
    get_policies_from = inputs[:get_policies_from]
    MiqPolicy.logger.info("MIQ(action_tag_inherit): Applying tags from [(#{get_policies_from.class}) #{get_policies_from.name}] to [(#{rec.class}) #{rec.name}]")
    tags = get_policies_from.tag_list(:ns => "/managed").split
    tags.delete_if { |t| t =~ /^power_state/ } # omit power state since this is assigned by the system

    tags.each { |t| Classification.classify_by_tag(rec, File.join("/managed", t)) }
  end

  def action_inherit_parent_tags(_action, rec, _inputs)
    # options = {
    #   :parent_type => host | ems_cluster | storage
    #   :cats        => [array of categories]
    # }
    parent = rec.send(options[:parent_type]) if rec.respond_to?(options[:parent_type])
    if parent.nil?
      MiqPolicy.logger.warn("MIQ(action_inherit_parent_tags): [(#{rec.class}) #{rec.name}] does not have a parent of type [#{options[:parent_type]}], no action will be taken")
      return
    end

    options[:cats].each do |cat|
      MiqPolicy.logger.info("MIQ(action_inherit_parent_tags): Removing tags from category [(#{cat}) from [(#{rec.class}) #{rec.name}]")
      rec.tag_with("", :ns => "/managed/#{cat}")
    end
    rec.reload

    Classification.get_tags_from_object(parent).each do |t|
      cat, _ent = t.split("/")
      next unless options[:cats].include?(cat)

      MiqPolicy.logger.info("MIQ(action_inherit_parent_tags): Applying tag [#{t}] from [(#{parent.class}) #{parent.name}] to [(#{rec.class}) #{rec.name}]")
      Classification.classify_by_tag(rec, "/managed/#{t}", false)
    end
  end

  def action_remove_tags(_action, rec, _inputs)
    # options = {
    #   :cats        => [array of categories]
    # }
    Classification.get_tags_from_object(rec).each do |t|
      cat, _ent = t.split("/")
      next unless options[:cats].include?(cat)

      MiqPolicy.logger.info("MIQ(action_remove_tags): Removing tag [#{t}] from [(#{rec.class}) #{rec.name}]")
      Classification.unclassify_by_tag(rec, "/managed/#{t}", false)
    end
  end

  def self.inheritable_cats
    Classification.in_my_region.categories.inject([]) do |arr, c|
      next(arr) if c.name.starts_with?("folder_path_") || c.entries.empty?
      arr << c
    end
  end

  def run_script(rec)
    filename = self.options[:filename]
    raise _("unable to execute script, no file name specified") if filename.nil?

    unless File.exist?(filename)
      raise _("unable to execute script, file name [%{file_name}] does not exist") % {:file_name => filename}
    end

    command_result = nil
    ruby_file = File.extname(filename) == '.rb'

    Tempfile.open('miq_action', SCRIPT_DIR) do |fd|
      fd.puts ruby_file ? RB_PREAMBLE : SH_PREAMBLE
      fd.puts File.read(filename)
      fd.chmod(0755)

      MiqPolicy.logger.info("MIQ(action_script): Executing: [#{filename}]")

      if ruby_file
        runner_cmd = MiqEnvironment::Command.runner_command
        MiqPolicy.logger.info("MIQ(action_script): Running: [#{runner_cmd} #{fd.path} '#{rec.name}'}]")
        command_result = AwesomeSpawn.run(runner_cmd, :params => [fd.path, rec.name])
      else
        MiqPolicy.logger.info("MIQ(action_script): Running: [#{fd.path}]")
        command_result = AwesomeSpawn.run(fname)
      end
    end

    rc = command_result.exit_status
    rc_verbose = RC_HASH[rc] || "Unknown RC: [#{rc}]"

    MiqPolicy.logger.info("MIQ(action_script): Result:\n#{result}")

    info_msg = "MIQ(action_script): Result: #{command_result.output}, rc: #{rc_verbose}"

    fail_msg = _("Action script exited with rc=%{rc_value}, error=%{error_text}") %
      {:rc_value => rc_verbose, :error_text => command_result.error}

    case rc
    when 0  # Success
      MiqPolicy.logger.info(info_msg)
    when 4  # Interrupted
      MiqPolicy.logger.warn(info_msg)
    when 8  # Exec format error
      raise MiqException::StopAction, fail_msg
    when 16 # Resource busy
      raise MiqException::AbortAction, fail_msg
    else
      raise MiqException::UnknownActionRc, fail_msg
    end
  end

  def action_script(action, rec, inputs)
    invoke_or_queue(inputs[:synchronous], __method__, nil, nil, action, 'run_script', [rec],
                    "Action Script [#{rec[:name]}]")
  end

  VM_ACTIONS_WITH_NO_ARGS = {
    "action_vm_start"                     => "start",
    "action_vm_stop"                      => "stop",
    "action_vm_suspend"                   => "suspend",
    "action_vm_shutdown_guest"            => "shutdown_guest",
    "action_vm_standby_guest"             => "standby_guest",
    "action_vm_unregister"                => "unregister",
    "action_vm_mark_as_template"          => "mark_as_template",
    "action_vm_analyze"                   => "scan",
    "action_vm_destroy"                   => "vm_destroy",
    "action_delete_all_snapshots"         => "remove_all_snapshots",
    "action_vm_connect_all"               => "connect_all_devices",
    "action_vm_connect_floppy"            => "connect_floppies",
    "action_vm_connect_cdrom"             => "connect_cdroms",
    "action_vm_disconnect_all"            => "disconnect_all_devices",
    "action_vm_disconnect_floppy"         => "disconnect_floppies",
    "action_vm_disconnect_cdrom"          => "disconnect_cdroms",
    "action_vm_collect_running_processes" => "collect_running_processes",
  }

  VM_ACTIONS_WITH_NO_ARGS.each do |action_method, vm_method|
    define_method(action_method) do |action, rec, inputs|
      unless rec.kind_of?(VmOrTemplate)
        MiqPolicy.logger.error("MIQ(#{action_method}): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
        return
      end

      invoke_or_queue(
        inputs[:synchronous], action_method, vm_method == "scan" ? "smartstate" : "ems_operations", rec.my_zone,
        rec, vm_method, [], "[#{action.description}] of VM [#{rec.name}]")
    end
  end

  def action_physical_server_power_on(action, rec, inputs)
    unless rec.kind_of?(PhysicalServer)
      MiqPolicy.logger.error("MIQ(physical_server_power_on): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a physical server")
      return
    end

    invoke_or_queue(inputs[:synchronous], __method__, "ems_operations", rec.my_zone, rec, 'power_on',
                    [], "[#{action.description}] of physical server [#{rec.name}]")
  end

  def action_vm_mark_as_vm(action, rec, inputs)
    unless rec.kind_of?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_vm_mark_as_vm): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end

    invoke_or_queue(inputs[:synchronous], __method__, "ems_operations", rec.my_zone, rec, 'mark_as_vm',
                    [action.options[:pool], action.options[:host]], "[#{action.description}] of VM [#{rec.name}]")
  end

  def action_vm_migrate(action, rec, inputs)
    unless rec.kind_of?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_vm_migrate): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end

    invoke_or_queue(inputs[:synchronous], __method__, "ems_operations", rec.my_zone, rec, 'migrate',
                    [action.options[:host], action.options[:pool], action.options[:priority], action.options[:state]],
                    "[#{action.description}] of VM [#{rec.name}]")
  end

  def action_vm_clone(action, rec, inputs)
    unless rec.kind_of?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_vm_clone): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end

    invoke_or_queue(
      inputs[:synchronous], __method__, "ems_operations", rec.my_zone, rec, 'clone',
      [
        action.options[:name], action.options[:folder], action.options[:pool], action.options[:host],
        action.options[:datastore], action.options[:powerOn], action.options[:template], action.options[:transform],
        action.options[:config], action.options[:customization], action.options[:disk]
      ],
      "[#{action.description}] of VM [#{rec.name}]")
  end

  # Legacy: Replaces by action_vm_analyze
  def action_vm_scan(action, rec, inputs)
    action_vm_analyze(action, rec, inputs)
  end

  def action_vm_retire(action, rec, inputs)
    unless rec.kind_of?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_vm_retire): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end

    target = inputs[:synchronous] ? VmOrTemplate : rec.class
    invoke_or_queue(
      inputs[:synchronous], __method__, "ems_operations", rec.my_zone, target, 'retire',
      [[rec], :date => Time.zone.now - 1.day],
      "VM Retire for VM [#{rec.name}]")
  end

  def action_create_snapshot(action, rec, inputs)
    unless rec.kind_of?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_create_snapshot): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end
    action.options[:description] ||= "Created by EVM Policy Action"

    invoke_or_queue(inputs[:synchronous], __method__, "ems_operations", rec.my_zone, rec, 'create_snapshot',
                    [action.options[:name], action.options[:description]],
                    "Create Snapshot [#{action.options[:name]}] for VM [#{rec.name}]")
  end

  def action_delete_snapshots_by_age(action, rec, _inputs)
    log_prefix = "MIQ(action_delete_snapshots_by_age):"
    unless rec.kind_of?(VmOrTemplate)
      MiqPolicy.logger.error("#{log_prefix} Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end
    log_prefix += " VM: [#{rec.name}] Id: [#{rec.id}]"

    age_threshold = (Time.now.utc - action.options[:age])
    has_ch = false
    snaps_to_delete = rec.snapshots.each_with_object([]) do |s, arr|
      has_ch = true if s.is_a_type?(:consolidate_helper)
      next if s.is_a_type?(:evm_snapshot) || s.is_a_type?(:vcb_snapshot)

      arr << s if s.create_time < age_threshold
    end

    if snaps_to_delete.empty?
      MiqPolicy.logger.info("#{log_prefix} has no snapshots older than [#{age_threshold}]")
      return
    end

    if has_ch
      MiqPolicy.logger.warn("#{log_prefix} has a Consolidate Helper snapshot, no shanpshots will be deleted")
      return
    end

    task_id = "action_#{action.id}_vm_#{rec.id}"
    snaps_to_delete.sort_by(&:create_time).reverse.each do |s| # Delete newest to oldest
      MiqPolicy.logger.info("#{log_prefix} Deleting Snapshot: Name: [#{s.name}] Id: [#{s.id}] Create Time: [#{s.create_time}]")
      rec.remove_snapshot_queue(s.id, task_id)
    end
  end

  def action_delete_most_recent_snapshot(action, rec, _inputs)
    log_prefix = "MIQ(action_delete_most_recent_snapshot):"
    unless rec.kind_of?(VmOrTemplate)
      MiqPolicy.logger.error("#{log_prefix} Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end
    log_prefix += " VM: [#{rec.name}] Id: [#{rec.id}]"

    has_ch = false
    snap   = nil
    rec.snapshots.order("create_time DESC").each do |s|
      if s.is_a_type?(:consolidate_helper)
        has_ch = true
        next
      end
      next if s.is_a_type?(:evm_snapshot) || s.is_a_type?(:vcb_snapshot)

      snap ||= s # Take the first eligable snapshot
    end

    if snap.nil?
      MiqPolicy.logger.info("#{log_prefix} has no snapshots available to delete")
      return
    end

    if has_ch
      MiqPolicy.logger.warn("#{log_prefix} has a Consolidate Helper snapshot, no shanpshot will be deleted")
      return
    end

    MiqPolicy.logger.info("#{log_prefix} Deleting Snapshot: Name: [#{snap.name}] Id: [#{snap.id}] Create Time: [#{snap.create_time}]")
    rec.remove_snapshot_queue(snap.id)
  end

  def action_reconfigure_memory(action, rec, inputs)
    unless rec.kind_of?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_reconfigure_memory): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end

    unless action.options[:value]
      MiqPolicy.logger.error("MIQ(action_reconfigure_memory): Unable to perform action [#{action.description}], object [#{rec.inspect}] no memory value given")
      return
    end

    invoke_or_queue(inputs[:synchronous], __method__, "ems_operations", rec.my_zone, rec, 'set_memory',
                    [action.options[:value]],
                    "[#{action.description}] for VM [#{rec.name}], Memory value: [#{action.options[:value]}]")
  end

  def action_reconfigure_cpus(action, rec, inputs)
    unless rec.kind_of?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_reconfigure_cpus): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end

    unless action.options[:value]
      MiqPolicy.logger.error("MIQ(action_reconfigure_cpus): Unable to perform action [#{action.description}], object [#{rec.inspect}] no cpu value given")
      return
    end

    invoke_or_queue(inputs[:synchronous], __method__, "ems_operations", rec.my_zone, rec, 'set_number_of_cpus',
                    [[action.options[:value]]],
                    "Reconfigure CPUs for VM [#{rec.name}], CPUs value: [#{action.options[:value]}]")
  end

  def action_ems_refresh(action, rec, inputs)
    unless rec.respond_to?(:ext_management_system) && !rec.ext_management_system.nil?
      MiqPolicy.logger.error("MIQ(action_ems_refresh): Unable to perform action [#{action.description}], object [#{rec.inspect}] does not have a Provider")
      return
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_ems_refresh): Now executing EMS refresh of [#{rec.name}]")
      EmsRefresh.refresh(rec)
    else
      MiqPolicy.logger.info("MIQ(action_ems_refresh): Queueing EMS refresh of [#{rec.name}]")
      EmsRefresh.queue_refresh(rec)
    end
  end

  def action_container_image_analyze(action, rec, inputs)
    unless rec.kind_of?(ContainerImage)
      MiqPolicy.logger.error("MIQ(#{__method__}): Unable to perform action [#{action.description}],"\
                             " object [#{rec.inspect}] is not a Container Image")
      return
    end

    if inputs[:event].name == "request_containerimage_scan"
      MiqPolicy.logger.warn("MIQ(#{__method__}): Invoking action [#{action.description}] for event"\
                            " [#{inputs[:event].description}] would cause infinite loop, skipping")
      return
    end

    MiqPolicy.logger.info("MIQ(#{__method__}): Now executing [#{action.description}] of Container Image "\
                            "[#{rec.name}]")
    rec.scan
  end

  def action_container_image_annotate_scan_results(action, rec, inputs)
    MiqPolicy.logger.info("MIQ(#{__method__}): Now executing  [#{action.description}]")
    error_prefix = "MIQ(#{__method__}): Unable to perform action [#{action.description}], "
    unless rec.kind_of?(ContainerImage)
      MiqPolicy.logger.error("#{error_prefix} object [#{rec.inspect}] is not a Container Image")
      return
    end

    unless rec.respond_to?(:annotate_scan_policy_results)
      MiqPolicy.logger.error("#{error_prefix} ContainerImage is not linked with an OpenShift image")
      return
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(#{__method__}): Now executing  [#{action.description}] for event "\
                            "[#{inputs[:event].description}]")
      rec.annotate_scan_policy_results(inputs[:policy].name, inputs[:result])
    else
      MiqPolicy.logger.info("MIQ(#{__method__}): Queueing [#{action.description}] for event "\
                            "[#{inputs[:event].description}]")
      MiqQueue.submit_job(
        :service     => "ems_operations",
        :affinity    => rec.ext_management_system,
        :class_name  => rec.class.name,
        :method_name => :annotate_scan_policy_results,
        :args        => [inputs[:policy].name, inputs[:result]],
        :instance_id => rec.id,
        :priority    => MiqQueue::HIGH_PRIORITY,
      )
    end
  end

  def action_host_analyze(action, rec, inputs)
    action_method = "action_host_analyze"
    if inputs[:event].name == "request_host_scan"
      MiqPolicy.logger.warn("MIQ(#{action_method}): Invoking action [#{action.description}] for event [#{inputs[:event].description}] would cause infinite loop, skipping")
      return
    end

    unless rec.kind_of?(Host)
      MiqPolicy.logger.error("MIQ(#{action_method}): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a Host")
      return
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(#{action_method}): Now executing [#{action.description}] of Host [#{rec.name}]")
      rec.scan
    else
      MiqPolicy.logger.info("MIQ(#{action_method}): Queueing [#{action.description}] of Host [#{rec.name}]")
      MiqQueue.submit_job(
        :service     => "smartstate",
        :affinity    => rec.ext_management_system,
        :class_name  => "Host",
        :method_name => "scan_from_queue",
        :instance_id => rec.id,
        :priority    => MiqQueue::HIGH_PRIORITY,
      )
    end
  end

  def action_cancel_task(action, rec, inputs)
    unless rec.respond_to?(:ext_management_system) && !rec.ext_management_system.nil?
      MiqPolicy.logger.error("MIQ(action_cancel_task): Unable to perform action [#{action.description}], object [#{rec.inspect}] does not have a Provider")
      return
    end

    source_event = inputs[:source_event]
    task_mor = source_event.full_data.try(:fetch_path, 'info', 'task')
    unless task_mor
      MiqPolicy.logger.warn("MIQ(action_cancel_task): Event record does not have a task reference, no action will be taken")
      return
    end

    MiqPolicy.logger.info("MIQ(action_cancel_task): Now executing Cancel of task [#{source_event.event_type}] on VM [#{source_event.vm_name}]")
    ems = ExtManagementSystem.find_by(:id => source_event.ems_id)
    raise _("unable to find vCenter with id [%{id}]") % {:id => source_event.ems_id} if ems.nil?

    vim = ems.connect
    vim.cancelTask(task_mor)
  end

  def action_custom_automation(action, rec, inputs)
    ae_hash = action.options[:ae_hash] || {}
    automate_attrs = ae_hash.reject { |key, _value| MiqAeEngine::DEFAULT_ATTRIBUTES.include?(key) }
    automate_attrs[:request] = action.options[:ae_request]
    MiqAeEngine.set_automation_attributes_from_objects([inputs[:policy], inputs[:source_event]], automate_attrs)

    user = rec.tenant_identity
    unless user
      raise _("A user is needed to raise an action to automate. [%{name}] id:[%{id}] action: [%{description}]") %
              {:name => rec.class.name, :id => rec.id, :description => action.description}
    end

    args = {
      :object_type      => rec.class.base_class.name,
      :object_id        => rec.id,
      :user_id          => user.id,
      :miq_group_id     => user.current_group.id,
      :tenant_id        => user.current_tenant.id,
      :attrs            => automate_attrs,
      :instance_name    => "REQUEST",
      :automate_message => action.options[:ae_message] || "create",
    }

    invoke_or_queue(inputs[:synchronous], __method__, "automate", nil, MiqAeEngine, 'deliver', [args],
                    "MiqAeEngine.deliver for #{automate_attrs[:request]} with args=#{args.inspect}")
  end

  def action_raise_automation_event(_action, rec, inputs)
    event = inputs[:event].name
    aevent = {}
    aevent[:vm]     = inputs[:vm]
    aevent[:host]   = inputs[:host]
    aevent[:ems]    = inputs[:ext_management_systems]
    aevent[:policy] = inputs[:policy]

    case rec
    when VmOrTemplate
      aevent[:vm]    = rec
    when Host
      aevent[:host]  = rec
    when EmsCluster
      aevent[:ems]   = rec
    end

    invoke_or_queue(inputs[:synchronous], __method__, "automate", rec.my_zone, MiqAeEvent, 'raise_synthetic_event',
                    [rec, event, aevent], "Raise Automation Event, Event: [#{event}]")
  end

  def action_evaluate_alerts(action, rec, inputs)
    action.options[:alert_guids].each do |guid|
      alert = MiqAlert.find_by(:guid => guid)
      unless alert
        MiqPolicy.logger.warn("MIQ(action_evaluate_alert): Unable to perform action [#{action.description}], unable to find alert: [#{action.options[:alert_guid]}]")
        next
      end

      invoke_or_queue(inputs[:synchronous], __method__, nil, rec.my_zone, alert, 'evaluate', [rec, inputs],
                      "Evaluate Alert, Alert: [#{alert.description}]")
    end
  end

  def action_assign_scan_profile(action, _rec, _inputs)
    ScanItem  # Cause the ScanItemSet class to load, if not already loaded
    profile = ScanItemSet.find_by(:name => action.options[:scan_item_set_name])
    if profile
      MiqPolicy.logger.info("MIQ(action_assign_scan_profile): Action [#{action.description}], using analysis profile: [#{profile.description}]")
      return ScanItem.get_profile(profile.name)
    else
      MiqPolicy.logger.warn("MIQ(action_assign_scan_profile): Unable to perform action [#{action.description}], unable to find analysis profile: [#{action.options[:scan_item_set_name]}]")
      return
    end
  end

  def action_set_custom_attribute(action, rec, inputs)
    unless rec.kind_of?(VmOrTemplate) || rec.kind_of?(Host)
      MiqPolicy.logger.error("MIQ(action_set_custom_attribute): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM or a Host")
      return
    end

    invoke_or_queue(inputs[:synchronous], __method__, "ems_operations", rec.my_zone, rec, 'set_custom_field',
                    [action.options[:attribute], action.options[:value]],
                    "#{action.description} [#{action.options[:attribute]}] for VM [#{rec.name}]")
  end

  def export_to_array
    h = attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    [self.class.to_s => h]
  end

  def self.import_from_hash(action, options = {})
    status = {:class => name, :description => action["description"]}
    a = MiqAction.find_by(:description => action["description"])
    msg_pfx = "Importing Action: description=[#{action["description"]}]"

    if a.nil?
      a = MiqAction.new(action)
      status[:status] = :add
    else
      a.attributes = action
      status[:status] = :update
    end

    unless a.valid?
      status[:status]   = :conflict
      status[:messages] = a.errors.full_messages
    end

    msg = "#{msg_pfx}, Status: #{status[:status]}"
    msg += ", Messages: #{status[:messages].join(",")}" if status[:messages]
    if options[:preview] == true
      MiqPolicy.logger.info("[PREVIEW] #{msg}")
    else
      MiqPolicy.logger.info(msg)
      a.save!
    end

    return a, status
  end

  def check_policy_contents_empty_on_destroy
    raise _("Action is referenced in at least one policy and connot be deleted") unless miq_policy_contents.empty?
  end

  def round_if_memory_reconfigured
    # round memory value to the nearest 4mb
    self.options[:value] = round_to_nearest_4mb(self.options[:value]) if action_type == "reconfigure_memory"
  end

  def round_to_nearest_4mb(num)
    num = num.to_i
    pad = (-num) % 4
    num + pad
  end

  def self.seed
    create_default_actions
    create_script_actions_from_directory
  end

  def self.create_default_actions
    CSV.foreach(fixture_path, :headers => true, :skip_lines => /^#/) do |csv_row|
      action_attributes = csv_row.to_hash
      action_attributes['action_type'] = 'default'

      create_or_update(action_attributes)
    end
  end

  def self.create_script_actions_from_directory
    Dir.glob(SCRIPT_DIR.join("*")).sort.each do |f|
      create_or_update(
        'name'        => File.basename(f).tr(".", "_"),
        'description' => "Execute script: #{File.basename(f)}",
        'action_type' => "script",
        'options'     => {:filename => f}
      )
    end
  end

  def self.create_or_update(action_attributes)
    name = action_attributes['name']
    action = find_by(:name => name)
    if action
      action.attributes = action_attributes
      if action.changed? || action.options_was != action.options
        _log.info("Updating [#{name}]")
        action.save
      end
    else
      _log.info("Creating [#{name}]")
      create(action_attributes)
    end
  end

  def self.fixture_path
    FIXTURE_DIR.join("#{to_s.pluralize.underscore}.csv")
  end

  def self.display_name(number = 1)
    n_('Action', 'Actions', number)
  end

  private

  def invoke_or_queue(
    synchronous,
    calling_method,
    role,
    zone,
    target,
    target_method,
    target_args = [],
    log_suffix = nil
  )
    log_prefix = "MIQ(#{calling_method}):"
    log_suffix ||= calling_method.to_s.titleize[7..-1] # remove 'Action '
    static = target.instance_of?(Class) || target.instance_of?(Module)

    if synchronous
      MiqPolicy.logger.info("#{log_prefix} Now executing #{log_suffix}")
      target.send(target_method, *target_args)
    else
      MiqPolicy.logger.info("#{log_prefix} Queueing #{log_suffix}")
      MiqQueue.put(
        :class_name  => static ? target.name : target.class.name,
        :method_name => target_method,
        :instance_id => static ? nil : target.id,
        :args        => target_args,
        :role        => role,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => zone
      )
    end
  end

  def target_hosts(action, rec)
    if action.options[:use_event_target]
      ipaddress(rec)
    elsif action.options[:use_localhost]
      'localhost'
    else
      action.options[:hosts]
    end
  end

  def ipaddress(record)
    record.ipaddresses[0] if record.respond_to?(:ipaddresses)
  end

  def target_user(record)
    record.respond_to?(:tenant_identity) ? record.tenant_identity : default_user
  end

  def default_user
    User.super_admin.tap { |u| u.current_group = Tenant.root_tenant.default_miq_group }
  end
end
