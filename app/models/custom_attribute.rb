class CustomAttribute < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true

  include ReportableMixin

  def stored_on_provider?
    source == "VC"
  end
end
