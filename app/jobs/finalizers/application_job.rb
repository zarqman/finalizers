module Finalizers
  class ApplicationJob < ActiveJob::Base

    # Automatically retry jobs that encountered a deadlock
    retry_on ActiveRecord::Deadlocked, wait: 10.seconds, attempts: :unlimited, jitter: 3.seconds

    # Most jobs are safe to ignore if the underlying records are no longer available
    discard_on ActiveJob::DeserializationError

  end
end
