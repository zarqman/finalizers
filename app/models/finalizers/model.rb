# usage:
# class Book  # mongoid or activerecord
#   include Concerns::Finalizers
#   has_many :editions
#     # may add dependent: :restrict_with_exception to help ensure proper operation
#     # of erase/finalization. similarly, may still use dependent: :destroy to
#     # bypass erase/finalization system, but this is discouraged except perhaps in
#     # tests [and delete() may be a better choice yet].
#   erase_dependents :editions  # replaces  dependent: :destroy  in has_many/etc
#     # this should be used for dependents that themselves should also erase in the
#     # background (and optionally define finalizers of their own).
#     # will delay erasing the present object until finalizers for dependents have
#     # completed.
#
#   add_finalizer :do_something
#   add_finalizer do
#     do_something_else || throw(:abort)
#     # alt: on error,  raise RetryJobError  instead
#   end
# end
# b = Book.create
# b.erase # alt: b.update state: 'deleted'
# b.state # => 'deleted'
# b.editions.first.state # => 'deleted
#
# the background job will then run finalizers for each Book and Edition being erased.
# like Rails' standard callbacks, if a finalizer fails, `throw(:abort)`,
# `raise RetryJobError, 'specific message'`, or raise any other exception.
# RetryJobError and throw(:abort) are excluded from sentry exception notifications.
# other exceptions will pass through as normal.
#
# requires a `state` field on the model.
# will call before/after destroy hooks when the object is finally destroyed, after
# completing finalizers.
#
# finalizers only run after verifying that dependent objects have been erased (as
# instructed by calling `erase_dependents`). this means that parent objects are not
# finalized or destroyed until all children are gone. this ensures child objects
# still have access to a functioning (undestroyed) parent to complete their own
# finalizers.
# the lifecycle looks like this:
#   check dependents for not-yet-finalized objects
#   run finalizers
#   run before_destroy callbacks
#   destroy self
#   run after_destroy callbacks
#
# finalizers should be idempotent as they may run more than once in the event of a
# failure and subsequent retry. they may persist changes to the model to help manage
# idempotence.
#
# note that erase() simply updates :state and will execute normal save and update
# callbacks.
# like destroy(), erase() does not run validations. to conditionally trigger an
# erase, use update(state: 'deleted') instead, which will not bypass validations.


module Finalizers::Model
  extend ActiveSupport::Concern

  included do
    define_model_callbacks :finalize, only: [:before]
    class << self
      alias_method :add_finalizer, :before_finalize
    end

    after_save do
      if state == 'deleted' && state_previously_was != 'deleted'
        EraserJob.perform_later self
      end
    end

    scope :not_deleted, ->{ where.not(state: 'deleted') }
  end


  module ClassMethods

    def wait_for_no_dependents(*assoc_list, erase_if_found: false)
      add_finalizer prepend: true do
        assoc_list.each do |assoc|
          proxy = send(assoc)
          # has_many's :dependent checks use .size, so match that here
          #   .size uses the cache_counter column, if available, else queries the db
          if proxy.respond_to?(:size)
            count = proxy.size
            _perform_erase_dependents assoc if erase_if_found && count > 0 && proxy.not_deleted.any?
          elsif proxy
            count = 1
            _perform_erase_dependents assoc if erase_if_found && !proxy.deleted?
          else
            count = 0
          end
          if count > 0
            raise RetryJobError, "#{self.class.name} #{id} still has #{count} dependent #{assoc}"
          end
        end
      end
    end

    def erase_dependents(*assoc_list)
      wait_for_no_dependents(*assoc_list, erase_if_found: true)
      before_update do
        if state == 'deleted' && state_was != 'deleted'
          assoc_list.each do |assoc|
            _perform_erase_dependents assoc
          end
        end
      end
    end

  end


  def deleted? ; state=='deleted' ; end

  def destroy(force: false)
    raise 'Called destroy() directly instead of using erase()' unless force
    super()
  end
  def destroy!(force: false)
    raise 'Called destroy!() directly instead of using erase!()' unless force
    destroy(force: true) || _raise_record_not_destroyed
  end

  # should run callbacks, but not validations
  # intent is to parallel destroy()'s behavior
  def erase
    self.state     = 'deleted'
    self.state_at  = Time.current if respond_to?(:state_at=) && state_changed?
    self.delete_at = nil if respond_to?(:delete_at=)
    save validate: false
  end
  def erase!
    self.state     = 'deleted'
    self.state_at  = Time.current if respond_to?(:state_at=) && state_changed?
    self.delete_at = nil if respond_to?(:delete_at=)
    save! validate: false
  end

  # must define on model
  # def erasable?
  #   ...
  # end

  def safe_erase
    if erasable?
      erase
    else
      errors.add :base, "#{self.class.model_name.human} in use"
      false
    end
  end


  # called by EraserJob
  # may call directly for testing
  def finalize_and_destroy!
    # finalizers execute outside of the destroy transaction (and callback sequence).
    # this intentionally allows finalizers to do whatever action and /persist/ that finalized state
    #   so if a later finalizer aborts, the previous ones don't have to repeat themselves.
    # finalizers should still be idempotent though, as a finalizer could re-run due to an error
    #   persisting that state, server failure, etc.
    run_callbacks :finalize do
      destroy force: true
    end
    raise RetryJobError, "#{self.class.name} #{id} finalizers did not complete" unless destroyed?
    self
  end


  private

  def _perform_erase_dependents(assoc)
    # both activerecord and mongoid use non-! variants for their :dependent
    # implementations, silently ignoring failures. match that behavior here.
    proxy = send(assoc)
    if proxy.respond_to?(:each)
      proxy.not_deleted.each(&:erase)
    elsif proxy
      proxy.erase unless proxy.deleted?
    end
  end

end
