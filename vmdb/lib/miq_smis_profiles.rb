class MiqSmisProfiles

  SelfContainedNAS1 = [
    {
      #
      # Exported file shares
      #
      :flags => {},
      :association => {
        :AssocClass   => 'CIM_HostedShare',
        :ResultClass  => 'CIM_FileShare',
        :Role     => "Antecedent",
        :ResultRole   => "Dependent"
      },
      :next => [
        {
          #
          # Protocol End Point for the file share.
          #
          :flags => { :pruneUnless => 'Protocol' },
          :association => {
            :AssocClass   => 'CIM_SAPAvailableForElement',
            :ResultClass  => 'CIM_ProtocolEndpoint',
            :Role     => "ManagedElement",
            :ResultRole   => "AvailableSAP"
          },
          :next => {
            #
            # The network port supported by the Protocol End Point.
            #
            :flags => {},
            :association => {
              :AssocClass   => 'CIM_DeviceSAPImplementation',
              :ResultClass  => 'CIM_NetworkPort',
              :Role     => "Dependent",
              :ResultRole   => "Antecedent"
            },
            :next => {
              #
              # Find the IP Protocol Endpoint for the network port.
              #
              :flags => {},
              :association => {
                :AssocClass   => 'CIM_DeviceSAPImplementation',
                :ResultClass  => 'CIM_IPProtocolEndpoint',
                :Role     => "Antecedent",
                :ResultRole   => "Dependent"
              }
            }
          }
        },
        {
          #
          # Exported file share setting
          #
          :flags => { :pruneUnless => 'settings' },
          :association => {
            :AssocClass   => 'CIM_ElementSettingData',
            :ResultClass  => 'SNIA_ExportedFileShareSetting',
            :Role     => "ManagedElement",
            :ResultRole   => "SettingData"
          }
        },
        {
          #
          # The filesystem on which the share is based
          #
          :flags => {},
          :association => {
            :AssocClass   => 'SNIA_SharedElement',
            :ResultClass  => 'SNIA_LocalFileSystem',
            :Role     => "SameElement",
            :ResultRole   => "SystemElement"
          },
          :next => [
            {
              #
              # Filesystem setting
              #
              :flags => { :pruneUnless => 'settings' },
              :association => {
                :AssocClass   => 'CIM_ElementSettingData',
                :ResultClass  => 'CIM_FileSystemSetting',
                :Role     => "ManagedElement",
                :ResultRole   => "SettingData"
              }
            },
            {
              #
              # The storage extent on which the filesystem is based
              #
              :flags => {},
              :association => {
                :AssocClass   => 'CIM_ResidesOnExtent',
                :ResultClass  => 'CIM_StorageExtent',
                :Role     => "Dependent",
                :ResultRole   => "Antecedent"
              },
              :next => {
                #
                # Drill down into the components of composit extents
                #
                :flags => { :recurse => true },
                :association => {
                  :AssocClass   => 'CIM_BasedOn',
                  :Role     => "Dependent",
                  :ResultRole   => "Antecedent"
                },
                :next => [
                  {
                    #
                    # Find snapshot info for extents
                    #
                    :flags => { :pruneUnless => 'snapshots' },
                    :association => [
                      {
                        :AssocClass   => 'ONTAP_SnapshotBasedOnFlexVol',
                        :ResultClass  => 'ONTAP_Snapshot',
                        :Role     => "Antecedent",
                        :ResultRole   => "Dependent"
                      },
                      {
                        :AssocClass   => 'ONTAP_SnapshotBasedOnExtent',
                        :ResultClass  => 'ONTAP_Snapshot',
                        :Role     => "Antecedent",
                        :ResultRole   => "Dependent"
                      }
                    ]
                  },
                  {
                    #
                    # Storage setting
                    #
                    :flags => { :pruneUnless => 'settings' },
                    :association => {
                      :AssocClass   => 'CIM_ElementSettingData',
                      :ResultClass  => 'CIM_StorageSetting',
                      :Role     => "ManagedElement",
                      :ResultRole   => "SettingData"
                    }
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  ]

  ShareToVm = {
    #
    # File share to datastore.
    #
    :flags => { :reverse => true, :set_level => 1, :pruneUnless => 'datastore' },
    :association => {
      :AssocClass   => 'MIQ_DatastoreBacking',
      :ResultClass  => 'MIQ_CimDatastore',
      :Role     => "Dependent",
      :ResultRole   => "Antecedent"
    },
    :next => {
      #
      # Datastore to Virtual disk.
      #
      :flags => { :reverse => true, :set_level => 1, :pruneUnless => 'VM' },
      :association => {
        :AssocClass   => 'MIQ_VirtualDiskDatastore',
        :ResultClass  => 'MIQ_CimVirtualDisk',
        :Role     => "Dependent",
        :ResultRole   => "Antecedent"
      },
      :next => {
        #
        # Virtual disk to VM.
        #
        :flags => { :reverse => true, :set_level => 1 },
        :association => {
          :AssocClass   => 'MIQ_VmVirtualDisk',
          :ResultClass  => 'MIQ_CimVirtualMachine',
          :Role     => "Dependent",
          :ResultRole   => "Antecedent"
        },
        :next => {
          #
          # VM to it's other disks.
          #
          :flags => { :pruneUnless => 'vDisks', :set_level => 1 },
          :association => {
            :AssocClass   => 'MIQ_VmVirtualDisk',
            :ResultClass  => 'MIQ_CimVirtualDisk',
            :Role     => "Antecedent",
            :ResultRole   => "Dependent"
          },
          :next => {
            #
            # Virtual disk to Datastore.
            #
            :flags => {},
            :association => {
              :AssocClass   => 'MIQ_VirtualDiskDatastore',
              :ResultClass  => 'MIQ_CimDatastore',
              :Role     => "Antecedent",
              :ResultRole   => "Dependent"
            },
            :next => {
              #
              # Datastore to file share.
              #
              :flags => { :pruneUnless => 'bridge' },
              :association => {
                :AssocClass   => 'MIQ_DatastoreBacking',
                :ResultClass  => 'CIM_FileShare',
                :Role     => "Antecedent",
                :ResultRole   => "Dependent"
              },
              :next => {
                #
                # File share back up to storage system.
                #
                :flags => { :reverse => true, :set_level => 1 },
                :association => {
                  :AssocClass   => 'CIM_HostedShare',
                  :ResultClass  => 'CIM_ComputerSystem',
                  :Role     => "Dependent",
                  :ResultRole   => "Antecedent"
                },
                :next => SelfContainedNAS1
              }
            }
          }
        }
      }
    }
  }

  ShareToEsx = {
    #
    # File share to datastore.
    #
    :flags => { :reverse => true, :set_level => 1, :pruneUnless => 'datastore' },
    :association => {
      :AssocClass   => 'MIQ_DatastoreBacking',
      :ResultClass  => 'MIQ_CimDatastore',
      :Role     => "Dependent",
      :ResultRole   => "Antecedent"
    },
    :next => {
      #
      # Datastore to ESX host.
      #
      :flags => { :reverse => true, :pruneUnless => 'ESX' },
      :association => {
        :AssocClass   => 'MIQ_HostDatastore',
        :ResultClass  => 'MIQ_CimHostSystem',
        :Role     => "Dependent",
        :ResultRole   => "Antecedent"
      },
      :next => {
        #
        # ESX host to all of its VMs.
        #
        :flags => { :recurse => true, :set_level => 1, :pruneUnless => 'ESX-VMs' },
        :association => {
          :AssocClass   => 'MIQ_VmHost',
          :ResultClass  => 'MIQ_CimVirtualMachine',
          :Role     => "Dependent",
          :ResultRole   => "Antecedent"
        }
      }
    }
  }

  #
  # Access Points
  #
  AccessPoints = {
    #
    # System Devices
    #
    :flags => {},
    :association => {
      :AssocClass   => 'CIM_HostedAccessPoint',
      :Role     => "Antecedent",
      :ResultRole   => "Dependent"
    },
    :next => {
      #
      #
      #
      :flags => {},
      :association => {
        :AssocClass   => 'CIM_DeviceSAPImplementation',
        :Role     => "Dependent",
        :ResultRole   => "Antecedent"
      },
    }
  }

  System = [
    {
      #
      # System Devices
      #
      :flags => {},
      :association => {
        :AssocClass   => 'CIM_SystemDevice',
        :Role     => "GroupComponent",
        :ResultRole   => "PartComponent"
      }
    },
    {
      #
      # Hosted filesystems
      #
      :flags => {},
      :association => {
        :AssocClass   => 'CIM_HostedFileSystem',
        :Role     => "GroupComponent",
        :ResultRole   => "PartComponent"
      }
    }
  ]

  #
  # ONTAP Storage Array with snapshot information
  #
  StorageArray = [
    {
      #
      # Network ports
      #
      :flags => {},
      :association => {
        :AssocClass   => 'CIM_SystemDevice',
        :ResultClass  => 'CIM_LogicalPort',
        :Role     => "GroupComponent",
        :ResultRole   => "PartComponent"
      }
    },
    {
      #
      # Logical Disks and Storage Volumes
      #
      :flags => {},
      :association => [
        {
          :AssocClass   => 'CIM_SystemDevice',
          :ResultClass  => 'CIM_StorageVolume',
          :Role     => "GroupComponent",
          :ResultRole   => "PartComponent"
        },
        {
          :AssocClass   => 'CIM_SystemDevice',
          :ResultClass  => 'CIM_LogicalDisk',
          :Role     => "GroupComponent",
          :ResultRole   => "PartComponent"
        }
      ],
      :next => [
        {
          :flags => { :pruneUnless => 'Protocol' },
          :association => {
            :AssocClass   => 'CIM_ProtocolControllerForUnit',
            :ResultClass  => 'CIM_SCSIProtocolController',
            :Role     => "Dependent",
            :ResultRole   => "Antecedent"
          },
          :next => {
            :flags => {},
            :association => {
              :AssocClass   => 'CIM_SAPAvailableForElement',
              :ResultClass  => 'CIM_ProtocolEndpoint',
              :Role     => "ManagedElement",
              :ResultRole   => "AvailableSAP"
            },
            :next => {
              #
              # The network port supported by the Protocol End Point.
              #
              :flags => {},
              :association => {
                :AssocClass   => 'CIM_DeviceSAPImplementation',
                # :ResultClass  => 'CIM_NetworkPort',
                :Role     => "Dependent",
                :ResultRole   => "Antecedent"
              },
              :next => {
                #
                # Find the IP Protocol Endpoint for the network port.
                #
                :flags => {},
                :association => {
                  :AssocClass   => 'CIM_DeviceSAPImplementation',
                  # :ResultClass  => 'CIM_IPProtocolEndpoint',
                  :Role     => "Antecedent",
                  :ResultRole   => "Dependent"
                }
              }
            }
          }
        },
        {
          #
          # Drill down into the components of composit extents
          #
          :flags => { :recurse => true },
          :association => {
            :AssocClass   => 'CIM_BasedOn',
            :Role     => "Dependent",
            :ResultRole   => "Antecedent"
          },
          :next => [
            {
              #
              # Find snapshot info for extents
              #
              :flags => { :pruneUnless => 'snapshots' },
              :association => [
                {
                  :AssocClass   => 'ONTAP_SnapshotBasedOnFlexVol',
                  :ResultClass  => 'ONTAP_Snapshot',
                  :Role     => "Antecedent",
                  :ResultRole   => "Dependent"
                },
                {
                  :AssocClass   => 'ONTAP_SnapshotBasedOnExtent',
                  :ResultClass  => 'ONTAP_Snapshot',
                  :Role     => "Antecedent",
                  :ResultRole   => "Dependent"
                }
              ]
            },
            {
              #
              # Storage setting
              #
              :flags => { :pruneUnless => 'settings' },
              :association => {
                :AssocClass   => 'CIM_ElementSettingData',
                :ResultClass  => 'CIM_StorageSetting',
                :Role     => "ManagedElement",
                :ResultRole   => "SettingData"
              }
            }
          ]
        }
      ]
    }
  ]

  Test = {
    #
    # Exported file shares
    #
    :flags => {},
    :association => {
      :AssocClass   => 'CIM_HostedShare',
      :ResultClass  => 'CIM_FileShare',
      :Role     => "Antecedent",
      :ResultRole   => "Dependent"
    }
  }

  #
  # Self-contained NAS System profile. Down to primordial extents.
  #
  SelfContainedNAS = [
    {
      #
      # Exported file shares
      #
      :flags => {},
      :association => {
        :AssocClass   => 'CIM_HostedShare',
        :ResultClass  => 'CIM_FileShare',
        :Role     => "Antecedent",
        :ResultRole   => "Dependent"
      },
      :next => [
        {
          #
          # Protocol End Point for the file share.
          #
          :flags => { :pruneUnless => 'Protocol' },
          :association => {
            :AssocClass   => 'CIM_SAPAvailableForElement',
            :ResultClass  => 'CIM_ProtocolEndpoint',
            :Role     => "ManagedElement",
            :ResultRole   => "AvailableSAP"
          },
          :next => {
            #
            # The network port supported by the Protocol End Point.
            #
            :flags => {},
            :association => {
              :AssocClass   => 'CIM_DeviceSAPImplementation',
              :ResultClass  => 'CIM_NetworkPort',
              :Role     => "Dependent",
              :ResultRole   => "Antecedent"
            },
            :next => {
              #
              # Find the IP Protocol Endpoint for the network port.
              #
              :flags => {},
              :association => {
                :AssocClass   => 'CIM_DeviceSAPImplementation',
                :ResultClass  => 'CIM_IPProtocolEndpoint',
                :Role     => "Antecedent",
                :ResultRole   => "Dependent"
              }
            }
          }
        },
        {
          #
          # Exported file share setting
          #
          :flags => { :pruneUnless => 'settings' },
          :association => {
            :AssocClass   => 'CIM_ElementSettingData',
            :ResultClass  => 'SNIA_ExportedFileShareSetting',
            :Role     => "ManagedElement",
            :ResultRole   => "SettingData"
          }
        },
        #
        # The VMs that have storage on this share.
        #
        ShareToVm,
        #
        # The ESX hosts that have datastores based on this share.
        #
        ShareToEsx,
        {
          #
          # The filesystem on which the share is based
          #
          :flags => {},
          :association => {
            :AssocClass   => 'SNIA_SharedElement',
            :ResultClass  => 'SNIA_LocalFileSystem',
            :Role     => "SameElement",
            :ResultRole   => "SystemElement"
          },
          :next => [
            {
              #
              # Filesystem setting
              #
              :flags => { :pruneUnless => 'settings' },
              :association => {
                :AssocClass   => 'CIM_ElementSettingData',
                :ResultClass  => 'CIM_FileSystemSetting',
                :Role     => "ManagedElement",
                :ResultRole   => "SettingData"
              }
            },
            {
              #
              # The storage extent on which the filesystem is based
              #
              :flags => {},
              :association => {
                :AssocClass   => 'CIM_ResidesOnExtent',
                :ResultClass  => 'CIM_StorageExtent',
                :Role     => "Dependent",
                :ResultRole   => "Antecedent"
              },
              :next => {
                #
                # Drill down into the components of composit extents
                #
                :flags => { :recurse => true },
                :association => {
                  :AssocClass   => 'CIM_BasedOn',
                  :Role     => "Dependent",
                  :ResultRole   => "Antecedent"
                },
                :next => [
                  {
                    #
                    # Find snapshot info for extents
                    #
                    :flags => { :pruneUnless => 'snapshots' },
                    :association => [
                      {
                        :AssocClass   => 'ONTAP_SnapshotBasedOnFlexVol',
                        :ResultClass  => 'ONTAP_Snapshot',
                        :Role     => "Antecedent",
                        :ResultRole   => "Dependent"
                      },
                      {
                        :AssocClass   => 'ONTAP_SnapshotBasedOnExtent',
                        :ResultClass  => 'ONTAP_Snapshot',
                        :Role     => "Antecedent",
                        :ResultRole   => "Dependent"
                      }
                    ]
                  },
                  {
                    #
                    # Storage setting
                    #
                    :flags => { :pruneUnless => 'settings' },
                    :association => {
                      :AssocClass   => 'CIM_ElementSettingData',
                      :ResultClass  => 'CIM_StorageSetting',
                      :Role     => "ManagedElement",
                      :ResultRole   => "SettingData"
                    }
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  ]

  @@selfContainedNAS = SelfContainedNAS

  DsToShare = {
    #
    # Datastore to file share.
    #
    :flags => {},
    :association => {
      :AssocClass   => 'MIQ_DatastoreBacking',
      :ResultClass  => 'CIM_FileShare',
      :Role     => "Antecedent",
      :ResultRole   => "Dependent"
    }
  }

  ShareToDs = {
    #
    # File share to datastore.
    #
    :flags => { :reverse => true, :recurse => true },
    :association => {
      :AssocClass   => 'MIQ_DatastoreBacking',
      :ResultClass  => 'MIQ_CimDatastore',
      :Role     => "Dependent",
      :ResultRole   => "Antecedent"
    }
  }

  EsxToShare = {
    #
    # ESX Host to datastore.
    #
    :flags => {},
    :association => {
      :AssocClass   => 'MIQ_HostDatastore',
      :ResultClass  => 'MIQ_CimDatastore',
      :Role     => "Antecedent",
      :ResultRole   => "Dependent"
    },
    :next => {
      #
      # Datastore to file share.
      #
      :flags => { :recurse => true },
      :association => {
        :AssocClass   => 'MIQ_DatastoreBacking',
        :ResultClass  => 'CIM_FileShare',
        :Role     => "Antecedent",
        :ResultRole   => "Dependent"
      }
    }
  }

  def self.extractProfile
    ep = []
    [
      System,
      AccessPoints,
      StorageArray,
      SelfContainedNAS
    ].each do |p|
      if p.kind_of?(Array)
        ep += p
      else
        ep << p
      end
    end
    return ep
  end

  $viewProfiles = {
    'Storage Array'           => StorageArray,
    'Self Contained NAS'        => SelfContainedNAS,
    'System'              => System,
    'Access Points'           => AccessPoints,
  }

end # class MiqSmisProfiles
