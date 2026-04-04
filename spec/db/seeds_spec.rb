# frozen_string_literal: true

require 'rails_helper'

describe 'db/seeds.rb' do # rubocop:disable RSpec/DescribeClass
  subject(:run_seeds) { Rails.application.load_seed }

  before do
    # ConfigLoader and GlobalConfig are called in seeds; stub to avoid side effects
    config_loader = instance_double(ConfigLoader, process: nil, general_configs: [])
    allow(ConfigLoader).to receive(:new).and_return(config_loader)
    allow(GlobalConfig).to receive(:clear_cache)
  end

  context 'when in production' do
    before { allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production')) }

    context 'with CHATWOOT_ADMIN_EMAIL and CHATWOOT_ADMIN_PASSWORD set' do
      it 'creates a SuperAdmin user and account, skips onboarding flag' do
        with_modified_env(
          CHATWOOT_ADMIN_EMAIL: 'suporte@chatwoot.app.br',
          CHATWOOT_ADMIN_PASSWORD: 'SecurePass1!',
          CHATWOOT_ADMIN_NAME: 'Suporte',
          CHATWOOT_ADMIN_COMPANY: 'ChatWoot BR'
        ) do
          expect { run_seeds }.to change(User, :count).by(1)

          user = User.from_email('suporte@chatwoot.app.br')
          expect(user).to be_present
          expect(user.type).to eq('SuperAdmin')
          expect(user.confirmed?).to be(true)

          account = Account.last
          expect(account.name).to eq('ChatWoot BR')
          expect(AccountUser.exists?(user_id: user.id, account_id: account.id)).to be(true)

          expect(Redis::Alfred.get(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)).to be_nil
        end
      end
    end

    context 'with CHATWOOT_ADMIN_EMAIL set but user already exists' do
      before do
        user = User.new(name: 'Existing', email: 'suporte@chatwoot.app.br', password: 'OldPass1!', type: 'SuperAdmin')
        user.skip_confirmation!
        user.save!
      end

      it 'skips user creation without error' do
        with_modified_env(
          CHATWOOT_ADMIN_EMAIL: 'suporte@chatwoot.app.br',
          CHATWOOT_ADMIN_PASSWORD: 'SecurePass1!'
        ) do
          expect { run_seeds }.not_to change(User, :count)
          expect(Redis::Alfred.get(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)).to be_nil
        end
      end
    end

    context 'with CHATWOOT_ADMIN_EMAIL set but CHATWOOT_ADMIN_PASSWORD missing' do
      # CHATWOOT_ADMIN_PASSWORD is mandatory when email is set — ENV.fetch raises KeyError intentionally
      it 'raises KeyError' do
        with_modified_env(CHATWOOT_ADMIN_EMAIL: 'suporte@chatwoot.app.br') do
          expect { run_seeds }.to raise_error(KeyError, /CHATWOOT_ADMIN_PASSWORD/)
        end
      end
    end

    context 'without admin env vars' do
      it 'sets the Redis onboarding flag (existing behavior)' do
        with_modified_env(CHATWOOT_ADMIN_EMAIL: nil) do
          run_seeds
          expect(Redis::Alfred.get(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)).to eq('true')
        end
      end
    end
  end
end
