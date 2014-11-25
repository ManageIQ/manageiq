class MiqAction < ActiveRecord::Base
  default_scope :conditions => self.conditions_for_my_region_default_scope

  include UuidMixin
  before_validation :default_name_to_guid, :on => :create
  before_destroy    :check_policy_contents_empty_on_destroy
  before_save       :round_if_memory_reconfigured

  silence_warnings {
    const_set("TYPES",
      {
        "create_snapshot"         => "Create a Snapshot",
        "email"                   => "Send an E-mail",
        "snmp_trap"               => "Send an SNMP Trap",
        "tag"                     => "Tag",
        "reconfigure_memory"      => "Reconfigure Memory",
        "reconfigure_cpus"        => "Reconfigure CPUs",
        "custom_automation"       => "Invoke a Custom Automation",
        "evaluate_alerts"         => "Evaluate Alerts",
        "assign_scan_profile"     => "Assign Profile to Analysis Task",
        "set_custom_attribute"    => "Set a Custom Attribute in vCenter",
        "inherit_parent_tags"     => "Inherit Parent Tags",
        "remove_tags"             => "Remove Tags",
        "delete_snapshots_by_age" => "Delete Snapshots by Age"
      }
    )
  }

  validates_presence_of     :name, :description, :action_type
  validates_uniqueness_of   :name, :description
  validates_format_of       :name, :with => %r{\A[a-z0-9_\-]+\z}i,
    :allow_nil => true, :message => "must only contain alpha-numeric, underscore and hyphen chatacters without spaces"

  acts_as_miq_taggable
  acts_as_miq_set_member
  include ReportableMixin

  has_many :miq_policy_contents

  serialize :options, Hash

  # Add a instance method to store the sequence and synchronous values from the policy contents
  attr_accessor :sequence, :synchronous, :reserved

  FIXTURE_DIR = File.join(Rails.root, "db/fixtures")

  SCRIPT_DIR = File.expand_path(File.join(Rails.root, "product/conditions/scripts"))
  FileUtils.mkdir_p(SCRIPT_DIR) unless File.exist?(SCRIPT_DIR)

  RE_SUBST = /\$\{([^}]+)\}/

  RC_HASH = {
    0  => "MIQ_OK",
    4  => "MIQ_WARN",
    8  => "MIQ_STOP",
    16 => "MIQ_ABORT"
  }

  SH_PREAMBLE = begin
    preamble = "\#!/bin/sh\n"
    RC_HASH.each {|k, v| preamble += "#{v}=#{k}\n" }
    preamble
  end

  RB_PREAMBLE = "
    RC_HASH = #{RC_HASH.inspect}
    RC_HASH.each {|k, v| eval(\"\#{v} = \#{k}\")}
  "

  virtual_column :v_synchronicity,         :type => :string
  virtual_column :action_type_description, :type => :string

  def v_synchronicity
    return self.synchronous ? "Synchronous" : "Asynchronous"
  end

  def action_type_description
    TYPES[self.action_type] || self.description
  end

  def validate
    case self.action_type
    when "email"
      self.options ||= {}
      self.options[:to] ||= ""
      [:from, :to].each {|k|
        if self.options && self.options[k]
          next if k == :from && self.options[k].blank? # allow blank from addres, we use the default.
          match = self.options[k] =~ %r{^\A([\w\.\-\+]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z$}i
          errors.add(k, "must be a valid email address") unless match
        end
      }
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
    self.miq_policy_contents.collect {|pe| pe.miq_policy}.uniq
  end

  def self.invoke_actions(apply_policies_to, inputs, succeeded, failed)
    deferred = []
    # $log.info("XXX(action-invoke_actions) succeeded policies: #{succeeded.inspect}")
    # $log.info("XXX(action-invoke_actions) failed policies: #{failed.inspect}")

    results = {}

    begin
      failed.each {|p|
        actions = case p
        when MiqPolicy; p.actions_for_event(inputs[:event], :failure).uniq
        else            p.actions_for_event
        end

        #        $log.debug("MIQ(action-invoke_actions) actions on failure: #{actions.inspect}")
        actions.each {|a|
          # merge in the synchronous flag and possibly the sequence if not already sorted by this
          inputs = inputs.merge(:policy => p, :result => false, :sequence => a.sequence, :synchronous => a.synchronous)
          $log.debug("MIQ(action-invoke_actions) action: [#{a.name}], seq: [#{a.sequence}], sync: [#{a.synchronous}], inputs to action: seq: [#{inputs[:sequence]}], sync: [#{inputs[:synchronous]}]")

          if a.name == "prevent"
            deferred.push([a, apply_policies_to, inputs])
            next
          end

          name = a.action_type == "default" ? a.name.to_sym : a.action_type.to_sym
          results[name] ||= []
          results[name] << {:policy_id => p.kind_of?(MiqPolicy) ? p.id : nil, :policy_status => :failure, :result => a.invoke(apply_policies_to, inputs)}
        }
      }

      succeeded.each {|p|
        next unless p.is_a?(MiqPolicy) # built-in policies are OpenStructs whose actions will be invoked only on failure
        actions = p.actions_for_event(inputs[:event], :success).uniq
        # $log.info("MIQ(action-invoke_actions) actions on success: #{actions.inspect}")
        actions.each {|a|
          inputs = inputs.merge(:policy => p, :result => true, :sequence => a.sequence, :synchronous => a.synchronous)
          $log.debug("MIQ(action-invoke_actions) action: [#{a.name}], seq: [#{a.sequence}], sync: [#{a.synchronous}], inputs to action: seq: [#{inputs[:sequence]}], sync: [#{inputs[:synchronous]}]")

          if a.name == "prevent"
            deferred.push([a, apply_policies_to, inputs])
            next
          end

          name = a.action_type == "default" ? a.name.to_sym : a.action_type.to_sym
          results[name] ||= []
          results[name] << {:policy_id => p.kind_of?(MiqPolicy) ? p.id : nil, :policy_status => :success, :result => a.invoke(apply_policies_to, inputs)}
        }
      }

      deferred.each {|arr|
        a, apply_policies_to, inputs = arr
        result = a.invoke(apply_policies_to, inputs)
      }
    rescue MiqException::StopAction => err
      MiqPolicy.logger.error("MIQ(action-invoke) Stopping action invocation [#{err.message}]")
      return
    rescue MiqException::UnknownActionRc => err
      MiqPolicy.logger.error("MIQ(action-invoke) Aborting action invocation [#{err.message}]")
      raise
    rescue MiqException::PolicyPreventAction => err
      MiqPolicy.logger.info "MIQ(action-invoke) [#{err}]"
      raise
    end

    return results
  end

  def invoke(rec, inputs)
    atype = self.action_type
    atype = self.name if atype.nil? || atype == "default"
    method = "action_" + atype
    unless self.respond_to?(method)
      MiqPolicy.logger.info("MIQ(action-invoke) '#{self.name}', not supported")
      return
    end

    if inputs[:result]
      phrase = "for successful policy"
    else
      phrase = "for failed policy"
    end
    MiqPolicy.logger.info("MIQ(action-invoke) Invoking action [#{self.description}] #{phrase} [#{inputs[:policy].description}], event: [#{inputs[:event].description}], entity name: [#{rec.name}], entity type: [#{Dictionary.gettext(rec.class.to_s, :type=>:model)}], sequence: [#{inputs[:sequence]}], synchronous? [#{inputs[:synchronous]}]")
    self.send(method.to_sym, self, rec, inputs)
  end

  def invoke_action_for_built_in_policy(rec, inputs)
    atype = self.action_type
    atype ||= self.name
    method = "action_" + atype
    unless self.respond_to?(method)
      MiqPolicy.logger.info("MIQ(action-invoke) '#{self.name}', not supported")
      return
    end

    MiqPolicy.logger.info("MIQ(action-invoke) Invoking action [#{self.description}] for built-in policy [#{inputs[:built_in_policy]}], event: [#{inputs[:event]}], entity name: [#{rec.name}], entity type: [#{Dictionary.gettext(rec.class.to_s, :type=>:model)}]")
    self.send(method.to_sym, self, rec, inputs)
  end

  def action_prevent(action, rec, inputs)
    #    MiqPolicy.logger.warn("MIQ(action_prevent): Invoking action [prevent] for policy: [#{inputs[:policy].description}], event: [#{inputs[:event].description}], entity name: [#{rec.name}], entity type: [#{Dictionary.gettext(rec.class.to_s, :type=>:model)}]")
    raise MiqException::PolicyPreventAction, "preventing current process from proceeding due to policy failure"
  end

  def action_log(action, rec, inputs)
    if inputs[:result]
      MiqPolicy.logger.info("MIQ(action-log): Policy success: policy: [#{inputs[:policy].description}], event: [#{inputs[:event].description}], entity name: [#{rec.name}], entity type: [#{Dictionary.gettext(rec.class.to_s, :type=>:model)}]")
    else
      MiqPolicy.logger.warn("MIQ(action-log): Policy failure: policy: [#{inputs[:policy].description}], event: [#{inputs[:event].description}], entity name: [#{rec.name}], entity type: [#{Dictionary.gettext(rec.class.to_s, :type=>:model)}]")
    end
  end

  def action_audit(action, rec, inputs)
    msg = inputs[:result] ? "success" : "failure"
    AuditEvent.send(msg,
      :event => inputs[:event].name,
      :target_id => rec.id,
      :target_class => rec.class.base_class.name,
      :message => "Policy #{msg}: policy: [#{inputs[:policy].description}], event: [#{inputs[:event].description}]")
  end

  def action_snmp_trap(action, rec, inputs)
    # Validate SNMP Version
    snmp_version = action.options[:snmp_version]
    snmp_version = 2 if action.options[:snmp_version] == "v2"
    snmp_version = 1 if action.options[:snmp_version] == "v1"
    snmp_version = 1 unless [1,2].include?(snmp_version)
    method_name = "trap_v#{snmp_version}"

    snmp_inputs = {}
    snmp_inputs[:host] = action.options[:host]
    trap_id_key = (snmp_version == 1) ? :specific_trap : :trap_oid
    snmp_inputs[trap_id_key]  = action.options[:trap_id]

    vars = []
    action.options[:variables].each { |h|
      value = h[:value]

      value = value.gsub(RE_SUBST) { |s|
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
            subst = "#{rec.class}"
          elsif method == "ems" && rec.respond_to?(:ext_management_system)
            ems = rec.ext_management_system
            subst = "vCenter #{ems.hostname}/#{ems.ipaddress}" unless ems.nil?
          elsif rec.respond_to?(method)
            subst = rec.send(method)
          end
        end

        subst
      } unless value.nil?

      h[:value] = value
      vars << h
    } unless action.options[:variables].nil?

    snmp_inputs[:object_list] = vars

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_snmp_trap): Now executing SNMP Trap [#{rec[:name]}]")
      MiqSnmp.send(method_name, snmp_inputs)
    else
      MiqPolicy.logger.info("MIQ(action_snmp_trap): Queueing SNMP Trap [#{rec[:name]}]")
      MiqQueue.put(
        :class_name  => "MiqSnmp",
        :method_name => method_name,
        :args        => [snmp_inputs],
        :role        => "notifier",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => nil
      )
    end

  end

  def action_email(action, rec, inputs)
    smtp = VMDB::Config.new("vmdb").config[:smtp]

    action.options[:from] = smtp[:from] if action.options[:from].blank?

    email_options = {
      :to => action.options[:to],
      :from => action.options[:from],
    }
    if inputs[:policy].kind_of?(MiqPolicy)
      presult = inputs[:result] ? "Succeeded" : "Failed"
      email_options[:subject] = "Policy #{presult}: #{inputs[:policy].description}, for (#{rec.class.to_s.upcase}) #{rec.name}"
      email_options[:miq_action_hash] = {
        :header => inputs[:result] ? "Policy Succeeded" : "Policy Failed",
        :policy_detail =>"Policy '#{inputs[:policy].description}', #{presult}",
        :event_description => inputs[:event].description,
        :entity_type => rec.class.to_s,
        :entity_name => rec.name
      }
    elsif inputs[:policy].kind_of?(MiqAlert)
      email_options[:subject] = "Alert Triggered: #{inputs[:policy].description}, for (#{rec.class.to_s.upcase}) #{rec.name}"
      email_options[:miq_action_hash] = {
        :header => "Alert Triggered",
        :policy_detail => "Alert '#{inputs[:policy].description}', triggered",
        :event_description => inputs[:event].description,
        :entity_type => rec.class.to_s,
        :entity_name => rec.name
      }
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_email): Now executing Email [#{rec[:name]}]")
      MiqAction.send("queue_email", email_options)
    else
      MiqPolicy.logger.info("MIQ(action_email): Queueing Email [#{rec[:name]}]")
      MiqQueue.put(
        :class_name  => "MiqAction",
        :method_name => "queue_email",
        :args        => [email_options],
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "notifier",
        :zone        => nil
      )
    end
  end

  def self.queue_email(options)
    begin
      GenericMailer.deliver_queue(:policy_action_email, options)
    rescue Exception => err
      MiqPolicy.logger.log_backtrace(err)
    end
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

    EmsEvent.create(opts)
  end

  def action_compliance_failed(action, rec, inputs)
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

  def action_tag(action, rec, inputs)
    get_policies_from = inputs[:get_policies_from]
    MiqPolicy.logger.info("MIQ(action_tag): Applying tags [#{action.options[:tags].inspect}] to [(#{rec.class}) #{rec.name}]")
    action.options[:tags].each {|t| Classification.classify_by_tag(rec, t)}
  end

  def action_tag_inherit(action, rec, inputs)
    get_policies_from = inputs[:get_policies_from]
    MiqPolicy.logger.info("MIQ(action_tag_inherit): Applying tags from [(#{get_policies_from.class}) #{get_policies_from.name}] to [(#{rec.class}) #{rec.name}]")
    tags = get_policies_from.tag_list(:ns=>"/managed").split
    tags.delete_if {|t| t =~ /^power_state/} # omit power state since this is assigned by the system

    tags.each {|t| Classification.classify_by_tag(rec, File.join("/managed", t))}
  end

  def action_inherit_parent_tags(action, rec, inputs)
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
      rec.tag_with("", :ns=>"/managed/#{cat}")
    end
    rec.reload

    Classification.get_tags_from_object(parent).each do |t|
      cat, ent = t.split("/")
      next unless options[:cats].include?(cat)

      MiqPolicy.logger.info("MIQ(action_inherit_parent_tags): Applying tag [#{t}] from [(#{parent.class}) #{parent.name}] to [(#{rec.class}) #{rec.name}]")
      Classification.classify_by_tag(rec, "/managed/#{t}", false)
    end
  end

  def action_remove_tags(action, rec, inputs)
    # options = {
    #   :cats        => [array of categories]
    # }
    Classification.get_tags_from_object(rec).each do |t|
      cat, ent = t.split("/")
      next unless options[:cats].include?(cat)

      MiqPolicy.logger.info("MIQ(action_remove_tags): Removing tag [#{t}] from [(#{rec.class}) #{rec.name}]")
      Classification.unclassify_by_tag(rec, "/managed/#{t}", false)
    end
  end

  def self.inheritable_cats
    Classification.in_my_region.categories.inject([]) do |arr,c|
      next(arr) if c.name.starts_with?("folder_path_")
      next(arr) if c.entries.size == 0
      arr << c
    end
  end

  def run_script(rec)
    filename = self.options[:filename]
    raise "unable to execute script, no file name specified" if filename.nil?
    raise "unable to execute script, file name [#{filename} does not exist]" unless File.exist?(filename)

    fd    = Tempfile.new("miq_action", SCRIPT_DIR)
    fname = fd.path
    fd.puts((File.extname(filename) == ".rb") ? RB_PREAMBLE : SH_PREAMBLE)
    fd.puts(File.read(filename))
    fd.close

    File.chmod(0755, fname)

    MiqPolicy.logger.info("MIQ(action_script): Executing: [#{filename}]")
    if File.extname(filename) == ".rb"
      rails_cmd = MiqEnvironment::Command.rails_command
      MiqPolicy.logger.info("MIQ(action_script): Eval:      [#{rails_cmd} runner #{fname} '#{rec.name}'}]")
      result, _, status = Open3.capture3(rails_cmd, "runner", fname, "'#{rec.name}'")
    else
      MiqPolicy.logger.info("MIQ(action_script): Eval:      [#{fname}]")
      result, _, status = Open3.capture3(fname)
    end
    rc = status.exitstatus
    rc_verbose = RC_HASH[rc] || "Unknown RC: [#{rc}]"

    fd.delete

    MiqPolicy.logger.info("MIQ(action_script): Result:\n#{result}")

    case rc
    when 0
      MiqPolicy.logger.info("MIQ(action_script): Result: #{result}, rc: #{rc_verbose}")
    when 4
      MiqPolicy.logger.warn("MIQ(action_script): Result: #{result}, rc: #{rc_verbose}")
    when 8
      raise MiqException::StopAction, "Action script exited with rc=#{rc_verbose}"
    when 16
      raise MiqException::AbortAction, "Action script exited with rc=#{rc_verbose}"
    else
      raise MiqException::UnknownActionRc, "Action script exited with rc=#{rc_verbose}"
    end
  end

  def action_script(action, rec, inputs)
    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_script): Now executing Action Script [#{rec[:name]}]")
      action.send("run_script", rec)
    else
      MiqPolicy.logger.info("MIQ(action_script): Queueing Action Script [#{rec[:name]}]")
      MiqQueue.put(:class_name => "MiqAction",
        :method_name => "run_script",
        :priority => MiqQueue::HIGH_PRIORITY,
        :args => [rec],
        :instance_id => action.id
      )
    end
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

  VM_ACTIONS_WITH_NO_ARGS.each { |action_method, vm_method|
    define_method(action_method) { |action, rec, inputs|
      unless rec.is_a?(VmOrTemplate)
        MiqPolicy.logger.error("MIQ(#{action_method}): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
        return
      end

      if inputs[:synchronous]
        MiqPolicy.logger.info("MIQ(#{action_method}): Now executing [#{action.description}] of VM [#{rec.name}]")
        rec.send(vm_method)
      else
        role = vm_method == "scan" ? "smartstate" : "ems_operations"
        MiqPolicy.logger.info("MIQ(#{action_method}): Queueing [#{action.description}] of VM [#{rec.name}]")
        MiqQueue.put(
          :class_name  => rec.class.name,
          :method_name => vm_method,
          :instance_id => rec.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :zone        => rec.my_zone,
          :role        => role
        )
      end
    }
  }

  def action_vm_mark_as_vm(action, rec, inputs)
    unless rec.is_a?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_vm_mark_as_vm): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_vm_mark_as_vm): Now executing [#{action.description}] of VM [#{rec.name}]")
      rec.mark_as_vm(action.options[:pool], action.options[:host])
    else
      MiqPolicy.logger.info("MIQ(action_vm_mark_as_vm): Queueing [#{action.description}] of VM [#{rec.name}]")
      MiqQueue.put(
        :class_name  => rec.class.name,
        :method_name => "mark_as_vm",
        :args        => [action.options[:pool], action.options[:host]],
        :instance_id => rec.id,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => rec.my_zone,
        :role        => "ems_operations"
      )
    end
  end

  def action_vm_migrate(action, rec, inputs)
    unless rec.is_a?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_vm_migrate): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_vm_migrate): Now executing [#{action.description}] of VM [#{rec.name}]")
      rec.send("migrate", action.options[:host], action.options[:pool], action.options[:priority], action.options[:state])
    else
      MiqPolicy.logger.info("MIQ(action_vm_migrate): Queueing [#{action.description}] of VM [#{rec.name}]")
      MiqQueue.put(
        :class_name  => rec.class.name,
        :method_name => "migrate",
        :args        => [action.options[:host], action.options[:pool], action.options[:priority], action.options[:state]],
        :instance_id => rec.id,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => rec.my_zone,
        :role        => "ems_operations"
      )
    end
  end

  def action_vm_clone(action, rec, inputs)
    unless rec.is_a?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_vm_clone): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_vm_clone): Now executing [#{action.description}] of VM [#{rec.name}]")
      rec.send("clone", action.options[:name], action.options[:folder], action.options[:pool], action.options[:host], action.options[:datastore], action.options[:powerOn], action.options[:template], action.options[:transform], action.options[:config], action.options[:customization], action.options[:disk])
    else
      MiqPolicy.logger.info("MIQ(action_vm_clone): Queueing [#{action.description}] of VM [#{rec.name}]")
      MiqQueue.put(
        :class_name  => rec.class.name,
        :method_name => "clone",
        :args        => [action.options[:name], action.options[:folder], action.options[:pool], action.options[:host], action.options[:datastore], action.options[:powerOn], action.options[:template], action.options[:transform], action.options[:config], action.options[:customization], action.options[:disk]],
        :instance_id => rec.id,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => rec.my_zone,
        :role        => "ems_operations"
      )
    end
  end

  # Legacy: Replaces by action_vm_analyze
  def action_vm_scan(action, rec, inputs)
    action_vm_analyze(action, rec, inputs)
  end

  def action_vm_retire(action, rec, inputs)
    unless rec.is_a?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_vm_retire): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_vm_retire): Now executing VM Retire for VM [#{rec.name}]")
      VmOrTemplate.retire([rec], :date => Time.now.utc - 1.day)
    else
      MiqPolicy.logger.info("MIQ(action_vm_retire): Queueing VM Retire for VM [#{rec.name}]")
      MiqQueue.put(
        :class_name  => rec.class.name,
        :method_name => "retire",
        :args        => [[rec], :date => Time.now.utc - 1.day],
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => rec.my_zone
      )
    end
  end

  def action_create_snapshot(action, rec, inputs)
    unless rec.is_a?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_create_snapshot): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end
    action.options[:description] ||= "Created by EVM Policy Action"

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_create_snapshot): Now executing Create Snapshot [#{action.options[:name]}] for VM [#{rec.name}]")
      rec.send("create_snapshot", action.options[:name], action.options[:description])
    else
      MiqPolicy.logger.info("MIQ(action_create_snapshot): Queueing Create Snapshot [#{action.options[:name]}] for VM [#{rec.name}]")
      MiqQueue.put(
        :class_name  => rec.class.name,
        :method_name => "create_snapshot",
        :args        => [action.options[:name], action.options[:description]],
        :instance_id => rec.id,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => rec.my_zone,
        :role        => "ems_operations"
      )
    end
  end

  def action_delete_snapshots_by_age(action, rec, inputs)
    log_prefix = "MIQ(action_delete_snapshots_by_age):"
    unless rec.is_a?(VmOrTemplate)
      MiqPolicy.logger.error("#{log_prefix} Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end
    log_prefix += " VM: [#{rec.name}] Id: [#{rec.id}]"

    age_threshold = (Time.now.utc - action.options[:age])
    has_ch = false
    snaps_to_delete = rec.snapshots.each_with_object([]) do |s,arr|
      has_ch = true if s.is_a_type?(:consolidate_helper)
      next          if s.is_a_type?(:evm_snapshot)
      next          if s.is_a_type?(:vcb_snapshot)

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
    snaps_to_delete.sort {|a,b| b.create_time <=> a.create_time}.each do |s| # Delete newest to oldest
      MiqPolicy.logger.info("#{log_prefix} Deleting Snapshot: Name: [#{s.name}] Id: [#{s.id}] Create Time: [#{s.create_time}]")
      rec.remove_snapshot_queue(s.id, task_id)
    end
  end

  def action_delete_most_recent_snapshot(action, rec, inputs)
    log_prefix = "MIQ(action_delete_most_recent_snapshot):"
    unless rec.is_a?(VmOrTemplate)
      MiqPolicy.logger.error("#{log_prefix} Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end
    log_prefix += " VM: [#{rec.name}] Id: [#{rec.id}]"

    has_ch = false
    snap   = nil
    rec.snapshots.all(:order => "create_time DESC").each do |s|
      if s.is_a_type?(:consolidate_helper)
        has_ch = true
        next
      end
      next if s.is_a_type?(:evm_snapshot)
      next if s.is_a_type?(:vcb_snapshot)

      snap ||= s #Take the first eligable snapshot
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
    unless rec.is_a?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_reconfigure_memory): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end

    unless action.options[:value]
      MiqPolicy.logger.error("MIQ(action_reconfigure_memory): Unable to perform action [#{action.description}], object [#{rec.inspect}] no memory value given")
      return
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_reconfigure_memory): Now executing [#{action.description}] for VM [#{rec.name}], Memory value: [#{action.options[:value]}]")
      rec.set_memory(action.options[:value])
    else
      MiqPolicy.logger.info("MIQ(action_reconfigure_memory): Queueing [#{action.description}] for VM [#{rec.name}], Memory value: [#{action.options[:value]}]")
      MiqQueue.put(
        :class_name  => rec.class.name,
        :method_name => "set_memory",
        :args        => [action.options[:value]],
        :instance_id => rec.id,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => rec.my_zone,
        :role        => "ems_operations"
      )
    end
  end

  def action_reconfigure_cpus(action, rec, inputs)
    unless rec.is_a?(VmOrTemplate)
      MiqPolicy.logger.error("MIQ(action_reconfigure_cpus): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM")
      return
    end

    unless action.options[:value]
      MiqPolicy.logger.error("MIQ(action_reconfigure_cpus): Unable to perform action [#{action.description}], object [#{rec.inspect}] no cpu value given")
      return
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_reconfigure_cpus): Now executing Reconfigure CPUs for VM [#{rec.name}], CPUs value: [#{action.options[:value]}]")
      rec.set_number_of_cpus(action.options[:value])
    else
      MiqPolicy.logger.info("MIQ(action_reconfigure_cpus): Queueing Reconfigure CPUs for VM [#{rec.name}], CPUs value: [#{action.options[:value]}]")
      MiqQueue.put(
        :class_name  => rec.class.name,
        :method_name => "set_number_of_cpus",
        :args        => [action.options[:value]],
        :instance_id => rec.id,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => rec.my_zone,
        :role        => "ems_operations"
      )
    end
  end

  def action_ems_refresh(action, rec, inputs)
    unless rec.respond_to?(:ext_management_system) && !rec.ext_management_system.nil?
      MiqPolicy.logger.error("MIQ(action_ems_refresh): Unable to perform action [#{action.description}], object [#{rec.inspect}] does not have a #{ui_lookup(:table=>"ext_management_systems")}")
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

  def action_host_analyze(action, rec, inputs)
    action_method = "action_host_analyze"
    if inputs[:event].name == "request_host_scan"
      MiqPolicy.logger.warn("MIQ(#{action_method}): Invoking action [#{action.description}] for event [#{inputs[:event].description}] would cause infinite loop, skipping")
      return
    end

    unless rec.is_a?(Host)
      MiqPolicy.logger.error("MIQ(#{action_method}): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a Host")
      return
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(#{action_method}): Now executing [#{action.description}] of Host [#{rec.name}]")
      rec.send(:scan)
    else
      role = "smartstate"
      MiqPolicy.logger.info("MIQ(#{action_method}): Queueing [#{action.description}] of Host [#{rec.name}]")
      MiqQueue.put(
      :class_name  => "Host",
      :method_name => "scan_from_queue",
      :instance_id => rec.id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :zone        => rec.my_zone,
      :role        => role
      )
    end
  end

  def action_cancel_task(action, rec, inputs)
    unless rec.respond_to?(:ext_management_system) && !rec.ext_management_system.nil?
      MiqPolicy.logger.error("MIQ(action_cancel_task): Unable to perform action [#{action.description}], object [#{rec.inspect}] does not have a #{ui_lookup(:table=>"ext_management_systems")}")
      return
    end

    task_mor = inputs[:ems_event].full_data['info']['task']
    unless task_mor
      MiqPolicy.logger.warn("MIQ(action_cancel_task): Event record does not have a task reference, no action will be taken")
      return
    end

    MiqPolicy.logger.info("MIQ(action_cancel_task): Now executing Cancel of task [#{inputs[:ems_event].event_type}] on VM [#{inputs[:ems_event].vm_name}]")
    ems = ExtManagementSystem.find_by_id(inputs[:ems_event].ems_id)
    raise "unable to find vCenter with id [#{inputs[:ems_event].ems_id}]" if ems.nil?

    vim = ems.connect
    vim.cancelTask(task_mor)
  end

  def action_custom_automation(action, rec, inputs)
    ae_hash = action.options[:ae_hash] || {}
    automate_attrs = ae_hash.reject { |key, value| MiqAeEngine::DEFAULT_ATTRIBUTES.include?(key) }
    automate_attrs[MiqAeEngine.create_automation_attribute_key(inputs[:policy])]    = MiqAeEngine.create_automation_attribute_value(inputs[:policy]) unless inputs[:policy].nil?
    automate_attrs[MiqAeEngine.create_automation_attribute_key(inputs[:ems_event])] = MiqAeEngine.create_automation_attribute_value(inputs[:ems_event]) unless inputs[:ems_event].nil?
    automate_attrs[:request] = action.options[:ae_request]

    args = {}
    args[:object_type]      = rec.class.base_class.name
    args[:object_id]        = rec.id
    args[:attrs]            = automate_attrs
    args[:instance_name]    = "REQUEST"
    args[:automate_message] = action.options[:ae_message] || "create"

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_custom_automation): Now executing MiqAeEngine.deliver for #{automate_attrs[:request]} with args=#{args.inspect}")
      MiqAeEngine.deliver(args)
    else
      MiqPolicy.logger.info("MIQ(action_custom_automation): Queuing MiqAeEngine.deliver for #{automate_attrs[:request]} with args=#{args.inspect}")
      MiqQueue.put(
        :class_name  => 'MiqAeEngine',
        :method_name => 'deliver',
        :args        => [args],
        :role        => 'automate',
        :zone        => nil,
        :priority    => MiqQueue::HIGH_PRIORITY,
      )
    end
  end

  def action_raise_automation_event(action, rec, inputs)
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

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_raise_automation_event): Now executing Raise Automation Event, Event: [#{event}]")
      MiqAeEvent.raise_synthetic_event(event, aevent)
    else
      MiqPolicy.logger.info("MIQ(action_raise_automation_event): Queuing Raise Automation Event, Event: [#{event}]")
      MiqQueue.put(
        :class_name  => "MiqAeEvent",
        :method_name => "raise_synthetic_event",
        :args        => [event, aevent],
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => rec.my_zone,
        :role        => "automate"
      )
    end
  end

  def action_evaluate_alerts(action, rec, inputs)
    action.options[:alert_guids].each do |guid|
      alert = MiqAlert.find_by_guid(guid)
      unless alert
        MiqPolicy.logger.warn("MIQ(action_evaluate_alert): Unable to perform action [#{action.description}], unable to find alert: [#{action.options[:alert_guid]}]")
        next
      end

     if inputs[:synchronous]
        MiqPolicy.logger.info("MIQ(action_evaluate_alert): Now executing Evaluate Alert, Alert: [#{alert.description}]")
        alert.evaluate(rec, inputs)
      else
        MiqPolicy.logger.info("MIQ(action_evaluate_alert): Queuing Evaluate Alert, Alert: [#{alert.description}]")
        MiqQueue.put(
          :class_name  => "MiqAlert",
          :instance_id => alert.id,
          :method_name => "evaluate",
          :args        => [rec, inputs],
          :priority    => MiqQueue::HIGH_PRIORITY,
          :zone        => rec.my_zone
        )
      end
    end
  end

  def action_assign_scan_profile(action, rec, inputs)
    ScanItem  # Cause the ScanItemSet class to load, if not already loaded
    profile = ScanItemSet.find_by_name(action.options[:scan_item_set_name])
    unless profile
      MiqPolicy.logger.warn("MIQ(action_assign_scan_profile): Unable to perform action [#{action.description}], unable to find analysis profile: [#{action.options[:scan_item_set_name]}]")
      return
    else
      MiqPolicy.logger.info("MIQ(action_assign_scan_profile): Action [#{action.description}], using analysis profile: [#{profile.description}]")
      return ScanItem.get_profile(profile.name)
    end
  end

  def action_set_custom_attribute(action, rec, inputs)
    unless rec.is_a?(VmOrTemplate) || rec.is_a?(Host)
      MiqPolicy.logger.error("MIQ(action_set_custom_attribute): Unable to perform action [#{action.description}], object [#{rec.inspect}] is not a VM or a Host")
      return
    end

    if inputs[:synchronous]
      MiqPolicy.logger.info("MIQ(action_set_custom_attribute): Now executing #{action.description} [#{action.options[:attribute]}] for VM [#{rec.name}]")
      rec.set_custom_field(action.options[:attribute], action.options[:value])
    else
      MiqPolicy.logger.info("MIQ(action_set_custom_attribute): Queueing #{action.description} [#{action.options[:attribute]}] for VM [#{rec.name}]")
      MiqQueue.put(
        :class_name  => rec.class.name,
        :method_name => "set_custom_field",
        :args        => [action.options[:attribute], action.options[:value]],
        :instance_id => rec.id,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => rec.my_zone,
        :role        => "ems_operations"
      )
    end
  end

  def export_to_array
    h = self.attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    return [ self.class.to_s => h ]
  end

  def self.import_from_hash(action, options={})
    status = {:class => self.name, :description => action["description"]}
    a = MiqAction.find_by_description(action["description"])
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
    unless options[:preview] == true
      MiqPolicy.logger.info(msg)
      a.save!
    else
      MiqPolicy.logger.info("[PREVIEW] #{msg}")
    end

    return a, status
  end

  def self.create_script_actions_from_directory
    Dir.glob(SCRIPT_DIR + "/*").sort.each do |f|
      rec = {}
      rec[:name]        = File.basename(f).gsub(".", "_")
      rec[:description] = "Execute script: #{File.basename(f)}"
      rec[:action_type] = "script"
      rec[:options]     = {:filename => f}

      action = self.find_by_name(rec[:name])
      if action.nil?
        $log.info("MIQ(MiqAction.create_script_actions_from_directory) Creating [#{rec[:name]}]")
        action = self.create(rec)
      else
        action.attributes = rec
        if action.changed? || action.options_was != actions.options
          $log.info("MIQ(MiqAction.create_script_actions_from_directory) Updating [#{rec[:name]}]")
          action.save
        end
      end
    end
  end

  def check_policy_contents_empty_on_destroy
    raise "Action is referenced in at least one policy and connot be deleted" unless self.miq_policy_contents.empty?
  end

  def round_if_memory_reconfigured
    # round memory value to the nearest 4mb
    self.options[:value] = round_to_nearest_4mb(self.options[:value]) if self.action_type == "reconfigure_memory"
  end

  def round_to_nearest_4mb(num)
    num = num.to_i
    mod = num.modulo(4)
    unless mod == 0
      pad = 4 - mod
      num += pad
    end
    num
  end

  def self.seed
    MiqRegion.my_region.lock do
      self.create_default_actions
      self.create_script_actions_from_directory
    end
  end

  def self.create_default_actions
    fname = File.join(FIXTURE_DIR, "#{self.to_s.pluralize.underscore}.csv")
    data  = File.read(fname).split("\n")
    cols  = data.shift.split(",")

    data.each do |a|
      next if a =~ /^#.*$/ # skip commented lines

      arr = a.split(",")

      action = {}
      cols.each_index {|i| action[cols[i].to_sym] = arr[i]}

      rec = self.find_by_name(action[:name])
      if rec.nil?
        $log.info("MIQ(MiqAction.create_default_actions) Creating [#{action[:name]}]")
        rec = self.create(action.merge(:action_type => "default"))
      else
        rec.attributes = action.merge(:action_type => "default")
        if rec.changed? || (rec.options_was != rec.options)
          $log.info("MIQ(MiqAction.create_default_actions) Updating [#{action[:name]}]")
          rec.save
        end
      end
    end
  end
end
