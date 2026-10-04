require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get root_url
    assert_response :success
  end

  test "should get services" do
    get services_url
    assert_response :success
    assert_includes response.body, "ResumeMaker"
    assert_includes response.body, resume_maker_path
  end

  test "should get resume maker" do
    get resume_maker_url
    assert_response :success
    assert_includes response.body, "ResumeCraft"
  end

  test "should serve resume maker assets" do
    get resume_maker_stylesheet_url
    assert_response :success
    assert_equal "text/css", response.media_type

    get resume_maker_script_url
    assert_response :success
    assert_equal "text/javascript", response.media_type
  end
end
