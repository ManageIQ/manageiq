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
  end
end
