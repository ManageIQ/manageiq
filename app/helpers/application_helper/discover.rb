module ApplicationHelper
  module Discover
    def discover_type(dtype)
      dtypes = {
        "azure"           => _("Azure"),
        "ec2"             => _("Amazon"),
        "esx"             => _("ESX"),
        "hyperv"          => _("Hyper-V"),
        "ipmi"            => _("IPMI"),
        "kvm"             => _("KVM"),
        "msvirtualserver" => _("MS vCenter"),
        "rhevm"           => _("Red Hat Virtualization Manager"),
        "scvmm"           => _("Microsoft System Center VMM"),
        "virtualcenter"   => _("VMware vCenter"),
        "vmwareserver"    => _("VMware Server"),
      }

      if dtypes.key?(dtype)
        dtypes[dtype]
      else
        dtype.titleize
      end
    end
  end
end
