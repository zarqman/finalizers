class Wheel < ApplicationRecord
  include Finalizers::Model
  belongs_to :vehicle

  state_machine :state do
    state :active, :initial
    state :deleted, require: :erasable?
    on :* => :*, trigger: ->(r){ r.state_at = Time.current }
  end

  def erasable?
    true
  end

end
