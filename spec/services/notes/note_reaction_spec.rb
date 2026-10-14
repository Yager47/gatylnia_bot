require "rails_helper"

RSpec.describe Notes::NoteReaction do
  let(:note) { create(:track_note, telegram_message_id: 100) }

  it "puts ✍ on the note's message" do
    described_class.new(note).call

    method, params = fake_telegram.calls.sole
    expect(method).to eq(:set_message_reaction)
    expect(params).to include(chat_id: note.audio_track.chat.telegram_id, message_id: 100)
    expect(params[:reaction].map(&:emoji)).to eq([ "✍" ])
  end

  it "only logs when Telegram refuses" do
    allow(fake_telegram).to receive(:set_message_reaction).and_raise(Faraday::ConnectionFailed, "down")
    allow(Rails.logger).to receive(:warn)

    expect { described_class.new(note).call }.not_to raise_error
    expect(Rails.logger).to have_received(:warn).with(/TrackNote #{note.id}: Faraday::ConnectionFailed/)
  end
end
