class MessageFinder
  def initialize(conversation, params)
    @conversation = conversation
    @params = params
  end

  def perform
    current_messages
  end

  private

  def conversation_messages
    @conversation.messages.includes(:attachments, :sender, sender: { avatar_attachment: [:blob] })
  end

  def messages
    return conversation_messages if @params[:filter_internal_messages].blank?

    conversation_messages.where.not('private = ? OR message_type = ?', true, 2)
  end

  def current_messages
    if @params[:after].present? && @params[:before].present?
      messages_between(@params[:after].to_i, @params[:before].to_i)
    elsif @params[:before].present?
      messages_before(@params[:before].to_i)
    elsif @params[:after].present?
      messages_after(@params[:after].to_i)
    else
      messages_latest
    end
  end

  def messages_after(after_id)
    # Find the created_at of the reference message to paginate correctly
    # This handles history-synced messages that have higher IDs but older timestamps
    reference_message = @conversation.messages.find_by(id: after_id)
    return messages.reorder('created_at asc').limit(100) unless reference_message

    messages.reorder('created_at asc')
            .where('created_at > ? OR (created_at = ? AND id > ?)',
                   reference_message.created_at, reference_message.created_at, after_id)
            .limit(100)
  end

  def messages_before(before_id)
    # Find the created_at of the reference message to paginate correctly
    # This handles history-synced messages that have higher IDs but older timestamps
    reference_message = @conversation.messages.find_by(id: before_id)
    return [] unless reference_message

    messages.reorder('created_at desc')
            .where('created_at < ? OR (created_at = ? AND id < ?)',
                   reference_message.created_at, reference_message.created_at, before_id)
            .limit(20)
            .reverse
  end

  def messages_between(after_id, before_id)
    # Find the created_at of the reference messages to paginate correctly
    # This handles history-synced messages that have higher IDs but older timestamps
    after_message = @conversation.messages.find_by(id: after_id)
    before_message = @conversation.messages.find_by(id: before_id)

    return [] unless after_message && before_message

    messages.reorder('created_at asc')
            .where('(created_at > ? OR (created_at = ? AND id >= ?)) AND (created_at < ? OR (created_at = ? AND id < ?))',
                   after_message.created_at, after_message.created_at, after_id,
                   before_message.created_at, before_message.created_at, before_id)
            .limit(1000)
  end

  def messages_latest
    messages.reorder('created_at desc').limit(20).reverse
  end
end
