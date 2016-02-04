class TreeBuilderChargebackRates < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:open_all => true, :full_ids => true, :leaf => "MiqReportResult"}
  end

  def set_locals_for_render
    locals = super
    temp = {
      :id_prefix      => "cbr_",
    }
    locals.merge!(temp)
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, options)
    # TODO: Common code in CharbackRate & ChargebackAssignments, need to move into module
    case options[:type]
    when :cb_assignments
      rate_types = ChargebackRate::VALID_CB_RATE_TYPES

      if count_only
        rate_types.length
      else
        objects = []
        rate_types.sort.each do |rtype|
          img = rtype.downcase == "compute" ? "hardware-processor" : "hardware-disk"
          objects.push(
            :id    => rtype,
            :text  => rtype,
            :image => img,
            :tip   => rtype
          )
        end
        objects
      end
    when :cb_rates
      # the rate accordion merge the compute rate and the storage rate in one unic rate grouping by description
      rates = ChargebackRate.all
      grouped_rates = rates.group_by(&:description)
      if count_only
        grouped_rates.length
      else
        objects = []
        grouped_rates.sort.map do |description_group|
          objects.push(
            # We identified by the structure Compute_id:Storage_id
            :id    => description_group[1][0].id.to_s + ":" + description_group[1][1].id.to_s,
            :text  => description_group[0],
            :image => 'chargeback_rate',
          )
        end
        objects
      end
    end
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, count_only, _options)
    objects = ChargebackRate.where(:rate_type => object[:id]).to_a
    count_only_or_objects(count_only, objects, "description")
  end
end
