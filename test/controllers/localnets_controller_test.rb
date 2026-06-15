# frozen_string_literal: true

require "test_helper"

class LocalnetsControllerTest < ActionDispatch::IntegrationTest
  test "dashboard loads" do
    get root_url

    assert_response :success
    assert_select "h1", "Localnet Control"
    assert_select "h3", "Local Validator"
  end
end
