# USAGE:
#
#   toggle_console_sql_logging
#   ManageIQ::DeepDelete.delete(ExtManagementSystem.find(2))
#
# currently only tested on ContainerManager / ems
module ManageIQ
  class DeepDelete
    include Vmdb::Logging
    # list of callbacks that we have reviewed and can safely ignore
    IGNORE_CALLBACKS = {
      # Storages#all_relationships(ems_metadata) - we're deleting all children anyway
      "Storages"            => 1,
      # EmsFolders#all_relationships(ems_metadata)
      "EmsFolders"          => 1,
      # EmsClusters#all_relationships(ems_metadata)
      "EmsClusters"         => 1,
      # ResourcePools#all_relationships(ems_metadata) - TODO: do we want ancestry here?
      "ResourcePools"       => 1,
      # MonitorManager => ExtManagementSystem
      "ExtManagementSystem" => 1,
      # ContainerManager#monitoring_manager (apply_orphan_strategy?)
      # MonitorManager#endpoints: endpoint_destroyed (using this/destroy_queue instead of dependent => destroy)
      # ContainerManager#persistent_volumes (?)
      # InfraManager#orchestration_templates (check_not_in_use (before destroy)
      # InfraManager#orchestration_stacks apply_orphan_strategy
      # BlacklistedEvent#reload_all_server_settings, BlacklistedEvent#audit_deletion
      "BlacklistedEvent"    => 2,
      # EventStream.after_commit :emit_notifications, :on => :create
      "EventStream"         => 1
      # VmOrTemplate#apply_orphan_strategy (/via ancesty - needed to destroy tree)
      # Relationship#apply_orphan_strategy (/via ancestry - needed to destroy tree)
      # Endpoint#endpoint_destroyed (using this/destroy_queue instead of dependent => destroy)
    }.freeze

    IGNORE_CONSTRAINTS = {
      # Hardware.disks is an order clause
      "Hardware.disks"                          => true,
      # MiqAlertStatus.miq_alert_status_actions is an order clause
      "MiqAlertStatus.miq_alert_status_actions" => true,
      # BinaryBlob.binary_blob_parts is an order clause
      "BinaryBlob.binary_blob_parts"            => true
    }.freeze

    # true to recurse into associations that have no values and would be skipped
    # Useful for developers to ensure all relationships could be reached
    attr_accessor :visit_skips

    def initialize(visit_skips: false)
      @visit_skips = visit_skips
    end

    # @param scope the record(s) to be destroyed - only a single child class/type can be passed in
    def self.delete(scope, **options)
      if scope.kind_of?(ActiveRecord::Base)
        # convert an individual record into a scope
        scope = scope.class.where(:id => scope.id)
      else
        # update scope.klass to a more specific class.
        # Ems child classes have additional relationships defined
        record = scope.first
        if record.nil?
          _log.error("DeepDelete found no records")
          return
        end
        scope = record.class.merge(scope)
      end

      name = scope.klass.name.split(":").last
      _, timing = Benchmark.realtime_block(:deep_delete) do
        new(**options).recursive_delete(scope, :name => name)
      end
      _log.info("Finished DeepDelete in #{timing[:deep_delete]} seconds")

      self
    end

    # @param scope [Relation] scope used to reach this relation
    # @param klass [Class] class for this relation (default to scope's klass)
    # @param name [String] name of this relation relative to the root node
    # @param mode [:delete_all, :destroy] what we are to do with this node
    #             If we are deleting this node, then we do not traverse into children to destroy them
    # @return [Numeric] number of outstanding callbacks (so others know not to delete this object)
    def recursive_delete(scope, klass = scope.klass, name: klass.name)
      _log.debug { "=> deep_delete #{name} begin" }
      # TODO: fetch distinct.pluck(:type).map(&:constantize).map { |k| refs_callbacks(k)} - to handle STI?
      #       current code does not require this but may be more future proof
      refs, callbacks = refs_callbacks(scope.klass)

      has_record = scope.exists?
      if has_record || visit_skips
        refs.each do |n, relation|
          rscope = rel_scope(klass, relation, scope)
          # rscope = select * from hardwares where host_id in (select id from hosts where ems_id in (select id from ems where id = 2))
          rname = "#{name}.#{n}"
          case relation.options[:dependent]
          when :destroy
            # If we recurse to self without ensuring a record exists, then this will be an infinite loop
            if has_record || relation.klass != scope.klass
              recursive_delete(rscope, :name => rname)
            end
          when :delete_all
            run(rname, "delete") { batch(rscope) { |subset| subset.delete_all } }
          when :nullify
            run(rname, "null") { rscope.update_all(relation.foreign_key => nil) } # rubocop:disable Rails/SkipsModelValidations
          else
            raise "unknown relation dependent option #{rname} :dependent => #{relation.options[:dependent]}"
          end
        end
      end

      if !has_record
        skip_run(name, callbacks ? "destroy" : "delete")
      elsif callbacks
        # issue - this works for after destroy, but may have problems with a before destroy hook
        #   they can reference children
        run(name, "destroy") { batch(scope) { |subset| subset.destroy_all.count } }
      else
        run(name, "delete") { batch(scope) { |subset| subset.delete_all } }
      end
      _log.debug { "/> deep_delete #{name}" }
    end

    private

    # @param scope starting table
    # @param relation foreign table (i.e.: relation = scope.klass.send(relation.name))
    def rel_scope(klass, relation, scope)
      # Hardware#disks MiqAlertStatus#miq_alert_status_action have order constraint - so are false positives
      # TODO: TEST harnes if there is a constraint, don't have dependent destroy
      if !relation.constraints.empty? && !IGNORE_CONSTRAINTS["#{scope.klass.name}.#{relation.name}"]
        _log.warn("CONSTRAINT: #{scope.klass.name}.#{relation.name} not handled")
      end

      # For a :through, point to the link record not the target record
      # ASIDE: chances are the :through relation also has a destroy, so this will be a no-op
      if relation.options[:through]
        _log.warn("RELATION: #{scope.klass.name}.#{relation.name} has a :through. move destroy to linking record")
        relation = klass.reflections[relation.options[:through].to_s]
      end

      relation.chain.reverse.inject(scope) do |sc, ar|
        ret = ar.klass.where(ar.join_primary_key => sc.select(ar.join_foreign_key))
        ar.type ? ret.where(ar.type => sc.klass.polymorphic_name) : ret
      end
    end

    # @param  klass [Class] class of model that has reflections
    # @return [Array<Reflection>, Boolean]
    def refs_callbacks(klass)
      dependent_refs = klass.reflections.select { |_, v| v.options[:dependent] }
      callback_count = klass._destroy_callbacks.count + klass._commit_callbacks.count
      ruby_callback_count = callback_count - dependent_refs.count

      ruby_callbacks_we_can_ignore = IGNORE_CALLBACKS[klass.name]&.to_i || IGNORE_CALLBACKS[klass.base_class.name].to_i
      need_to_call_ruby_callbacks = ruby_callback_count > ruby_callbacks_we_can_ignore
      [dependent_refs, need_to_call_ruby_callbacks]
    end

    # in_batches for delete or destroy (not nullify)
    # similar to:
    #   scope.in_batches(of: batch_size, :load => true).destroy_all.count
    #
    # @block takes a subscope and returns a count
    def batch(scope, batch_size: 1000)
      pk = scope.primary_key
      total = 0

      loop do
        if (id = scope.order(pk).limit(1).offset(batch_size).pluck(pk).first)
          total += yield(scope.where("#{pk} < ?", id))
        else
          return total += yield(scope)
        end
      end
    end

    def run(name, action, &block)
      count, timings = Benchmark.realtime_block(action, &block)
      _log.info("%-7{action} %{name} %{count} records in %.6<timings>d seconds" % {
        :action  => action,
        :count   => count,
        :name    => name,
        :timings => timings[action]
      })
    end

    def skip_run(name, action)
      _log.debug("%-7{action} %{name} skipped" % {
        :action => action,
        :name   => name
      })
    end
  end
end
