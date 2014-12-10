module EmsRefresh::Refreshers
  class BaseRefresher
    DEBUG_TRACE = false

    attr_accessor :ems_by_ems_id, :targets_by_ems_id

    def self.refresh(targets)
      self.new(targets).refresh
    end

    def initialize(targets)
      group_targets_by_ems(targets)
    end

    def options
      return @options if defined?(@options)
      @options = VMDB::Config.new("vmdb").config[:ems_refresh]
    end

    def refresher_options
      options[self.class.ems_type]
    end

    private

    def self.ems_type
      # e.g. EmsRefresh::Refreshers::VcRefresher => :vc
      @ems_type ||= self.name.split("::").last.underscore.split("_").first.to_sym
    end

    def group_targets_by_ems(targets)
      non_ems_targets = targets.select { |t| !t.kind_of?(ExtManagementSystem) }
      ActiveRecord::Associations::Preloader.new(non_ems_targets, :ext_management_system).run

      self.ems_by_ems_id     = {}
      self.targets_by_ems_id = Hash.new { |h, k| h[k] = Array.new }

      targets.each do |t|
        ems = t.kind_of?(ExtManagementSystem) ? t : t.ext_management_system
        if ems.nil?
          $log.warn "MIQ(#{self.class.name}.group_targets_by_ems) Unable to perform refresh for #{t.class} [#{t.name}] id [#{t.id}], since it is not on an EMS."
          next
        end

        self.ems_by_ems_id[ems.id] ||= ems
        self.targets_by_ems_id[ems.id] << t
      end
    end

    def refresher_type
      # "EmsRefresh::Refreshers::Ec2Refresher" => "Ec2Refresher" => "Ec2"
      self.class.name.demodulize.sub(/Refresher$/, '')
    end
  end
end
