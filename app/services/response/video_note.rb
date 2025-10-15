module Response
  class VideoNote < Response::Base
    def initialize(video_note:)
      @video_note = video_note
    end

    def process
      return if @video_note.blank?

      if @video_note[:duration].to_i > 25
        success answer("push_ups")
      else
        if Time.now > "18:30".to_time || Time.now < "04:00".to_time
          success answer("evening_short")
        else
          success answer("coffee")
        end
      end
    end

    private

    def data
      {
        "push_ups" => basic_answers + answers("push_ups"),
        "coffee" => basic_answers + answers("coffee"),
        "evening_short" => basic_answers + answers("evening_video")
      }
    end

    def basic_answers
      answers("basic_video")
    end
  end
end