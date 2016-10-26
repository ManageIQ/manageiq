Vmdb::Gettext::Domains.add_domain(
  'ManageIQ_Providers_<%= class_name %>',
  ManageIQ::Providers::<%= class_name %>::Engine.root.join('locale').to_s,
  :po
)
