require "widget_import_validator"

class WidgetImportService
  class ParsedNonWidgetYamlError < StandardError; end

  def initialize(widget_import_validator = WidgetImportValidator.new)
    @widget_import_validator = widget_import_validator
  end

  def cancel_import(import_file_upload_id)
    import_file_upload = ImportFileUpload.find(import_file_upload_id)

    destroy_queued_deletion(import_file_upload.id)
    import_file_upload.destroy
  end

  def import_widget_from_hash(widget)
    new_or_existing_widget = MiqWidget.where(:description => widget["description"]).first_or_create
    new_or_existing_widget.title ||= widget["title"]
    new_or_existing_widget.content_type ||= "report"
    new_or_existing_widget.resource = build_report_contents(widget)
    widget.delete("resource_id")
    schedule_from_widget = widget.delete("MiqSchedule")

    log_widget_import_message(new_or_existing_widget)

    new_or_existing_widget.update(widget)
    new_or_existing_widget.update(:miq_schedule => build_miq_schedule(schedule_from_widget.merge("widget_id" => new_or_existing_widget.id))) if schedule_from_widget
    new_or_existing_widget
  end

  def import_widgets(import_file_upload, widgets_to_import)
    number_imported_widgets = 0
    unless widgets_to_import.nil?
      widgets = YAML.load(import_file_upload.uploaded_content)

      widgets = widgets.select do |widget|
        widgets_to_import.include?(widget["MiqWidget"]["title"])
      end

      raise ParsedNonWidgetYamlError if widgets.empty?

      widgets.each do |widget|
        number_imported_widgets += 1 if import_widget_from_hash(widget["MiqWidget"])
      end
    end

    destroy_queued_deletion(import_file_upload.id)
    import_file_upload.destroy
    number_imported_widgets
  end

  def store_for_import(file_contents)
    import_file_upload = create_import_file_upload(file_contents)

    @widget_import_validator.determine_validity(import_file_upload)

    import_file_upload
  ensure
    queue_deletion(import_file_upload.id)
  end

  private

  def create_import_file_upload(file_contents)
    ImportFileUpload.create.tap do |import_file_upload|
      import_file_upload.store_binary_data_as_yml(file_contents, "Widget import")
    end
  end

  def build_report_contents(widget)
    report_contents = widget.delete("MiqReportContent")

    return if report_contents.blank?

    report_attributes = name = new_or_existing_report = nil

    if report_contents.first["MiqReport"]
      report_attributes = report_contents.first["MiqReport"]
      name = report_attributes.delete("menu_name")
      new_or_existing_report = MiqReport.where(:name => name).first_or_initialize
    end

    if new_or_existing_report.new_record?
      new_or_existing_report.update(report_attributes)
      $log.info("Created a new MiqReport [#{name}] for MiqWidget import")
    else
      $log.info("Not importing existing MiqReport [#{name}]")
    end

    new_or_existing_report
  end

  def build_miq_schedule(schedule_contents)
    return if schedule_contents.blank?
    new_widget_id = schedule_contents.delete("widget_id")

    new_or_existing_schedule = MiqSchedule.where(
      :name          => schedule_contents["name"],
      :resource_type => schedule_contents["resource_type"]
    ).first_or_initialize
    new_or_existing_schedule.update(schedule_contents) if new_or_existing_schedule.new_record?

    if new_or_existing_schedule
      filter = MiqExpression.new("=" => {"field" => "MiqWidget-id", "value" => new_widget_id})
      new_or_existing_schedule.update(:filter => filter)
    end

    new_or_existing_schedule
  end

  def destroy_queued_deletion(import_file_upload_id)
    MiqQueue.unqueue(
      :class_name  => "ImportFileUpload",
      :instance_id => import_file_upload_id,
      :method_name => "destroy"
    )
  end

  def queue_deletion(import_file_upload_id)
    MiqQueue.put(
      :class_name  => "ImportFileUpload",
      :instance_id => import_file_upload_id,
      :deliver_on  => 1.day.from_now,
      :method_name => "destroy"
    )
  end

  def log_widget_import_message(widget)
    if widget.new_record?
      $log.info("Creating new MiqWidget [#{widget.title}]")
    else
      $log.info("Updating MiqWidget [#{widget.title}]")
    end
  end
end
