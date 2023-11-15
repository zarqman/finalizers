require 'test_helper'

class Finalizers::ModelTest < ActiveJob::TestCase
  # https://guides.rubyonrails.org/testing.html#testing-parallel-transactions
  self.use_transactional_tests = false

  setup do
    queue_adapter.perform_enqueued_at_jobs = false
  end

  teardown do
    [Wheel, Vehicle].each(&:delete_all)
  end


  test "on_deleted" do
    [ [:erase],
      [:erase!],
      [:update!, state: 'deleted']
    ].each do |meth_args|
      s = build_vehicle
      refute_equal 'deleted', s.state

      assert_enqueued_jobs 5, only: EraserJob do
        s.send(*meth_args)
        assert_equal 'deleted', s.state
      end
    end
  end

  test "safe_erase" do
    s = Vehicle.create! color: 'orange', must_keep: true
    refute s.erasable?
    refute s.safe_erase
    assert_equal 'active', s.state

    s.must_keep = false
    assert s.erasable?
    assert s.safe_erase
    assert_equal 'deleted', s.state
  end

  test "protects #destroy" do
    s = Vehicle.create! color: 'white'
    assert_raises RuntimeError do
      s.destroy
    end
    assert_raises RuntimeError do
      s.destroy!
    end

    s.destroy force: true
  end

  test "erase_dependents" do
    s = build_vehicle

    assert_enqueued_jobs 5, only: EraserJob do
      s.erase!
    end
  end

  test "finalizer scopes" do
    Vehicle.create! color: 'blue'
    Vehicle.create! color: 'black', state: 'deleted'

    assert_equal 1, Vehicle.not_deleted.count, "Not-deleted vehicles: #{Vehicle.not_deleted.all.map(&:color).inspect}"
    assert_equal 2, Vehicle.count, "Visible vehicles: #{Vehicle.all.map(&:color).inspect}"
  end

  test "eraser job: completes when no dependents" do
    s = Vehicle.create! color: 'silver'
    assert_enqueued_jobs 1, only: EraserJob do
      s.erase!
    end
    assert_difference 'Vehicle.count', -1 do
      assert_no_enqueued_jobs do
        EraserJob.perform_now s
      end
    end
  end

  test "eraser job: retries when dependents exist" do
    s = build_vehicle
    assert_equal 4, s.wheels.size
    assert_enqueued_jobs 5, only: EraserJob do
      s.erase!
    end

    # should reschedule when dependent still exists
    assert_no_difference 'Vehicle.count + Wheel.count' do
      assert_enqueued_jobs 1, only: EraserJob do
        EraserJob.perform_now s
      end
    end
    enqueued_jobs.pop # drop the just rescheduled job

    # should destroy when dependent is gone
    assert_performed_jobs 5, only: EraserJob do
      assert_difference 'Vehicle.count', -1 do
        assert_difference 'Wheel.count', -4 do
          perform_enqueued_jobs only: EraserJob
        end
      end
    end
    assert_enqueued_jobs 0, only: EraserJob
  end



  def build_vehicle
    v = Vehicle.create! color: %w(red blue green gray black white purple).sample
    %w(fl fr rl rr).each{|loc| Wheel.create! location: loc, vehicle: v }
    v
  end

end
