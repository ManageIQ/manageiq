module Quadicons
  class VmOrTemplateQuadicon < Base
    def quadrant_list
      if render_single?
        single_list
      else
        full_list
      end
    end

    def render_single?
      context.fetch_settings(:quadicons, record_class).nil?
    end

    def url_options
      options = {
        :data => {
          :miq_sparkle_on  => "",
          :miq_sparkle_off => ""
        }
      }

      unless context.service_ctrlr_and_vm_view_db?
        options[:remote] = true
        options[:data][:method] = :post
      end

      if context.render_for_policy_sim?
        options[:data][:toggle] = "tooltip"
        options[:data][:placement] = "top"
        options[:title] = _("Show policy details for %{name}") % {:name => record.name}
      end

      options
    end

    def record_class
      record.class.base_model.name.underscore.to_sym
    end

    def render_badge
      unless record.get_policies.empty?
        concat(Quadicons::Badge.new(record, context).render)
      end
    end

    private

    def url_builder
      VmOrTemplateUrlBuilder
    end

    def single_list
      if show_compliance?
        [:guest_compliance]
      else
        [:guest_os]
      end
    end

    def full_list
      list = %i(guest_os guest_state host_vendor)

      if show_compliance?
        list << :guest_compliance
      end

      if show_snapshots?
        list.delete(:guest_compliance)
        list << :snapshot_count
      end

      list
    end

    def show_compliance?
      context.render_for_policy_sim?
    end

    def show_snapshots?
      !context.lastaction_is_policy_sim?
    end
  end
end
