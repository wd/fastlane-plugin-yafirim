describe Fastlane::Actions::YafirimAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The yafirim plugin is working!")

      Fastlane::Actions::YafirimAction.run(nil)
    end
  end
end
