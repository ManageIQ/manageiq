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

    def record_class
      record.class.base_model.name.underscore.to_sym
    end

    def render_badge
      unless record.get_policies.empty?
        concat(Quadicons::Badge.new(record, context).render)
      end
    end

    private

    def link_builder
      LinkBuilders::VmOrTemplateLinkBuilder
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
