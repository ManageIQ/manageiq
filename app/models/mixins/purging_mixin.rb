# Common methods for all purgers.
#
# For purge_by_date, the mixee must provide the following methods:
#
#   purge_scope(older_than): This method will receive a Time object and
#     should construct an ActiveRecord::Relation representing the conditions
#     for purging.  The conditions should only be made up of where clauses.
#
#   purge_date: This method must return the date from which purging should
#     start.  This value is typically obtained from user configuration relative
#     to the current time (e.g. the configuration specifies "6.months" and the
#     date is determined by calling 6.months.ago.utc).
#
#   purge_window_size: This method must return the maximum number of rows to be
#     deleted on each pass of the purger.  It should be chosen to balance speed
#     and memory use, as well as any records that will be deleted in the
#     purge_associated_records method.  This value is typically obtained from
#     user configuration.
#
#   purge_associated_records(ids): This is an optional method which will receive
#     the ids of the records that have just been deleted, and should purge any
#     other records associated with those ids.
#   ? can this be auto defined looking at relations and destroy / delete
#
# For purge_by_remaining, the mixee must provide the following methods:
#
#   @return [Symbol, Array<Symbol>] resource that is referenced by this table.
#   def purge_remaining_foreign_key
#     :foreign_id
#   end
#
#   example for `Driftstate`:
#   def purge_remaining_foreign_key
#     [:resource_type, :resource_id]
#   end
#
#   example for `MiqReportResult`:
#   def purge_remaining_foreign_key
#     :miq_report_id
#   end
#
#   example purge_mode_and_value
#   @return [Array<2>] the mode (i.e.: :remaining) and the number of records to keep
#   def purge_mode_and_value
#     [:remaining, ::Settings.drift_states.history.keep_drift_states]
#   end
#
# For purge_by_orphan, the mixee must provide the following methods:
#
#   @return [Array<2>] the mode (i.e.: :orphan) and the column_name to check for orphans
#   def purge_mode_and_value
#     %w[orphan resource]
#   end
module PurgingMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def purge_method
      :delete
    end

    def purge_mode_and_value
      [:date, purge_date]
    end

    def purge_timer
      purge_queue(*purge_mode_and_value)
    end

    def purge_queue(mode, *values)
      values = [nil] if values.empty?
      MiqQueue.submit_job(
        :class_name  => name,
        :method_name => "purge_by_#{mode}",
        :args        => values
      )
    end

    def purge(older_than = nil, window = nil, &block)
      purge_by_date(older_than || purge_date, window || purge_window_size, &block)
    end

    def purge_count(older_than = nil)
      purge_count_by_date(older_than || purge_date)
    end

    def purge_count_by_date(older_than)
      purge_scope(older_than).count
    end

    def purge_by_date(older_than, window = nil, &block)
      _log.info("Purging #{table_name} older than [#{older_than}]...")
      total = purge_in_batches(purge_scope(older_than), window || purge_window_size, &block)
      _log.info("Purging #{table_name} older than [#{older_than}]...Complete - Deleted #{total} records")
      total
    end

    def purge_count_by_remaining(remaining)
      purge_ids_for_remaining(remaining).size
    end

    # @param [Integer] remaining number of records per resource to keep (remains in table)
    # @param [Integer] window number of records to delete in a batch
    # @return [Integer] number of records deleted
    def purge_by_remaining(remaining, window = nil, &block)
      _log.info("Purging #{table_name} older than last #{remaining} results...")
      total = purge_in_batches(purge_ids_for_remaining(remaining), window || purge_window_size, &block)
      _log.info("Purging #{table_name} older than last #{remaining} results...Complete - Deleted #{total} records")
      total
    end

    def purge_by_scope(older_than = nil, window = nil, &block)
      _log.info("Purging #{table_name}...")
      total = purge_in_batches(purge_scope(older_than), window || purge_window_size, &block)
      _log.info("Purging #{table_name}...Complete - Deleted #{total} records")
      total
    end

    def purge_by_orphaned(fk_name, window = purge_window_size, purge_mode = :purge)
      _log.info("Purging orphans in #{table_name}...")
      total = purge_orphans(fk_name, window, purge_mode)
      _log.info("Purging orphans in #{table_name}...Complete - #{purge_mode.to_sym == :count ? 'Would delete' : 'Deleted'} #{total} records")
      total
    end

    # purging by date uses indexes and should be quicker
    # This allows us to get the lower hanging fruit then the remaining ones
    def purge_by_date_and_orphaned(older_than, fk_name, window = purge_window_size)
      total = purge_by_date(older_than, window)
      total += purge_by_orphaned(fk_name, window)
      total
    end

    private

    def purge_orphans(fk_name, window, purge_mode = :purge)
      reflection = reflect_on_association(fk_name)
      scopes = reflection.polymorphic? ? polymorphic_orphan_scopes(fk_name) : non_polymorphic_orphan_scopes(fk_name, reflection.klass)

      if purge_mode.to_sym == :count
        scopes.sum(&:count)
      else
        scopes.sum { |s| purge_in_batches(s, window) }
      end
    end

    def polymorphic_orphan_scopes(fk_name)
      polymorphic_type_column = "#{fk_name}_type"
      polymorphic_id_column   = connection.quote_column_name("#{fk_name}_id")

      polymorphic_classes(polymorphic_type_column).collect do |klass|
        resource_table = connection.quote_table_name(klass.table_name)
        q_table_name = connection.quote_table_name(table_name)

        joins("LEFT OUTER JOIN #{resource_table} ON #{q_table_name}.#{polymorphic_id_column} = #{resource_table}.id")
          .where(resource_table => {:id => nil})
          .where("#{q_table_name}.#{connection.quote_column_name(polymorphic_type_column)} = #{connection.quote(klass.name)}")
      end
    end

    def non_polymorphic_orphan_scopes(fk_name, reflection_klass)
      resource_table = connection.quote_table_name(reflection_klass.table_name)
      assoc_id = connection.quote_column_name("#{fk_name}_id")
      q_table_name = connection.quote_table_name(table_name)

      [joins("LEFT OUTER JOIN #{resource_table} ON #{q_table_name}.#{assoc_id} = #{resource_table}.id")
        .where(resource_table => {:id => nil})]
    end

    def polymorphic_classes(polymorphic_type_column)
      distinct(polymorphic_type_column).pluck(polymorphic_type_column).map(&:constantize)
    end

    # Private:  The ids to purge if we want to keep a fixed number of records
    # for each resource. Newer records (with a higher id/ lower rank) are kept.
    #
    # example:
    #
    # So given the following DriftStates:
    #
    # {id: 1, resource_type: 'foo', resource_id: 1}  # Rank = 2
    # {id: 2, resource_type: 'foo', resource_id: 1}  # Rank = 1
    # {id: 3, resource_type: 'foo', resource_id: 2}  # Rank = 2
    # {id: 4, resource_type: 'foo', resource_id: 2}  # Rank = 1
    # {id: 5, resource_type: 'bar', resource_id: 6}  # Rank = 1
    # {id: 6, resource_type: 'baz', resource_id: 4}  # Rank = 1
    #
    # For a "remaining" value of `1`, id 1 and 3 would then be up for deletion.
    #
    # @param [Integer] remaining number of records per resource to keep (remains in table)
    # @return [ActiveRecord::Relation] Records to be deleted
    def purge_ids_for_remaining(remaining)
      # HACK: `as(table_name)` fixes a bug with `from("").pluck(:id)`
      from(purge_ids_ranked_by_age.arel.as(table_name)).where("rank > ?", remaining)
    end

    # Private: Rank records by age for each resource
    #
    # Assigns a "RANK" value to each record, categorized by their foreign key(s).
    #
    # The higher the id, the lower the rank value, the higher the priority.
    #
    # The values to purge are the records with a rank greater than the number
    # of records to keep.
    #
    # @return [ActiveRecord::Relation] the ids prioritized by age.
    def purge_ids_ranked_by_age
      c = connection
      id_key = c.quote_column_name(:id)
      partition_key = Array.wrap(purge_remaining_foreign_key).collect { |k| c.quote_column_name(k) }.join(", ")
      select(<<-EOSQL)
        #{id_key}, RANK() OVER(
          PARTITION BY #{partition_key}
          ORDER BY #{id_key} DESC
        ) AS "rank"
      EOSQL
    end

    def purge_in_batches(conditions, window, total = 0, total_limit = nil)
      query = conditions.select(:id).limit(window)
      current_window = window

      loop do
        # nearing the end of our limit
        left_to_delete = total_limit && (total_limit - total)
        if total_limit && left_to_delete < window
          current_window = left_to_delete
          query = query.limit(current_window)
        end

        _log.info("Purging #{current_window} #{table_name}.")
        if respond_to?(:purge_associated_records)
          # pull back ids - will slow performance
          batch_ids = query.pluck(:id)
          break if batch_ids.empty?

          current_window = batch_ids.size

          # Purge the associated records before we purge the parent records to avoid leaving them orphaned
          purge_associated_records(batch_ids)
        else
          batch_ids = query
        end

        batch_records = unscoped.where(:id => batch_ids)
        count = purge_one_batch(batch_records)
        break if count == 0

        total += count

        yield(count, total) if block_given?
        break if count < window || (total_limit && (total_limit <= total))
      end
      total
    end

    def purge_one_batch(scope)
      if purge_method == :destroy
        destroyed = scope.destroy_all
        destroyed.detect { |d| !d.destroyed? }.tap do |failed|
          raise "failed removing record: #{failed.class.name} with id: #{failed.id} with error: #{failed.errors.full_messages}" if failed
        end

        destroyed.count
      else
        scope.delete_all
      end
    end
  end
end
