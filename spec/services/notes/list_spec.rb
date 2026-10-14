require "rails_helper"

RSpec.describe Notes::List do
  let(:chat) { create(:chat, notes_enabled: true) }
  let(:track) { create(:audio_track, chat: chat, telegram_message_id: 42, caption: "Сон, мікс v3") }
  let(:serhii) { create(:user, first_name: "Сергій", last_name: nil) }
  let(:artem) { create(:user, first_name: "Artem", last_name: nil) }
  let(:audio_message) { { message_id: 42, audio: { file_id: "f1" } } }

  def list(reply_to_message = audio_message)
    described_class.new(chat: chat, reply_to_message: reply_to_message).text
  end

  it "groups notes by person in the order they first wrote, marking voice and video" do
    create(:track_note, audio_track: track, user: artem, text: "вокал тихий", sent_at: 3.hours.ago)
    create(:track_note, audio_track: track, user: serhii, text: "бас гуде ", sent_at: 2.hours.ago)
    create(:track_note, audio_track: track, user: artem, source: :voice, text: "соло в кінці задовге", sent_at: 1.hour.ago)
    create(:track_note, audio_track: track, user: serhii, source: :video_note, text: "бочку голосніше", sent_at: 30.minutes.ago)

    expect(list).to eq(<<~TEXT.chomp)
      📝 Замітки до «Сон, мікс v3»:

      Artem:
      • вокал тихий
      • 🎤 соло в кінці задовге

      Сергій:
      • бас гуде
      • ⭕ бочку голосніше
    TEXT
  end

  it "leaves out notes on other tracks" do
    create(:track_note, audio_track: create(:audio_track, chat: chat), text: "інший трек")
    create(:track_note, audio_track: track, user: serhii, text: "цей трек")

    expect(list).to include("цей трек")
    expect(list).not_to include("інший трек")
  end

  it "says when a track has no notes, recorded or not" do
    track

    expect(list).to eq("До цього треку ще нема заміток.")
    expect(list({ message_id: 77, audio: { file_id: "f9" } })).to eq("До цього треку ще нема заміток.")
  end

  it "asks for a reply to an audio otherwise" do
    expect(list(nil)).to eq("Відповідай цією командою на аудіо з треком.")
    expect(list({ message_id: 50, text: "привіт" })).to eq("Відповідай цією командою на аудіо з треком.")
  end
end
