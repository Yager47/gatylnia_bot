require "rails_helper"

RSpec.describe AnswerFiles do
  before { described_class.clear }
  after { described_class.clear }

  # slow_load: sleeps inside each load, which releases the GVL so other
  # threads run in the middle of it (as with a slow disk or a busy CPU).
  def count_disk_reads(slow_load: false)
    reads = 0
    allow(YAML).to receive(:load_file).and_wrap_original do |original, *args|
      reads += 1
      sleep 0.05 if slow_load
      original.call(*args)
    end
    allow(File).to receive(:read).and_wrap_original { |original, *args| reads += 1 if args.first.to_s.include?("/lib/"); original.call(*args) }
    yield
    reads
  end

  describe ".yaml" do
    it "reads the file once and returns the same object afterwards" do
      first = nil
      reads = count_disk_reads { 3.times { first ||= described_class.yaml("phrases", "gato") } }

      expect(reads).to eq(1)
      expect(described_class.yaml("phrases", "gato")).to equal(first)
      expect(first).to include("гатю")
    end

    it "deep-freezes what it returns, because every thread shares it" do
      phrases = described_class.yaml("phrases", "gato")

      expect(phrases).to be_frozen
      expect(phrases).to all(be_frozen)
      expect { phrases.first << "!" }.to raise_error(FrozenError)
      expect { phrases << "нове" }.to raise_error(FrozenError)
    end

    it "loads a file only once when many threads ask for it at the same moment" do
      reads = count_disk_reads(slow_load: true) do
        gate = Queue.new
        threads = 10.times.map { Thread.new { gate.pop; described_class.yaml("answers", "sad") } }
        10.times { gate << :go }
        threads.each(&:join)
      end

      expect(reads).to eq(1)
    end
  end

  describe ".erb" do
    it "renders with the given locals on every call, reading the template once" do
      first = second = nil
      reads = count_disk_reads do
        first = described_class.erb("answers", "support", first_name: "Петро")
        second = described_class.erb("answers", "support", first_name: "Ольга")
      end

      expect(reads).to eq(1)
      expect(first.join).to include("Петро")
      expect(second.join).to include("Ольга")
      expect(second.join).not_to include("Петро")
    end
  end

  describe ".text" do
    it "returns the file's text, frozen, read once" do
      text = nil
      reads = count_disk_reads { 2.times { text = described_class.text("lib/ai_prompt/v2.txt") } }

      expect(reads).to eq(1)
      expect(text).to be_frozen
      expect(text).to eq(File.read(Rails.root.join("lib/ai_prompt/v2.txt")))
    end
  end

  context "with code reloading on (development)" do
    before { allow(Rails.application.config).to receive(:enable_reloading).and_return(true) }

    it "reads the file every time, so edits show up without a restart" do
      reads = count_disk_reads { 2.times { described_class.yaml("phrases", "gato") } }

      expect(reads).to eq(2)
    end
  end
end
