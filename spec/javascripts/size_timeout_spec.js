describe('Reset browser size timeout', function() {

  it('calls setTimeout if ManageIQ.sizeTimer is \'false\' and miqBrowserSizeTimeout is called', function() {
    spyOn(window, 'setTimeout');
    ManageIQ.sizeTimer = false;
    miqBrowserSizeTimeout()
    expect(setTimeout).toHaveBeenCalledWith(miqResetSizeTimer, 1000);
  });

  it('return \'undefined\' if ManageIQ.sizeTimer is \'true\'', function() {
    ManageIQ.sizeTimer = true;
    expect(miqBrowserSizeTimeout()).toEqual(undefined);
  });
});
