module MiqWidget::ImportExport
  extend ActiveSupport::Concern

  module ClassMethods
    def import_from_hash(widget, options={})
      raise "No Widget to Import" if widget.nil?

      status = { :class => self.name, :description => widget["description"], :children => [] }

      if rep = widget.delete("MiqReportContent")
        report_klass = Object.const_get(rep.first.keys.first)
        report, status[:children] = report_klass.import_from_hash(rep.first, options)

        if status[:children][:level] == "error"
          status[:status] = :error
          _log.error("Importing widget: [#{widget["description"]}] - Aborted. Status: #{status[:children][:message]}")
          return nil, status
        end
      end

      w = MiqWidget.where(:guid => widget["guid"]).first
      if w.nil?
        w = MiqWidget.new(widget)
        status.merge!(:status => :add, :message => "Imported Widget: [#{widget["description"]}]")
        msg = "Importing widget: [#{widget["description"]}]"
      elsif options[:overwrite]
        status[:old_description] = w.description
        w.attributes = widget
        status.merge!(:status => :update, :message => "Replaced Widget: [#{widget["description"]}]")
        msg = "Overwriting widget: [#{widget["description"]}]"
      else
        status.merge!(:status => :keep, :message => "Skipping Widget (already in DB): [#{widget["description"]}]")
        msg = "Skipping widget (already in DB): [#{widget["description"]}]"
      end

      unless w.valid?
        status[:status]  = :conflict
        status[:messages] << w.errors.full_messages
      end

      msg = "#{msg}"
      msg << ", Messages: #{status[:messages].join(",")}" if status[:messages]
      _log.info(msg)

      if options[:save]
        w.resource = report if report
        w.save!
        _log.info("- Completed.")
      end

      return w, status
    end
  end

  def export_to_array
    h = self.attributes
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
