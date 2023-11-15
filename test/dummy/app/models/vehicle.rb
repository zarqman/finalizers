class Vehicle < ApplicationRecord
  include Finalizers::Model
  has_many :wheels
  erase_dependents :wheels

  state_machine :state do
    state :active, :initial
    state :deleted, require: :erasable?
    on :* => :*, trigger: ->(r){ r.state_at = Time.current }
  end

  attr_accessor :must_keep

  def erasable?
    !@must_keep
  end

end
