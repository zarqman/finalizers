class EraserJob < Finalizers::ApplicationJob
  queue_with_priority 10

  retry_on Exception, wait: 20.seconds, jitter: 15.seconds, attempts: :unlimited, priority: 20

  def perform(obj)
    if obj.state == 'deleted'
      obj.finalize_and_destroy!
    end
  rescue RetryJobError => ex
    logger.warn "#{ex.message} (attempt=#{executions})"
    raise
  end

end
