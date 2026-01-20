require 'rails_helper'

RSpec.describe RegexHelper do
  describe 'WHATSAPP_CHANNEL_REGEX' do
    subject(:regex) { described_class::WHATSAPP_CHANNEL_REGEX }

    context 'with valid phone numbers' do
      it 'matches standard phone numbers' do
        expect(regex.match?('5511999999999')).to be true
        expect(regex.match?('1234567890')).to be true
        expect(regex.match?('123456789012345')).to be true
      end
    end

    context 'with WhatsApp group IDs (@g.us)' do
      it 'matches group IDs' do
        expect(regex.match?('120363421050222105@g.us')).to be true
        expect(regex.match?('123456789@g.us')).to be true
      end
    end

    context 'with WhatsApp LID addresses (@lid)' do
      it 'matches LID addresses' do
        expect(regex.match?('215946727821336@lid')).to be true
        expect(regex.match?('123456789012345@lid')).to be true
      end
    end

    context 'with WhatsApp broadcast lists (@broadcast)' do
      it 'matches broadcast list IDs' do
        expect(regex.match?('1720632860@broadcast')).to be true
        expect(regex.match?('123456789@broadcast')).to be true
      end
    end

    context 'with invalid formats' do
      it 'does not match phone numbers with + prefix' do
        expect(regex.match?('+5511999999999')).to be false
      end

      it 'does not match @s.whatsapp.net addresses' do
        expect(regex.match?('5511999999999@s.whatsapp.net')).to be false
      end

      it 'does not match empty strings' do
        expect(regex.match?('')).to be false
      end

      it 'does not match text strings' do
        expect(regex.match?('invalid')).to be false
      end

      it 'does not match partial suffixes' do
        expect(regex.match?('123456@g')).to be false
        expect(regex.match?('123456@li')).to be false
        expect(regex.match?('123456@broadca')).to be false
      end
    end
  end
end
