module MiqWidget::ImportExport
  extend ActiveSupport::Concern

  module ClassMethods
    def import_from_hash(widget, options = {})
      raise _("No Widget to Import") if widget.nil?

      WidgetImportService.new.import_widget_from_hash(widget)
    end
  end

  def export_to_array
    h = attributes
    %w(id created_at updated_at last_generated_content_on miq_schedule_id miq_task_id).each { |k| h.delete(k) }
    h["MiqReportContent"] = resource.export_to_array if resource
    if miq_schedule
      miq_schedule_attributes = miq_schedule.attributes
      %w(id created_on updated_at last_run_on miq_search_id zone_id).each { |key| miq_schedule_attributes.delete(key) }
      h["MiqSchedule"] = miq_schedule_attributes
    end
    [self.class.to_s => h]
  end
end
