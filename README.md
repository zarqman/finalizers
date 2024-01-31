# Finalizers

Add finalizers to your ActiveRecord models. Useful for cleaning up child dependencies in the database as well as associated external resources (APIs, etc).

* Finalizers and the eventual `destroy` run in background jobs, keeping controllers quick and responsive
* Finalizers may cleanup other database records, remote APIs, or anything else relevant
* Finalizers may also confirm any arbitrary dependency, making them extremly flexible
* Quickly define database-based dependencies with `erase_dependents`
* Supports cascading deletes
* Replaces `has_many ... dependent: :async`
* Background jobs are fully retryable, easily handling delays in satisfying finalizer dependencies and checks
* Dynamically determine when models shouldn't be deleted at all using `erasable?`
* Easily check if erasable and delete (erase) in controllers with `safe_erase`



## Basics and Usage

Each model used with Finalizers requires a `state` string field.

Finalizers is also aware and accommodative of `state_at` (when `state` was last changed) and `delete_at` (for scheduling a future delete), but expects those to be implemented separately.

A quick heads up: Finalizers depends on `rescue_like_a_pro` which changes how `retry_on` and `discard_on` are processed for *all* ActiveJob children. `rescue_like_a_pro` changes ActiveJob to handle exceptions based on specificity instead of last defintion, which most will find more intuitive. For basic usage, likely nothing will change. For advanced exception handling, it may warrant a review of your Job classes (which can often be simplified as a result).


#### Installation

As always, add to your Gemfile and run `bundle install` (or however you like to do such things):

```ruby
gem "finalizers"
```

```bash
$ bundle
```


#### Models

Add the required `state` field using a migration. It just needs to be a simple string long enough to hold `"deleted"` and any other values you wish to you.

Then, add `include Finalizers::Model` to the model and define an `erasable?` method.

To automatically cascade erase operations onto child classes (ie: `has_one` or `has_many`), use `erase_dependents`.

To add custom finalizers, use `add_finalizer`.

---

Finalizers add new `erase` and `erase!` methods to your model. You should generally use these instead of `destroy`.

`destroy` and `destroy!` continue to exist and will still destroy immediately, without running finalizers or handling dependent records. To prevent accidentally calling them and thus bypassing your finalizers, the `:force` argument must be added: `destroy(force: true)`. This is often still useful in tests.

For controllers and all other 'normal' actions, use `erase`, `erase!`, or `safe_erase`. `safe_erase` is designed especially for controllers. See below.

```ruby
class Vehicle < ApplicationRecord
  # Must have `state` attribute
  # May have `state_at` attribute. If present, will be updated when `state` is updated.
  # May have `delete_at` attribute. If present, will be cleared when `erase` is called.
  include Finalizers::Model

  add_finalizer :delete_from_remote
    # In addition to ensuring dependents are destroyed (see erase_dependents below),
    # additional work can be required to complete before this record is destroyed.
    # This is especially useful for cleaning up data in another system, but isn't
    # limited to that.
    # See `#delete_from_remote` below for more discussion.
  add_finalizer do
    # alternate syntax to define work inline if preferred
    raise RetryJobError, "#{self.class.name} #{id} still running" if running?
  end

  has_many :wheels
    # Hint: to further protect against accidental use of #destroy (and bypassing your
    # finalizers), add a foreign key restriction to your schema and then add
    # `:restrict_with_exception` to the has_many definition:
    #   has_many :wheels, dependent: :restrict_with_exception
  erase_dependents :wheels
    # This does 2 things:
    # a) When Vehicle is erased (state := 'deleted'), causes all child Wheels to be
    #   erased too. (And, if Wheel has_one :tire, this will cascade as well.)
    # b) Adds a finalizer to verify that the associated children are destroyed
    #   before proceeding. That means that children will always have access to the
    #   parent while performing their own finalization.
    # Note: any dependent classes here must also include Finalizers::Model.

  def erasable?
    true     # Allow `safe_erase` to proceed
    # false  # Prevent `safe_erase` from proceeding
  end
  # This only affects `safe_erase`. Using `erase` or `erase~` will work regardless.
  # Returning false is particularly useful if an object shouldn't be allowed to be
  # erased because it's in use, is a global object, etc.

  # Finalizer callback, as configured above.
  def delete_from_remote
    # If another finalizer fails (including erase_dependents), this finalizer may be
    # called more than once so it should be idempotent.
    # You may use (and update) a tracking field (`remote_uuid` here), or may simply
    # repeat the operation.
    if remote_uuid
      RemoteService.delete id: remote_uuid
      update_columns remote_uuid: nil
    end

    # Exceptions will cause the finalizer to fail and be retried, so they should
    # usually be passed through. You can raise RetryJobError if another exception
    # isn't already in play.
  end

end
```


#### Controllers

In `SomeController#destroy`, use `safe_erase` instead of `destroy`. `safe_erase` returns a boolean and will add an error message when false, so it allows making `#destroy` work like `#update`. Optionally, you may erase via `#update` by setting `@model.state = 'deleted'`.

```ruby
def destroy
  if @model.safe_erase
    render @model, notice: 'Resource deleted.'
  else
    render 'errors', locals: {obj: @model}, status: 422
      # however you normally render errors
  end
end
```


#### Error reporting

Finalizers uses `RetryJobError` internally to help manage flow. It is recommended to exclude it from any exception reporting tool (Honeybadger, Sentry, etc).



## Advanced usage

#### Overriding the default EraserJob

Just create your own version of the job in your app. Zeitwerk should prefer the app's version over the gem's.

Be sure to keep the existing signature for `perform`:
```ruby
  def perform(obj)
  end
```

#### Extending the default EraserJob

Like overriding, create your own version of the job and require the original job before reopening it:
```ruby
load "#{Finalizers::Engine.root}/app/jobs/eraser_job.rb"
class EraserJob
  # add extensions here
end
```



## History and Compatibility

Extracted from production code.

Tested w/Rails 7.x and GoodJob 3.x.



## Contributing
Pull requests welcomed. If unsure whether a proposed addition is in scope, feel free to open an Issue for discussion (not required though).



## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
