module DriftStateMixin
  extend ActiveSupport::Concern
  included do
    has_many :drift_states, :as => :resource, :dependent => :destroy

    has_one  :first_drift_state, -> { order("timestamp") }, :as => :resource, :class_name => 'DriftState'
    has_one  :last_drift_state, -> { order("timestamp DESC") }, :as => :resource, :class_name => 'DriftState'

    has_one  :first_drift_state_timestamp_rec, -> { select("id, timestamp, resource_type, resource_id").order("timestamp") }, :as => :resource, :class_name => 'DriftState'
    has_one :last_drift_state_timestamp_rec, -> { order("timestamp DESC").select("id, timestamp, resource_type, resource_id") }, :as => :resource, :class_name => 'DriftState'

    virtual_column :first_drift_state_timestamp, :type => :time, :uses => :first_drift_state_timestamp_rec
    virtual_column :last_drift_state_timestamp,  :type => :time, :uses => :last_drift_state_timestamp_rec
  end

  def drift_state_timestamps
    drift_states.order(:timestamp).pluck(:timestamp)
  end

  def first_drift_state_timestamp
    first_drift_state_timestamp_rec.try(:timestamp)
  end

  def last_drift_state_timestamp
    last_drift_state_timestamp_rec.try(:timestamp)
  end

  def save_drift_state
    drift_states.create!(:timestamp => Time.now.utc, :data => to_model_hash)
  end
end
