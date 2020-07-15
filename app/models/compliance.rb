class Compliance < ApplicationRecord
  include_concern 'Purging'
  belongs_to  :resource,  :polymorphic => true
  has_many    :compliance_details, :dependent => :destroy

  def self.check_compliance_queue(targets, inputs = {})
    Array.wrap(targets).each do |target|
      MiqQueue.submit_job(
        :class_name  => name,
        :method_name => 'check_compliance',
        :args        => [[target.class.name, target.id], inputs]
      )
    end
  end

  def self.scan_and_check_compliance_queue(targets, inputs = {})
    Array.wrap(targets).each do |target|
      if target.kind_of?(Host)
        # Queue this with the vc-refresher taskid, so that any concurrent ems_refreshes don't clash with this one.
        MiqQueue.put(
          :class_name  => name,
          :method_name => 'scan_and_check_compliance',
          :args        => [[target.class.name, target.id], inputs],
          :task_id     => 'vc-refresher',
          :role        => "ems_inventory",
          :zone        => target.ext_management_system.try(:my_zone)
        )
      end
    end
  end

  def self.scan_and_check_compliance(target, inputs = {})
    if target.kind_of?(Array)
      klass, id = target
      klass = Object.const_get(klass)
      target = klass.find_by(:id => id)
      unless target
        raise _("Unable to find object with class: [%{class_name}], Id: [%{number}]") % {:class_name => klass,
                                                                                         :number     => id}
      end
    end

    unless target.kind_of?(Host)
      raise _("Scan and Compliance check not supported for %{class_name} objects") % {:class_name => target.class.name}
    end

    _log.info("Requesting scan of #{target.log_target}")
    begin
      MiqEvent.raise_evm_job_event(target, :type => "scan", :prefix => "request")
    rescue => err
      _log.error("Error raising request scan event for #{target.log_target}: #{err.message}")
      return
    end

    target.scan_from_queue
    Compliance.check_compliance(target, inputs)
  end

  def self.check_compliance(target, _inputs = {})
    if target.kind_of?(Array)
      klass, id = target
      klass = Object.const_get(klass)
      target = klass.find_by(:id => id)
      unless target
        raise _("Unable to find object with class: [%{class_name}], Id: [%{number}]") % {:class_name => klass,
                                                                                         :number     => id}
      end
    end
    target_class = target.class.base_model.name.downcase
    target_class = "vm" if target_class.match("template")

    unless target.respond_to?(:compliances)
      raise _("Compliance check not supported for %{class_name} objects") % {:class_name => target.class.name}
    end
    check_event = "#{target_class}_compliance_check"
    _log.info("Checking compliance...")
    results = MiqPolicy.enforce_policy(target, check_event)

    if results[:details].empty?
      _log.info("No compliance policies were assigned or in scope, compliance status will not be set")
      return
    end

    compliance_result = results[:actions].nil? ? true : !results[:actions].key?(:compliance_failed)
    set_compliancy(compliance_result, target, check_event, results[:details])

    # Raise EVM event for result asynchronously
    event = results[:result] ? "#{target_class}_compliance_passed" : "#{target_class}_compliance_failed"
    _log.info("Raising EVM Event: #{event}")
    MiqEvent.raise_evm_event_queue(target, event)
    #
    results[:result]
  end

  def self.set_compliancy(compliant, target, event, details)
    name = target.respond_to?(:name) ? target.name : "NA"
    _log.info("Marking as #{compliant ? "" : "Non-"}Compliant Object with Class: [#{target.class}], Id: [#{target.id}], Name: [#{name}]")

    comp  = create(:resource => target, :compliant => compliant, :event_type => event, :timestamp => Time.now.utc)

    details.each do |p|
      dhash = {
        :miq_policy_id     => p["id"],
        :miq_policy_desc   => p["description"],
        :miq_policy_result => p["result"]
      }

      p["conditions"].each do |c|
        dhash[:condition_id]     = c["id"]
        dhash[:condition_desc]   = c["description"]
        dhash[:condition_result] = c["result"] == "allow"
        comp.compliance_details.create(dhash)
      end
    end
  end

  def self.display_name(number = 1)
    n_('Compliance History', 'Compliance Histories', number)
  end
end
