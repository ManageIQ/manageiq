# Methods defining commong expect patterns
def expect_result_to_include_data(collection, data)
  expect(@result).to have_key(collection)
  data.each do |key, value|
    value_list = fetch_value(value)
    expect(@result[collection].size).to eq(value_list.size)
    expect(@result[collection].collect { |r| r[key] }.sort).to eq(value_list.sort)
  end
end

def expect_result_to_include_hrefs(collection, hrefs)
  expect(@result).to have_key(collection)
  href_list = fetch_value(hrefs)
  expect(@result[collection].size).to eq(href_list.size)
  href_list.each do |href|
    expect(resources_include_suffix?(@result[collection], "href", href)).to be_true
  end
end

def expect_result_resources_to_match_key_data(collection, key, values)
  value_list = fetch_value(values)
  expect(@result).to have_key(collection)
  expect(@result[collection].size).to eq(value_list.size)
  @result[collection].zip(value_list).each do |hash, value|
    expect(hash).to have_key(key)
    expect(hash[key]).to match(value)
  end
end

def call_custom_expects(method)
  expect(respond_to?(method)).to be_true
  public_send(method)
end

shared_examples_for "bad_request" do |error_message|
  it "request failed with bad request (400) #{error_message}" do
    expect(@success).to be_false
    expect(@code).to eq(400)

    if error_message.present?
      expect(@result).to have_key("error")
      expect(@result["error"]["message"]).to match(error_message)
    end
  end
end

shared_examples_for "user_unauthorized" do
  it "request failed with unauthorized (401)" do
    expect(@success).to be_false
    expect(@code).to eq(401)
  end
end

shared_examples_for "request_forbidden" do
  it "request failed with request forbidden (403)" do
    expect(@success).to be_false
    expect(@code).to eq(403)
  end
end

shared_examples_for "resource_not_found" do
  it "request failed with resource not found (404)" do
    expect(@success).to be_false
    expect(@code).to eq(404)
  end
end

shared_examples_for "request_success" do |options|
  it "request succeeded with (200)" do
    options ||= {}
    expect(@success).to be_true
    expect(@code).to eq(200)
    expect_result_to_include_data(*options[:includes_data]) if options[:includes_data].present?
    call_custom_expects(options[:custom_expects]) if options[:custom_expects].present?
  end
end

shared_examples_for "request_success_no_content" do
  it "request succeeded with no content (204)" do
    expect(@success).to be_true
    expect(@code).to eq(204)
  end
end

shared_examples_for "empty_query_result" do |collection|
  it "collection result for #{collection} to be empty" do
    expect(@success).to be_true
    expect(@code).to eq(200)
    expect(@result).to have_key("name")
    expect(@result["name"]).to eq(collection.to_s)
    expect(@result["resources"]).to be_empty
  end
end

shared_examples_for "query_result" do |collection, size, options|
  it "collection result for #{collection} to be empty" do
    options ||= {}
    expect(@success).to be_true
    expect(@code).to eq(200)
    expect(@result).to have_key("name")
    expect(@result["name"]).to eq(collection.to_s)
    expect(@result["count"]).to eq(fetch_value(options["count"])) if options["count"]
    expect(@result["subcount"]).to eq(fetch_value(size))
    expect(@result["resources"].size).to eq(fetch_value(size))
    expect_result_to_include_hrefs(*options[:includes_hrefs]) if options[:includes_hrefs].present?
    expect_result_to_include_data(*options[:includes_data]) if options[:includes_data].present?
  end
end

shared_examples_for "results_include_hrefs" do |collection, href_list|
  it "result resources include hrefs" do
    expect_result_to_include_hrefs(collection, href_list)
  end
end

shared_examples_for "results_include_data" do |collection, data|
  it "result resources include data" do
    expect_result_to_include_data(collection, data)
  end
end

shared_examples_for "results_include_keys" do |collection, keys|
  it "result resources include data" do
    expect(@result).to have_key(collection)
    results = @result[collection]
    keys.each do |key|
      expect(results.all? { |r| r.key?(key) }).to be_true
    end
  end
end

shared_examples_for "results_match_key_data" do |collection, key, values|
  it "result resources matches key data" do
    expect_result_resources_to_match_key_data(collection, key, values)
  end
end

shared_examples_for "results_match_key_pattern" do |collection, key, value|
  it "result #{collection} all have a #{key} that matches #{pattern}" do
    pattern = fetch_value(value)
    expect(@result).to have_key(collection)
    expect(@result[collection].all? { |result| result[key].match(pattern) }).to be_true
  end
end

shared_examples_for "single_resource_query" do |attr_hash|
  it "single resource query with data" do
    attr_hash ||= {}
    expect(@success).to be_true
    expect(@code).to eq(200)
    includes_hrefs = attr_hash.delete(:includes_hrefs)
    includes_data  = attr_hash.delete(:includes_data)
    attr_hash.each do |key, value|
      expect(@result).to have_key(key)
      if key == "href"
        expect(@result[key]).to match(fetch_value(value))
      else
        expect(@result[key]).to eq(fetch_value(value))
      end
    end
    expect_result_to_include_hrefs(*includes_hrefs) if includes_hrefs.present?
    expect_result_to_include_data(*includes_data)   if includes_data.present?
  end
end

shared_examples_for "single_action" do |options|
  it "processed a single action" do
    expect(@success).to be_true
    expect(@code).to eq(200)
    if options[:success]
      expect(@result).to have_key("success")
      expect(@result["success"]).to eq(options[:success])
    end
    if options[:message]
      expect(@result).to have_key("message")
      expect(@result["message"]).to match(options[:message])
    end
    if options[:href]
      expect(@result).to have_key("href")
      expect(@result["href"]).to match(fetch_value(options[:href]))
    end
    if options[:task]
      expect(@result).to have_key("task_id")
      expect(@result).to have_key("task_href")
    end
    call_custom_expects(options[:custom_expects]) if options[:custom_expects].present?
  end
end

shared_examples_for "multiple_actions" do |count, options|
  it "processed multiple actions" do
    options ||= {}
    expect(@success).to be_true
    expect(@code).to eq(200)
    expect(@result).to have_key("results")
    results = @result["results"]
    expect(results.size).to eq(count)
    expect(results.all? { |r| r["success"] }).to be_true
    if options[:task]
      expect(results.all? { |r| r.key?("task_id") }).to be_true
      expect(results.all? { |r| r.key?("task_href") }).to be_true
    end
    if options[:href_list]
      fetch_value(options[:href_list]).each do |href|
        expect(resources_include_suffix?(results, "href", href)).to be_true
      end
    end
    expect_result_resources_to_match_key_data(*options[:match_key_data]) if options[:match_key_data].present?
    call_custom_expects(options[:custom_expects]) if options[:custom_expects].present?
  end
end

shared_examples_for "tagging_result" do |tagging_results|
  it "processed tagging requests" do
    tag_results = fetch_value(tagging_results)
    expect(@success).to be_true
    expect(@code).to eq(200)
    expect(@result).to have_key("results")
    results = @result["results"]
    expect(results.size).to eq(tag_results.size)
    [results, tag_results].transpose do |result, tag_result|
      expect(result["success"]).to eq(tag_result[:success])
      expect(result["href"]).to match(tag_result[:href])
      expect(result["tag_category"]).to eq(tag_result[:tag_category])
      expect(result["tag_name"]).to eq(tag_result[:tag_name])
    end
  end
end
