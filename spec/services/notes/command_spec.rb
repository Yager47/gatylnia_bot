require "rails_helper"

RSpec.describe Notes::Command do
  let(:chat) { create(:chat, notes_enabled: true) }
  let(:serhii) { create(:user, first_name: "Сергій", last_name: nil, username: "Yager47", chats: [ chat ]) }
  let(:artem) { create(:user, first_name: "Artem", last_name: nil, username: "artem_b", chats: [ chat ]) }
  let(:track) { create(:audio_track, chat: chat, telegram_message_id: 42, caption: "Сон, мікс v3") }
  let(:audio_message) { { message_id: 42, audio: { file_id: "f1" } }.with_indifferent_access }

  def run(command, user: serhii, reply_to_message: audio_message)
    described_class.new(command: command, chat: chat, user: user, reply_to_message: reply_to_message).call
  end

  before do
    create(:track_note, audio_track: track, user: serhii, text: "бас тихий", sent_at: 2.hours.ago)
    create(:track_note, audio_track: track, user: artem, text: "вокал тихий", sent_at: 1.hour.ago)
  end

  it "lists everyone's notes" do
    expect(run("замітки")).to include("Сергій:", "Artem:")
  end

  describe "one person's notes" do
    it "finds them by username, in any case" do
      text = run("замітки @yager47")

      expect(text).to include("Сергій:\n• бас тихий")
      expect(text).not_to include("Artem")
    end

    it "lists the sender's own with мої замітки" do
      expect(run("мої замітки", user: artem)).to eq("📝 Замітки до «Сон, мікс v3»:\n\nArtem:\n• вокал тихий")
    end

    it "says when that person has none on this track" do
      someone = create(:user, first_name: "Оля", last_name: nil, username: "olia", chats: [ chat ])

      expect(run("замітки @olia")).to eq("Оля: заміток до цього треку нема.")
      expect(run("мої замітки", user: someone)).to eq("Оля: заміток до цього треку нема.")
    end

    it "says when nobody here has that username" do
      expect(run("замітки @nobody")).to eq("Не знайшов @nobody у цьому чаті.")
    end
  end

  describe "видали замітки" do
    it "removes only the sender's notes on this track" do
      other_track_note = create(:track_note, audio_track: create(:audio_track, chat: chat), user: serhii)

      expect(run("видали замітки")).to eq("Видалив твої замітки до «Сон, мікс v3» (1).")
      expect(track.notes.map(&:user)).to eq([ artem ])
      expect(TrackNote.exists?(other_track_note.id)).to be(true)
    end

    it "says when there was nothing to remove" do
      run("видали замітки")

      expect(run("видали замітки")).to eq("У тебе нема заміток до цього треку.")
    end

    it "asks for a reply to an audio" do
      expect(run("видали замітки", reply_to_message: nil)).to eq("Відповідай цією командою на аудіо з треком.")
      expect(TrackNote.count).to eq(2)
    end
  end

  it "answers nothing while notes are off, or for other commands" do
    expect(run("баланс")).to be_nil

    chat.update!(notes_enabled: false)

    expect(run("замітки")).to be_nil
    expect(run("видали замітки")).to be_nil
    expect(TrackNote.count).to eq(2)
  end
end
