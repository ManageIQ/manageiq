describe('Calling miqGridSort', function() {
  it('returns url fwith no double id', function() {
    ManageIQ.actionUrl = 'show/1000000000015';
    ManageIQ.record.parentClass = 'ems_infra';
    ManageIQ.record.parentId = '1000000000015';
    expect(miqGetSortUrl(1)).toEqual('/ems_infra/show/1000000000015?sortby=1&');
  });
});
