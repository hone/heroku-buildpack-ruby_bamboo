require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'test_helper'))
class NewRelic::Agent::Instrumentation::ControllerInstrumentationTest < Test::Unit::TestCase
  require 'new_relic/agent/instrumentation/controller_instrumentation'
  class TestObject
    include NewRelic::Agent::Instrumentation::ControllerInstrumentation
  end

  def setup
    @object = TestObject.new
  end

  def test_detect_upstream_wait_basic
    start_time = Time.now
    # should return the start time above by default
    @object.expects(:newrelic_request_headers).returns({:request => 'headers'}).twice
    NewRelic::Agent::Instrumentation::QueueTime.expects(:parse_frontend_timestamp) \
      .with({:request => 'headers'}, start_time).returns(start_time)
    assert_equal(start_time, @object.send(:_detect_upstream_wait, start_time))
  end

  def test_detect_upstream_wait_with_upstream
    start_time = Time.now
    runs_at = start_time + 1
    @object = TestObject.new
    @object.expects(:newrelic_request_headers).returns(true).twice
    NewRelic::Agent::Instrumentation::QueueTime.expects(:parse_frontend_timestamp) \
      .with(true, runs_at).returns(start_time)
    assert_equal(start_time, @object.send(:_detect_upstream_wait, runs_at))
  end

  def test_detect_upstream_wait_swallows_errors
    start_time = Time.now
    # should return the start time above when an error is raised
    @object.expects(:newrelic_request_headers).returns({:request => 'headers'}).twice
    NewRelic::Agent::Instrumentation::QueueTime.expects(:parse_frontend_timestamp) \
      .with({:request => 'headers'}, start_time).raises("an error")
    assert_equal(start_time, @object.send(:_detect_upstream_wait, start_time))
  end
end
