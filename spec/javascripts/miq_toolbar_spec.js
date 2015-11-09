describe('miq_toolbar.js', function () {
  beforeEach(function () {
    setFixtures('<div id="test_tb">' +
                '  <div class="btn-group dropdown">' +
                '    <button id="button0" data-explorer="true" name="vm_power_choice" title="VM Power Functions" data-click="vm_power_choice" type="button" class="btn btn-default dropdown-toggle" data-toggle="dropdown">' +
                '      Power&nbsp;' +
                '      <span class="caret">' +
                '      </span>' +
                '    </button>' +
                '    <ul class="dropdown-menu">' +
                '      <li class="">' +
                '        <a id="button1" data-explorer="true" data-confirm="Shutdown the Guest OS on this VM?" name="vm_power_choice__vm_guest_shutdown" title="Shutdown the Guest OS on this VM" data-click="vm_power_choice__vm_guest_shutdown" href="#">' +
                '          Shutdown Guest' +
                '        </a>' +
                '      </li>' +
                '      <div class="divider" role="presentation">' +
                '      </div>' +
                '      <li class="">' +
                '        <a id="button2" data-explorer="true" data-confirm="Power Off this VM?" name="vm_power_choice__vm_stop" title="Power Off this VM" data-click="vm_power_choice__vm_stop" href="#">' +
                '          Power Off' +
                '        </a>' +
                '      </li>' +
                '    </ul>' +
                '  </div>' +
                '  <button id="button3" data-confirm="Opening a web-based VM VNC or SPICE console requires that the Provider is pre-configured to allow VNC connections.  Are you sure?" data-url="html5_console" name="vm_vnc_console" title="Open a web-based VNC or SPICE console for this VM" data-click="vm_vnc_console" type="button" class="btn btn-default">' +
                '    [&nbsp;]' +
                '  </button>' +
                '</div>');
  });

  it('initializes ManageIQ.toolbars', function () {
    expect(typeof ManageIQ.toolbars).toEqual('object');
  });

  describe('.findByDataClick', function () {
    it('finds a dropdown button', function () {
      expect( ManageIQ.toolbars.findByDataClick('#test_tb', 'vm_power_choice')[0].id ).toEqual('button0');
    });

    it('finds a dropdown item', function () {
      expect( ManageIQ.toolbars.findByDataClick('#test_tb', 'vm_power_choice__vm_guest_shutdown')[0].id ).toEqual('button1');
    });

    it('finds an ordinary button', function () {
      expect( ManageIQ.toolbars.findByDataClick('#test_tb', 'vm_vnc_console')[0].id ).toEqual('button3');
    });
  })
});
