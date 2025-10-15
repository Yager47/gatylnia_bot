module Response
  class Reply < Response::Base
    def initialize(chat:, text:, reply_to_message:)
      @chat = chat
      @text = text
      @reply_to_message = reply_to_message
      @reply_to_user = nil
      @point = nil
    end

    def process
      return unless @reply_to_message

      @point = add_point
      success answer("point")
    rescue ArgumentError
      nil
    end

    private

    def add_point
      amount = Integer(@text)
      @reply_to_user = User.find_by(telegram_id: @reply_to_message[:from][:id])
      reason = @reply_to_message[:text]

      @reply_to_user.points.create!(
        amount: amount,
        reason: reason,
        chat: @chat
      )
    end

    def point_answer
      amount =  @point.amount.positive? ? "+#{@point.amount}" : @point.amount
      name = @reply_to_user.name

      "#{name} отримує #{amount} по причині: \n\"#{@point.reason}\""
    end

    def data
      {
        "point" => point_answer
      }
    end
  end
end