module ManageIQ
  module Providers
    class BaseManager::Refresher
      include Vmdb::Logging
      DEBUG_TRACE = false

      attr_accessor :ems_by_ems_id, :targets_by_ems_id

      def self.refresh(targets)
        new(targets).refresh
      end

      def initialize(targets)
        group_targets_by_ems(targets)
      end

      def options
        return @options if defined?(@options)
        @options = Settings.ems_refresh
      end

      def refresher_options
        options[self.class.ems_type]
      end

      private

      def self.ems_type
        @ems_type ||= parent.ems_type.to_sym
      end

      def group_targets_by_ems(targets)
        non_ems_targets = targets.select { |t| !t.kind_of?(ExtManagementSystem) && t.respond_to?(:ext_management_system) }
        MiqPreloader.preload(non_ems_targets, :ext_management_system)

        self.ems_by_ems_id     = {}
        self.targets_by_ems_id = Hash.new { |h, k| h[k] = [] }

        targets.each do |t|
          ems = case
                when t.respond_to?(:ext_management_system) then t.ext_management_system
                when t.respond_to?(:manager)               then t.manager
                else                                            t
                end
          if ems.nil?
            _log.warn "Unable to perform refresh for #{t.class} [#{t.name}] id [#{t.id}], since it is not on an EMS."
            next
          end

          ems_by_ems_id[ems.id] ||= ems
          targets_by_ems_id[ems.id] << t
        end
      end

      def refresher_type
        self.class.parent.short_token
      end
    end
  end
end
