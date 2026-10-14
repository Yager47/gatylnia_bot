require "rails_helper"

RSpec.describe Notes::Handler do
  # Through the dispatcher, so the chat and user get created like in production.
  def dispatch(update)
    TelegramUpdates::Dispatcher.new(update.deep_stringify_keys).call
  end

  let!(:chat) { create(:chat, telegram_id: telegram_chat[:id].to_s, mode: :default, notes_enabled: true) }
  let(:sent_at) { Time.zone.local(2026, 10, 14, 18, 0) }
  let(:audio) { { file_id: "f1", file_unique_id: "u1", duration: 215, performer: "Розпач", title: "Сон", file_name: "son_v3.mp3", mime_type: "audio/mpeg" } }
  let(:wav) { { file_id: "f2", file_unique_id: "u2", file_name: "son_v4.wav", mime_type: "audio/x-wav" } }

  def audio_update(message_id: 42, **attrs)
    message_update(text: nil, message_id: message_id, date: sent_at.to_i, audio: audio, **attrs)
  end

  # Telegram sends the whole replied-to message along with a reply.
  def note_update(text:, message_id: 100, to: 42, edit: false, **attrs)
    replied = telegram_message(text: nil, message_id: to, audio: audio)
    attrs = { text: text, message_id: message_id, date: sent_at.to_i, reply_to_message: replied, **attrs }
    edit ? edited_message_update(**attrs) : message_update(**attrs)
  end

  def sender
    User.find_by!(telegram_id: "555")
  end

  # Any chatter from the default mode would reach these.
  before do
    allow_any_instance_of(DefaultHandler).to receive(:chance).and_return(true)
    allow(Ai).to receive(:reply_in).and_return("…")
  end

  describe "tracks" do
    it "records an audio message with what Telegram knows about the file, silently" do
      dispatch(audio_update(caption: "Сон, мікс v3"))

      expect(AudioTrack.sole).to have_attributes(
        chat: chat, user: sender, telegram_message_id: 42, performer: "Розпач", title: "Сон",
        file_name: "son_v3.mp3", duration: 215, caption: "Сон, мікс v3", sent_at: sent_at
      )
      expect(fake_telegram.sent_messages).to be_empty
    end

    it "records an audio file sent as a document" do
      dispatch(message_update(text: nil, message_id: 42, document: wav))

      expect(AudioTrack.sole).to have_attributes(file_name: "son_v4.wav", title: nil)
    end

    it "ignores a document that isn't audio" do
      dispatch(message_update(text: nil, message_id: 42, document: { file_id: "f3", file_name: "текст.pdf", mime_type: "application/pdf" }))

      expect(AudioTrack.count).to eq(0)
    end

    it "records a redelivered audio message once" do
      2.times { dispatch(audio_update) }

      expect(AudioTrack.count).to eq(1)
    end

    it "does nothing while notes are off" do
      chat.update!(notes_enabled: false)

      dispatch(audio_update)
      dispatch(note_update(text: "бас тихий"))

      expect(AudioTrack.count).to eq(0)
      expect(TrackNote.count).to eq(0)
    end
  end

  describe "notes" do
    before { dispatch(audio_update) }

    it "stores a text reply to the track exactly as written, silently" do
      dispatch(note_update(text: "Бас тихий, вокал перекрикує гітари"))

      expect(TrackNote.sole).to have_attributes(
        audio_track: AudioTrack.sole, user: sender, telegram_message_id: 100, source: "text",
        text: "Бас тихий, вокал перекрикує гітари", sent_at: sent_at
      )
      expect(fake_telegram.sent_messages).to be_empty
      expect(Ai).not_to have_received(:reply_in)
    end

    it "updates the note when its message is edited, and ignores a redelivery" do
      dispatch(note_update(text: "бас тихий"))
      dispatch(note_update(text: "бас тихий"))
      dispatch(note_update(text: "бас тихий, і бочка теж", edit: true))

      expect(TrackNote.sole.text).to eq("бас тихий, і бочка теж")
    end

    it "doesn't take the notes command for a note" do
      dispatch(note_update(text: "@test_bot замітки"))

      expect(TrackNote.count).to eq(0)
    end

    it "ignores a reply to something that isn't audio" do
      dispatch(message_update(text: "ага", message_id: 101, reply_to_message: telegram_message(text: "привіт", message_id: 50)))

      expect(TrackNote.count).to eq(0)
    end

    it "ignores a reply to a note: that's discussion" do
      dispatch(note_update(text: "бас тихий"))
      dispatch(message_update(text: "не згоден", message_id: 101, reply_to_message: telegram_message(text: "бас тихий", message_id: 100)))

      expect(TrackNote.count).to eq(1)
    end
  end

  it "picks up audio sent before notes were on from its first note" do
    dispatch(note_update(text: "вокал тихий", to: 77, reply_to_message: telegram_message(text: nil, message_id: 77, from: telegram_from(id: 999, first_name: "Artem"), audio: audio, date: sent_at.to_i - 3600)))

    expect(AudioTrack.sole).to have_attributes(telegram_message_id: 77, user: User.find_by!(telegram_id: "999"), sent_at: sent_at - 1.hour)
    expect(TrackNote.sole.text).to eq("вокал тихий")
  end
end
