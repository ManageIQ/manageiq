class TreeBuilderChargebackAssignments < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:open_all => true, :full_ids => true, :leaf => "ChargebackRate"}
  end

  def set_locals_for_render
    locals = super
    temp = {
      :id_prefix      => "cba_",
    }
    locals.merge!(temp)
  end

  def root_options
    [t = _("Assignments"), t]
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
    end
  end
end
