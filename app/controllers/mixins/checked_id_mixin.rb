module Mixins
  module CheckedIdMixin
    def checked_item_id(hash = params)
      return hash[:id] if hash[:id]

      checked_items = find_checked_items
      checked_items[0] if checked_items.length == 1
    end

    # Common routine to find checked items on a page (checkbox ids are
    # "check_xxx" where xxx is the item id or index)
    def find_checked_items(prefix = nil)
      if params[:miq_grid_checks].present?
        params[:miq_grid_checks].split(",").collect { |c| from_cid(c) }
      else
        prefix = "check" if prefix.nil?
        params.each_with_object([]) do |(var, val), items|
          vars = var.to_s.split("_")
          if vars[0] == prefix && val == "1"
            ids = vars[1..-1].collect { |v| from_cid(v) }
            items << ids.join("_")
          end
        end
      end
    end

    # Test RBAC on every item checked
    # Params:
    #   klass - class of accessed objects
    # Returns:
    #   array of checked items. If user does not have rigts for it,
    #   raises exception
    def find_checked_ids_with_rbac(klass, prefix = nil)
      items = find_checked_items(prefix)
      assert_rbac(klass, items)
      items
    end

    # Test RBAC on every item checked
    # Params:
    #   klass - class of accessed objects
    # Returns:
    #   array of records. If user does not have rigts for it,
    #   raises exception
    def find_checked_records_with_rbac(klass, ids = nil)
      ids ||= find_checked_items
      filtered = Rbac.filtered(klass.where(:id => ids))
      raise _("Unauthorized object or action") unless ids.length == filtered.length
      filtered
    end

    # Test RBAC in case there is only one record
    # Params:
    #   klass - class of accessed object
    #   id    - accessed object id
    # Returns:
    #   database record of checked item. If user does not have rights for it,
    #   raises an exception
    def find_record_with_rbac(klass, id, options = {})
      raise _("Invalid input") unless is_integer?(id)
      tested_object = klass.find_by(:id => id)
      if tested_object.nil?
        raise(_("User '%{user_id}' is not authorized to access '%{model}' record id '%{record_id}'") %
                {:user_id   => current_userid,
                 :record_id => id,
                 :model     => ui_lookup(:model => klass.to_s)})
      end
      Rbac.filtered_object(tested_object, :user => current_user, :named_scope => options[:named_scope]) ||
        raise(_("User '%{user_id}' is not authorized to access '%{model}' record id '%{record_id}'") %
                {:user_id   => current_userid,
                 :record_id => id,
                 :model     => ui_lookup(:model => klass.to_s)})
    end

    # Test RBAC in case there is only one record
    # Params:
    #   klass - class of accessed object
    #   id    - accessed object id
    # Returns:
    #   id of checked item. If user does not have rights for it,
    #   raises an exception
    def find_id_with_rbac(klass, id)
      assert_rbac(klass, Array.wrap(id))
      id
    end

    # Find a record by model and ID.
    # Set flash errors for not found/not authorized.
    def find_record_with_rbac_flash(model, id, resource_name = nil)
      tested_object = klass.find(id)
      if tested_object.nil?
        record_name = resource_name ? "#{ui_lookup(:model => model)} '#{resource_name}'" : _("The selected record")
        add_flash(_("%{record_name} no longer exists in the database") % {:record_name => record_name}, :error)
        return nil
      end

      checked_object = Rbac.filtered_object(tested_object, :user => current_user)
      if checked_object.nil?
        add_flash(_("You are not authorized to view %{model_name} '%{resource_name}'") %
          {:model_name => ui_lookup(:model => tested_object.class.base_model.to_s), :resource_name => resource_name}, :error)
        return nil
      end

      checked_object
    end

    # Tries to load a single checked item on from params.
    # If there's none, takes the id sent in params[:id].
    #
    # Returns:
    #   id of the item as a Fixnum
    #
    def checked_or_params_id
      objs = find_checked_items
      obj = objs.blank? && params[:id].present? ? params[:id] : objs[0]
      obj = from_cid(obj) if obj.present?
      obj
    end

    # Either creates a new instance or loads the one passed in 'ids'.
    #
    # Params:
    #   klass - class of requested object
    #   id    - id of requested object
    #
    # 'id' can be an array (then the first item is taken) or a single value.
    #
    # Returns:
    #   instance of 'klass'
    #
    def find_or_new(klass, id)
      if params[:typ] == "new"
        klass.new
      else
        Rbac.filtered(Array(id), :class => klass).first
      end
    end
  end
end
