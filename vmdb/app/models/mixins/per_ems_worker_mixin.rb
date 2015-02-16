module PerEmsWorkerMixin
  extend ActiveSupport::Concern

  included do
    class_eval do
      self.check_for_minimal_role = false
      self.workers = lambda { self.desired_queue_names.length }

      alias_method_chain :command_line_params, :ems_id
    end
  end

  module ClassMethods
    def ems_class
      ExtManagementSystem
    end

    def all_ems_in_zone
      self.ems_class.where(:zone_id => MiqServer.my_server.zone.id).to_a
    end

    def all_valid_ems_in_zone
      self.all_ems_in_zone.select(&:authentication_status_ok?)
    end

    def desired_queue_names
      return [] if MiqServer.minimal_env? && !self.has_minimal_env_option?
      return self.all_valid_ems_in_zone.collect { |e| self.queue_name_for_ems(e) }
    end

    def sync_workers
      ws      = self.find_current_or_starting
      current = ws.collect(&:queue_name).sort
      desired = self.has_required_role? ? self.desired_queue_names.sort : []
      result  = { :adds => [], :deletes => [] }

      if current != desired
        $log.info("MIQ(#{self.name}.sync_workers) Workers are being synchronized: Current: #{current.inspect}, Desired: #{desired.inspect}")

        dups = current.uniq.find_all { |u| current.find_all {|c| c == u }.length > 1 }
        $log.info("MIQ(#{self.name}.sync_workers) Duplicate workers found: Current: #{current.inspect}, Desired: #{desired.inspect}, Dups: #{dups.inspect}") unless dups.empty?
        current = current - dups

        dups.each { |d| result[:deletes] << self.stop_worker_for_ems(d) }

        if desired.length > current.length && enough_resource_to_start_worker?
          (desired - current).each do |x|
            w = self.start_worker_for_ems(x)
            result[:adds] << w.pid unless w.nil?
          end
        elsif desired.length < current.length
          (current - desired).each do |x|
            result[:deletes] << self.stop_worker_for_ems(x)
          end
        end
      end

      return result
    end

    def start_workers
      return unless self.has_required_role?
      self.all_valid_ems_in_zone.each do |ems|
        self.start_worker_for_ems(ems)
      end
    end

    def start_worker_for_ems(ems_or_queue_name)
      params = {:queue_name => self.queue_name_for_ems(ems_or_queue_name)}
      self.start_worker(params)
    end

    def stop_worker_for_ems(ems_or_queue_name)
      wpid = nil
      self.find_by_queue_name(self.queue_name_for_ems(ems_or_queue_name)).each do |w|
        next unless w.status == MiqWorker::STATUS_STARTED
        wpid = w.pid
        w.stop
      end
      wpid
    end

    def restart_worker_for_ems(ems)
      self.stop_worker_for_ems(ems)
      self.start_worker_for_ems(ems)
    end

    def find_by_ems(ems)
      self.find_by_queue_name(self.queue_name_for_ems(ems))
    end

    def find_by_queue_name(queue_name)
      self.server_scope.where(:queue_name => queue_name).order("started_on DESC")
    end

    def queue_name_for_ems(ems)
      # Host objects do not have dedicated refresh workers so request a generic worker which will
      # be used to make a web-service call to a SmartProxy to initiate inventory collection.
      return "generic" if ems.kind_of?(Host) && ems.acts_as_ems?

      return ems unless ems.kind_of?(ExtManagementSystem)
      "ems_#{ems.id}"
    end

    def ems_id_from_queue_name(queue_name)
      return nil if queue_name.blank?
      name, id = queue_name.split("_")
      return nil unless name == "ems"
      return id.to_i
    end

    def ems_from_queue_name(queue_name)
      ExtManagementSystem.find_by_id(self.ems_id_from_queue_name(queue_name))
    end
  end

  def ems_id
    self.class.ems_id_from_queue_name(self.queue_name)
  end

  def ext_management_system
    self.class.ems_from_queue_name(self.queue_name)
  end

  def command_line_params_with_ems_id
    command_line_params_without_ems_id.merge(:ems_id => self.ems_id)
  end
end
