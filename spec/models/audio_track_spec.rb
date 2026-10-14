require "rails_helper"

RSpec.describe AudioTrack do
  describe "#label" do
    it "prefers the sender's caption, then the tags, then the file name" do
      expect(build(:audio_track, caption: "Розпач — Сон, мікс v3", performer: "Розпач", title: "Сон").label).to eq("Розпач — Сон, мікс v3")
      expect(build(:audio_track, performer: "Розпач", title: "Сон").label).to eq("Розпач — Сон")
      expect(build(:audio_track, title: "Сон").label).to eq("Сон")
      expect(build(:audio_track, file_name: "son_v3.wav").label).to eq("son_v3.wav")
      expect(build(:audio_track, file_name: nil).label).to eq("аудіо")
    end

    it "keeps a long caption to one short line" do
      label = build(:audio_track, caption: "дуже #{'довгий ' * 30}\nопис").label

      expect(label.length).to eq(AudioTrack::LABEL_LENGTH)
      expect(label).not_to include("\n")
    end
  end
end
