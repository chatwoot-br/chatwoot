class Whatsapp::HistorySyncApiJob < ApplicationJob
  queue_as :low

  # Retry configuration for history sync failures
  retry_on Errno::ECONNREFUSED, wait: :polynomially_longer, attempts: 3
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
  retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 3
  retry_on StandardError, wait: :polynomially_longer, attempts: 2

  def perform(inbox_id, manual: false)
    inbox = Inbox.find_by(id: inbox_id)
    return unless inbox
    return unless valid_whatsapp_web_channel?(inbox)

    # Check if sync already done (unless manual trigger)
    return if !manual && already_synced?(inbox)

    Rails.logger.info "[HISTORY_SYNC] Starting history sync job for inbox #{inbox_id} (manual: #{manual})"

    # Mark sync as in progress
    mark_sync_status(inbox, 'in_progress')

    # Perform the import
    service = Whatsapp::MessageImportService.new(inbox: inbox)
    stats = service.perform

    # Mark sync as completed
    mark_sync_status(inbox, 'completed', stats)

    Rails.logger.info "[HISTORY_SYNC] History sync completed for inbox #{inbox_id}: #{stats.inspect}"

    stats
  rescue StandardError => e
    Rails.logger.error "[HISTORY_SYNC] History sync failed for inbox #{inbox_id}: #{e.message}"
    mark_sync_status(inbox, 'failed', { error: e.message }) if inbox
    raise e
  end

  private

  def valid_whatsapp_web_channel?(inbox)
    inbox.channel&.provider == 'whatsapp_web'
  end

  def already_synced?(inbox)
    sync_status = inbox.channel.provider_config['history_sync_status']
    sync_status == 'completed'
  end

  def mark_sync_status(inbox, status, stats = {})
    provider_config = inbox.channel.provider_config.dup
    provider_config['history_sync_status'] = status
    provider_config['history_sync_at'] = Time.current.iso8601 if status == 'completed'
    provider_config['history_sync_stats'] = stats if stats.present?

    inbox.channel.update!(provider_config: provider_config)
  end
end
