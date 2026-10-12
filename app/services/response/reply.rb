module Response
  # Replying to someone's message with a number gives them that many points.
  class Reply < Response::Base
    MAX_POINTS = 500

    def initialize(user:, text:, chat:, reply_to_message:)
      super(user: user, text: text)

      @chat = chat
      @reply_to_message = reply_to_message
    end

    def call
      return unless @reply_to_message

      amount = Integer(@text, exception: false)
      return if amount.nil? || amount.zero?

      # A replied-to channel post has no author ("from"), so no one to reward.
      receiver_id = @reply_to_message.dig(:from, :id)
      return unless receiver_id

      receiver = User.find_by(telegram_id: receiver_id)
      return if !receiver || @user == receiver
      return reply("Не можна за раз більше пʼятихатки вʼєбать") if amount.abs > MAX_POINTS

      point = receiver.points.create!(amount: amount, reason: @reply_to_message[:text], chat: @chat)
      reply(point_answer(point, receiver))
    end

    private

    def point_answer(point, receiver)
      amount = point.amount.positive? ? "+#{point.amount}" : point.amount
      response = "#{receiver.name} отримує #{amount}"
      response += " по причині: \n\"#{point.reason}\"" if point.reason.present?
      response
    end
  end
end
