module PerEmsWorkerMixin
  include MiqWorker::DeploymentPerWorker

  extend ActiveSupport::Concern

  included do
    class_eval do
      self.workers = -> { desired_queue_names.length }
    end
  end

  module ClassMethods
    def desired_queue_names
      all_valid_ems_in_zone.collect { |e| queue_name_for_ems(e) }
    end

    def sync_workers
      ws      = find_current_or_starting
      current = ws.collect(&:queue_name).sort
      desired = has_required_role? ? desired_queue_names.sort : []
      result  = {:adds => [], :deletes => []}

      unless compare_queues(current, desired)
        _log.info("Workers are being synchronized: Current: #{current.inspect}, Desired: #{desired.inspect}")

        dups = current.uniq.find_all { |u| current.find_all { |c| c == u }.length > 1 }
        _log.info("Duplicate workers found: Current: #{current.inspect}, Desired: #{desired.inspect}, Dups: #{dups.inspect}") unless dups.empty?
        current -= dups

        dups.each { |d| result[:deletes] << stop_worker_for_ems(d) }

        if desired.length > current.length && enough_resource_to_start_worker?
          (desired - current).each do |x|
            w = start_worker_for_ems(x)
            result[:adds] << w.pid unless w.nil?
          end
        elsif desired.length < current.length
          (current - desired).each do |x|
            result[:deletes] << stop_worker_for_ems(x)
          end
        end
      end

      result
    end

    def start_workers
      return unless has_required_role?

      all_valid_ems_in_zone.each do |ems|
        start_worker_for_ems(ems)
      end
    end

    def start_worker_for_ems(ems_or_queue_name)
      params = {:queue_name => queue_name_for_ems(ems_or_queue_name)}
      start_worker(params)
    end

    def stop_worker_for_ems(ems_or_queue_name)
      wpid = nil
      lookup_by_queue_name(queue_name_for_ems(ems_or_queue_name).to_s).each do |w|
        next unless w.status == MiqWorker::STATUS_STARTED

        wpid = w.pid
        w.stop
      end
      wpid
    end

    def restart_worker_for_ems(ems)
      stop_worker_for_ems(ems)
      start_worker_for_ems(ems)
    end

    def lookup_by_ems(ems)
      lookup_by_queue_name(queue_name_for_ems(ems))
    end

    alias find_by_ems lookup_by_ems
    Vmdb::Deprecation.deprecate_methods(self, :find_by_ems => :lookup_by_ems)

    def lookup_by_queue_name(queue_name)
      server_scope.where(:queue_name => queue_name).order("started_on DESC")
    end

    def queue_name_for_ems(ems)
      return ems unless ems.kind_of?(ExtManagementSystem)

      ems.queue_name
    end

    def parse_ems_id(queue_name)
      return nil if queue_name.blank?

      name, id = queue_name.split("_")
      return nil unless name == "ems"

      id.to_i
    end

    def ems_id_from_queue_name(queue_name)
      parse_ems_id(queue_name)
    end

    def ems_from_queue_name(queue_name)
      ExtManagementSystem.find_by(:id => ems_id_from_queue_name(queue_name))
    end

    private

    def compare_queues(current, desired)
      current.flatten.sort == desired.flatten.sort
    end
  end

  def ems_id
    self.class.ems_id_from_queue_name(queue_name)
  end

  def ext_management_system
    self.class.ems_from_queue_name(queue_name)
  end

  def worker_options
    super.merge(:ems_id => ems_id)
  end

  def environment_variables
    super.merge("EMS_ID" => ems_id.to_s)
  end
end
