module Response
  class Reply < Response::Base
    def initialize(user:, text:, chat:, reply_to_message:)
      super(user: user, text: text)

      @chat = chat
      @reply_to_message = reply_to_message
      @reply_to_user = nil
      @point = nil
    end

    def process
      return unless @reply_to_message

      @point = add_point
      success answer("point") if @point
    rescue ArgumentError
      nil
    end

    private

    def add_point
      amount = Integer(@text)
      @reply_to_user = User.find_by(telegram_id: @reply_to_message[:from][:id])
      reason = @reply_to_message[:text]

      return if !@reply_to_user || @user == @reply_to_user

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