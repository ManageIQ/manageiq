class ShowbackBucket < ApplicationRecord
  belongs_to :resource, :polymorphic => true
  before_save :check_bucket_state, if: :state_changed?

  has_many :showback_charges, :dependent => :destroy, :inverse_of => :showback_bucket
  has_many :showback_events, :through => :showback_charges, :inverse_of => :showback_buckets

  validates :name,                  :presence => true
  validates :description,           :presence => true
  validates :resource,              :presence => true
  validates :start_time, :end_time, :presence => true
  validates :state,                 :presence => true, :inclusion => { :in => %w(OPEN PROCESSING CLOSE) }

  #End_time should be after start_time.
  validate  :start_time_before_end_time

  def start_time_before_end_time
    errors.add(:start_time, "Start time should be before end time") unless end_time.to_i > start_time.to_i
  end

  def check_bucket_state
    case state_was
      when "OPEN"       then  raise _("Bucket can't pass to CLOSE after OPEN")      unless state != "CLOSE"
      when "PROCESSING"
        raise _("Bucket can't pass to OPEN after PROCESSING") unless state != "OPEN"
        ShowbackBucket.create(:name        => self.name,
                              :description => self.description,
                              :resource    => self.resource,
                              :start_time  => (self.start_time + 1.months).beginning_of_month,
                              :end_time    => (self.end_time + 1.months).end_of_month,
                              :state       => "OPEN"
        ) unless ShowbackBucket.exists?(:resource => self.resource, :start_time  => (self.start_time + 1.months).beginning_of_month)
      when "CLOSE"      then  raise _("Bucket can't change state after CLOSE")
    end
  end
end
