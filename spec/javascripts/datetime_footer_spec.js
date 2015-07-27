describe('Date and time in page footer', function() {
  beforeEach(function () {
    var html = '<span id="tp"></span>'
    setFixtures(html);
  });

  it('checks that date and time in page footer is correctly generated', function() {
    dateTime("0", "UTC");
    expect($("#tP").html().toEqual(jasmine.stringMatching(/\d{2}\/\d{2}\/\d{4}\s\d{2}:\d{2}\sUTC/));
  });
});
