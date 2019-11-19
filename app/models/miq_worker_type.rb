class MiqWorkerType < ApplicationRecord
  EXCLUDED_CLASS_NAMES = %w[ManageIQ::Providers::BaseManager::OperationsWorker].freeze

  scope :in_kill_order, -> { order(:kill_priority => :asc) }

  def self.seed
    transaction do
      classes_for_seed.each { |klass| seed_worker(klass) }
    end
  end

  private_class_method def self.classes_for_seed
    MiqWorker.descendants.select { |w| w.subclasses.empty? } - EXCLUDED_CLASS_NAMES.map(&:constantize)
  end

  private_class_method def self.seed_worker(klass)
    instance = find_or_initialize_by(:worker_type => klass.name)

    instance.update!(
      :bundler_groups => klass.bundler_groups,
      :kill_priority  => klass.kill_priority
    )
  end
end
