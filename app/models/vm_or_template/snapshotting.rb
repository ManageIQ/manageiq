module VmOrTemplate::Snapshotting
  extend ActiveSupport::Concern

  included do
    has_many :snapshots, :dependent => :destroy

    virtual_total  :v_total_snapshots, :snapshots
    virtual_column :v_snapshot_oldest_name,               :type => :string,     :uses => :snapshots
    virtual_column :v_snapshot_oldest_description,        :type => :string,     :uses => :snapshots
    virtual_column :v_snapshot_oldest_total_size,         :type => :integer,    :uses => :snapshots
    virtual_column :v_snapshot_oldest_timestamp,          :type => :datetime,   :uses => :snapshots
    virtual_column :v_snapshot_newest_name,               :type => :string,     :uses => :snapshots
    virtual_column :v_snapshot_newest_description,        :type => :string,     :uses => :snapshots
    virtual_column :v_snapshot_newest_total_size,         :type => :integer,    :uses => :snapshots
    virtual_column :v_snapshot_newest_timestamp,          :type => :datetime,   :uses => :snapshots
  end

  def newest_snapshot
    snapshots.max_by(&:create_time)
  end

  def oldest_snapshot
    snapshots.min_by(&:create_time)
  end

  def v_snapshot_oldest_name
    oldest = oldest_snapshot
    return nil if oldest.nil?
    oldest.name
  end

  def v_snapshot_oldest_description
    oldest = oldest_snapshot
    return nil if oldest.nil?
    oldest.description
  end

  def v_snapshot_oldest_total_size
    oldest = oldest_snapshot
    return nil if oldest.nil?
    oldest.total_size
  end

  def v_snapshot_oldest_timestamp
    oldest = oldest_snapshot
    return nil if oldest.nil?
    oldest.create_time
  end

  def v_snapshot_newest_name
    newest = newest_snapshot
    return nil if newest.nil?
    newest.name
  end

  def v_snapshot_newest_description
    newest = newest_snapshot
    return nil if newest.nil?
    newest.description
  end

  def v_snapshot_newest_total_size
    newest = newest_snapshot
    return nil if newest.nil?
    newest.total_size
  end

  def v_snapshot_newest_timestamp
    newest = newest_snapshot
    return nil if newest.nil?
    newest.create_time
  end

  def snapshot_storage
    snapshots.inject(0) { |t, s| t + s.total_size.to_i }
  end
end
