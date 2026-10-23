require "rails_helper"

RSpec.describe "Solid Queue supervisor lifecycle hooks" do
  let(:supervisor) { instance_double(SolidQueue::Supervisor, standalone?: standalone) }
  let(:standalone) { false }

  before { allow(Process).to receive(:kill) }

  def run_hooks(event)
    SolidQueue::Supervisor.lifecycle_hooks.fetch(event).each { |hook| hook.call(supervisor) }
  end

  it "stops Puma when the embedded supervisor exits without being stopped" do
    run_hooks(:start)
    run_hooks(:exit)

    expect(Process).to have_received(:kill).with(:INT, Process.pid)
  end

  it "leaves Puma alone when the supervisor was stopped on purpose" do
    run_hooks(:start)
    run_hooks(:stop)
    run_hooks(:exit)

    expect(Process).not_to have_received(:kill)
  end

  it "watches the supervisor Puma starts again after a restart" do
    run_hooks(:start)
    run_hooks(:stop)
    run_hooks(:exit)
    run_hooks(:start)
    run_hooks(:exit)

    expect(Process).to have_received(:kill).once
  end

  context "when the supervisor runs standalone (bin/jobs)" do
    let(:standalone) { true }

    it "leaves the process alone" do
      run_hooks(:start)
      run_hooks(:exit)

      expect(Process).not_to have_received(:kill)
    end
  end
end
