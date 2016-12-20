class TreeBuilderChargebackRates < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:open_all => true, :full_ids => true, :leaf => "MiqReportResult"}
  end

  def root_options
    [t = _("Rates"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, options)
    # TODO: Common code in CharbackRate & ChargebackAssignments, need to move into module
    case options[:type]
    when :cb_assignments, :cb_rates
      rate_types = ChargebackRate::VALID_CB_RATE_TYPES

      if count_only
        rate_types.length
      else
        objects = []
        rate_types.sort.each do |rtype|
          img = rtype.downcase == "compute" ? "100/hardware-processor.png" : "100/hardware-disk.png"
          objects.push(
            :id    => rtype,
            :text  => rtype,
            :image => img,
            :tip   => rtype
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
