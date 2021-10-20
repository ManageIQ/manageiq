class MiqWorkerType < ApplicationRecord
  KILL_PRIORITY_METRICS_PROCESSOR_WORKERS = 10
  KILL_PRIORITY_METRICS_COLLECTOR_WORKERS = 20
  KILL_PRIORITY_REPORTING_WORKERS         = 30
  KILL_PRIORITY_SMART_PROXY_WORKERS       = 40
  KILL_PRIORITY_GENERIC_WORKERS           = 50
  KILL_PRIORITY_EVENT_HANDLERS            = 60
  KILL_PRIORITY_REFRESH_WORKERS           = 70
  KILL_PRIORITY_SCHEDULE_WORKERS          = 80
  KILL_PRIORITY_PRIORITY_WORKERS          = 90
  KILL_PRIORITY_WEB_SERVICE_WORKERS       = 100
  KILL_PRIORITY_VIM_BROKER_WORKERS        = 110
  KILL_PRIORITY_EVENT_CATCHERS            = 120
  KILL_PRIORITY_UI_WORKERS                = 130
  KILL_PRIORITY_REMOTE_CONSOLE_WORKERS    = 140

  scope :in_kill_order, -> { order(:kill_priority => :asc) }

  def self.seed
    transaction do
      clean_worker_types
      classes_for_seed.each { |klass| seed_worker(klass) }
    end
  end

  def self.worker_class_names
    pluck(:worker_type)
  end

  def self.worker_classes
    worker_class_names.map(&:constantize)
  end

  def self.worker_class_names_in_kill_order
    in_kill_order.pluck(:worker_type)
  end

  def self.worker_classes_in_kill_order
    worker_class_names_in_kill_order.map(&:constantize)
  end

  private_class_method def self.classes_for_seed
    @classes_for_seed ||= MiqWorker.concrete_subclasses
  end

  private_class_method def self.seed_worker(klass)
    instance = find_or_initialize_by(:worker_type => klass.name)

    instance.update!(
      :bundler_groups => klass.bundler_groups,
      :kill_priority  => klass.kill_priority
    )
  end

  private_class_method def self.clean_worker_types
    where.not(:worker_type => classes_for_seed.map(&:to_s)).destroy_all
  end
end
