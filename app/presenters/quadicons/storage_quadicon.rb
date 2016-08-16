module Quadicons
  class StorageQuadicon < Base
    def quadrant_list
      if render_single?
        single_list
      else
        full_list
      end
    end

    def render_single?
      !context.fetch_settings(:quadicons, :storage)
    end

    private

    def full_list
      %i(storage_type guest_count host_count storage_free_space)
    end

    def single_list
      [:storage_used_space]
    end

    def default_title_attr
      _("Name: #{record.name} | #{i18n_datastores} Type: #{record.store_type}")
    end

    def i18n_datastores
      ui_lookup(:table => "storages")
    end
  end
end
