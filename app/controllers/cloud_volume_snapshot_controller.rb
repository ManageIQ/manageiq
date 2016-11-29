class CloudVolumeSnapshotController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericListMixin
  include Mixins::GenericSessionMixin

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit] # Restore @edit for adv search box
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh
    return tag("CloudVolumeSnapshot") if params[:pressed] == 'cloud_volume_snapshot_tag'
    if params[:pressed] == 'cloud_volume_snapshot_delete'
      delete_cloud_volume_snapshots
    elsif @refresh_div == "main_div" && @lastaction == "show_list"
      replace_gtl_main_div
    else
      render_flash
    end
  end

  def self.display_methods
    %w(based_volumes)
  end

  def display_based_volumes
    nested_list('based_volumes', CloudVolume)
  end

  def delete_cloud_volume_snapshots
    assert_privileges("cloud_volume_snapshot_delete")

    snapshots = if @lastaction == "show_list" || (@lastaction == "show" && @layout != "cloud_volume_snapshot")
                  find_checked_items
                else
                  [params[:id]]
                end

    if snapshots.empty?
      add_flash(_("No Cloud Volume Snapshots were selected for deletion."), :error)
    end

    snapshots_to_delete = []
    snapshots.each do |snapshot_id|
      snapshot = CloudVolumeSnapshot.find_by_id(snapshot_id)
      if snapshot.nil?
        add_flash(_("Cloud Volume Snapshot no longer exists."), :error)
      else
        snapshots_to_delete.push(snapshot)
      end
    end
    process_cloud_volume_snapshots(snapshots_to_delete, "destroy") unless snapshots_to_delete.empty?

    # refresh the list if applicable
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    elsif @lastaction == "show" && @layout == "cloud_volume_snapshot"
      @single_delete = true unless flash_errors?
      if @flash_array.nil?
        add_flash(_("The selected Cloud Volume Snapshot was deleted"))
      end
    end
    render_flash
  end

  private

  # dispatches tasks to multiple snapshots
  def process_cloud_volume_snapshots(snapshots, task)
    return if snapshots.empty?

    if task == "destroy"
      snapshots.each do |snapshot|
        audit = {
          :event        => "cloud_volume_snapshot_record_delete_initiateed",
          :message      => "[#{snapshot.name}] Record delete initiated",
          :target_id    => snapshot.id,
          :target_class => "CloudVolumeSnapshot",
          :userid       => session[:userid]
        }
        AuditEvent.success(audit)
        snapshot.delete_snapshot_queue(session[:userid])
      end
      add_flash(n_("Delete initiated for %{number} Cloud Volume Snapshot.",
                   "Delete initiated for %{number} Cloud Volume Snapshots.",
                   snapshots.length) % {:number => snapshots.length})
    end
  end
end
