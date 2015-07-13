class Compliance < ActiveRecord::Base
  belongs_to  :resource,  :polymorphic => true
  has_many    :compliance_details, :dependent => :destroy

  include ReportableMixin

  def self.check_compliance_queue(targets, inputs = {})
    targets.to_miq_a.each do |target|
      MiqQueue.put(
        :class_name  => self.name,
        :method_name => 'check_compliance',
        :args        => [[target.class.name, target.id], inputs]
      )
    end
  end

  def self.scan_and_check_compliance_queue(targets, inputs = {})
    targets.to_miq_a.each do |target|
      if target.kind_of?(Host)
        # Queue this with the vc-refresher taskid, so that any concurrent ems_refreshes don't clash with this one.
        MiqQueue.put(
          :class_name  => self.name,
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
      target = klass.find_by_id(id)
      raise "Unable to find object with class: [#{klass}], Id: [#{id}]" unless target
    end

    raise "Scan and Compliance check not supported for #{target.class.name} objects" unless target.kind_of?(Host)

    log_target = "#{target.class.name} name: [#{target.name}], id: [#{target.id}]"
    _log.info("Requesting scan of #{log_target}")
    begin
      MiqEvent.raise_evm_job_event(target, :type => "scan", :prefix => "request")
    rescue => err
      _log.error("Error raising request scan event for #{log_target}: #{err.message}")
      return
    end

    target.scan_from_queue
    Compliance.check_compliance(target, inputs)
  end

  def self.check_compliance(target, inputs = {})
    if target.kind_of?(Array)
      klass, id = target
      klass = Object.const_get(klass)
      target = klass.find_by_id(id)
      raise "Unable to find object with class: [#{klass}], Id: [#{id}]" unless target
    end
    target_class = target.class.base_model.name.downcase

    raise "Compliance check not supported for #{target.class.name} objects" unless target.respond_to?(:compliances)
    check_event = "#{target_class}_compliance_check"
    _log.info("Checking compliance...")
    results = MiqPolicy.enforce_policy(target, check_event)

    if results[:details].empty?
      _log.info("No compliance policies were assigned or in scope, compliance status will not be set")
      return
    end

    compliance_result = results[:actions].nil? ? true : !results[:actions].has_key?(:compliance_failed)
    self.set_compliancy(compliance_result, target, check_event, results[:details])

    # Raise EVM event for result asynchronously
    event = results[:result] ? "#{target_class}_compliance_passed" : "#{target_class}_compliance_failed"
    _log.info("Raising EVM Event: #{event}")
    MiqEvent.raise_evm_event_queue(target, event)
    #
    return results[:result]
  end

  def self.set_compliancy(compliant, target, event, details)
    name = target.respond_to?(:name) ? target.name : "NA"
    _log.info("Marking as #{compliant ? "" : "Non-"}Compliant Object with Class: [#{target.class}], Id: [#{target.id}], Name: [#{name}]")

    comp  = self.create(:resource => target, :compliant => compliant, :event_type => event, :timestamp => Time.now.utc)

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
end
