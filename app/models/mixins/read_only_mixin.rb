module ReadOnlyMixin
  extend ActiveSupport::Concern

  included do
    before_destroy :reject_if_read_only
  end

  private

  def reject_if_read_only
    if read_only? && !EvmDatabase.seeding?
      model_name = self.class.name.pluralize.underscore.tr('_', ' ').gsub('miq ', '')
      errors.add(:base, _("Read only %{model_name} cannot be deleted.") % {:model_name => model_name})
      throw :abort
    end
  end
end
