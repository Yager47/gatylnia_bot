require "rails_helper"

RSpec.describe HandleVideoNoteJob do
  let(:chat) { create(:chat) }
  let(:user) { create(:user, first_name: "Петро", last_name: nil) }
  let(:sent_at) { Time.zone.local(2026, 10, 12, 9, 0) }
  let(:message) { create(:message, chat: chat, user: user, content: "Петро записав відео 10s.", telegram_message_id: 42) }
  let(:classifier) { instance_double(Activities::VideoNoteClassifier) }
  let(:frame_dirs) { [] }

  # Writes fake frames into the job's temp dir, like the real analyzer.
  def analysis_returns(transcript: "Друга кава", frames: 3)
    allow(Video::NoteAnalyzer).to receive(:call) do |dir:, **|
      frame_dirs << dir
      paths = frames.times.map { |i| File.join(dir, "frame_#{i}.jpg").tap { |path| File.write(path, "img") } }
      Video::NoteAnalyzer::Result.new(description: "Петро записав відео 10s. Транскрипт: #{transcript}.", transcript: transcript, frame_paths: paths)
    end
  end

  def classify_as(coffee: false, push_ups: false, ordinal: nil)
    allow(Activities::VideoNoteClassifier).to receive(:new).and_return(classifier)
    allow(classifier).to receive(:call).and_return(Activities::VideoNoteClassifier::Result.new(coffee: coffee, ordinal: ordinal, push_ups: push_ups))
  end

  def perform
    described_class.perform_now(message, file_id: "file-1", duration: 10, sent_at: sent_at)
  end

  def sent_texts
    fake_telegram.sent_messages.map { |params| params[:text] }
  end

  before { analysis_returns }

  # The test adapter ignores Solid Queue's limit, so check the declared settings.
  it "runs one video note at a time across all chats" do
    jobs = [ described_class.new(message, file_id: "a", duration: 1, sent_at: sent_at),
             described_class.new(create(:message), file_id: "b", duration: 1, sent_at: sent_at) ]

    expect(described_class.concurrency_limit).to eq(1)
    expect(jobs.map(&:concurrency_key).uniq.size).to eq(1)
  end

  it "saves the transcript on the message for later AI context" do
    classify_as(coffee: true)

    perform

    expect(message.reload.content).to eq("Петро записав відео 10s. Транскрипт: Друга кава.")
  end

  it "passes the Telegram file and duration to the analyzer" do
    classify_as(coffee: true)

    perform

    expect(Video::NoteAnalyzer).to have_received(:call).with(video_note: { file_id: "file-1", duration: 10 }, user: user, dir: kind_of(String))
  end

  it "records coffee and confirms without an AI reply" do
    classify_as(coffee: true, ordinal: 2)

    perform

    expect(Activity.sole).to have_attributes(kind: "coffee", source: "video_note", amount: 1, occurred_at: sent_at, details: { "ordinal" => 2 })
    expect(sent_texts).to eq([ "☕ Петро: 1 за сьогодні" ])
    expect(Ai).not_to have_received(:reply_in)
  end

  it "records push-ups" do
    classify_as(push_ups: true)

    perform

    expect(Activity.sole).to have_attributes(kind: "push_ups", amount: 1, details: {})
    expect(sent_texts).to eq([ "💪 Петро: 1 підхід за сьогодні" ])
  end

  it "records both from one video in one message" do
    classify_as(coffee: true, push_ups: true)

    perform

    expect(Activity.pluck(:kind)).to contain_exactly("coffee", "push_ups")
    expect(sent_texts).to eq([ "☕💪 Петро: 1 кава, 1 підхід відтискань за сьогодні" ])
  end

  it "replies in character with all frames, tied to this video, when it shows neither" do
    classify_as
    received = nil
    allow(Ai).to receive(:reply_in) do |_chat, frames_for:, frame_paths:|
      received = { frames_for: frames_for, frames: frame_paths.map { |path| File.basename(path) } }
      "Шо ти там бубониш"
    end

    perform

    expect(Activity.count).to eq(0)
    expect(received).to eq(frames_for: message, frames: %w[frame_0.jpg frame_1.jpg frame_2.jpg])
    expect(sent_texts).to eq([ "Шо ти там бубониш" ])
  end

  it "replies in character without asking the classifier when the analysis failed" do
    analysis_returns(transcript: nil, frames: 0)
    allow(Activities::VideoNoteClassifier).to receive(:new)
    allow(Ai).to receive(:reply_in).and_return("Нічо не видно")

    perform

    expect(Activities::VideoNoteClassifier).not_to have_received(:new)
    expect(Ai).to have_received(:reply_in).with(chat, frames_for: message, frame_paths: [])
  end

  it "removes the frames when it's done, even after an error" do
    classify_as(coffee: true)
    allow(fake_telegram).to receive(:send_message).and_raise("boom")

    expect { perform }.to raise_error("boom")

    expect(frame_dirs.size).to eq(1)
    expect(Dir.exist?(frame_dirs.first)).to be(false)
  end

  it "rolls the record back when sending fails, so a retry starts clean" do
    classify_as(push_ups: true)
    allow(fake_telegram).to receive(:send_message).and_raise(Faraday::ConnectionFailed, "down")

    perform # retry_on catches it and schedules a retry

    expect(Activity.count).to eq(0)
  end

  it "does nothing when run again after recording" do
    classify_as(coffee: true)

    2.times { perform }

    expect(Activity.count).to eq(1)
    expect(sent_texts.size).to eq(1)
    expect(Video::NoteAnalyzer).to have_received(:call).once
  end
end
