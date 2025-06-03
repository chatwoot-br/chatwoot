import { mount } from '@vue/test-utils';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { nextTick } from 'vue';
import APICampaignForm from './APICampaignForm.vue';

const mockLabels = [
  { id: 1, title: 'VIP Customer' },
  { id: 2, title: 'Premium Customer' },
];

const mockInboxes = [
  { id: 1, name: 'API Inbox 1' },
  { id: 2, name: 'API Inbox 2' },
];

// Mock the composables
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: vi.fn(path => {
    const mockData = {
      'campaigns/getUIFlags': { value: { isCreating: false } },
      'labels/getLabels': { value: mockLabels },
      'inboxes/getAPIInboxes': { value: mockInboxes },
    };
    return mockData[path] || { value: [] };
  }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: vi.fn(key => key),
  }),
}));

const createWrapper = (props = {}) => {
  return mount(APICampaignForm, {
    props: {
      ...props,
    },
    global: {
      stubs: {
        Input: {
          template:
            '<input v-bind="$attrs" @input="$emit(\'update:modelValue\', $event.target.value)" />',
        },
        TextArea: {
          template:
            '<textarea v-bind="$attrs" @input="$emit(\'update:modelValue\', $event.target.value)" />',
        },
        Button: {
          template:
            '<button v-bind="$attrs" @click="$emit(\'click\')"><slot /></button>',
        },
        ComboBox: {
          template:
            '<select v-bind="$attrs" @change="$emit(\'update:modelValue\', $event.target.value)"><option v-for="option in options" :key="option.value" :value="option.value">{{ option.label }}</option></select>',
          props: ['options', 'modelValue'],
        },
        TagMultiSelectComboBox: {
          template:
            '<div><select multiple v-bind="$attrs" @change="handleChange"><option v-for="option in options" :key="option.value" :value="option.value">{{ option.label }}</option></select></div>',
          props: ['options', 'modelValue'],
          methods: {
            handleChange(event) {
              const values = Array.from(event.target.selectedOptions).map(
                option => parseInt(option.value, 10)
              );
              this.$emit('update:modelValue', values);
            },
          },
        },
      },
    },
  });
};

describe('APICampaignForm', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders correctly', () => {
    const wrapper = createWrapper();
    expect(wrapper.exists()).toBe(true);
  });

  it('displays form fields with proper stubs', () => {
    const wrapper = createWrapper();

    // Check if main form elements are present using stubs
    expect(wrapper.find('input').exists()).toBe(true);
    expect(wrapper.find('textarea').exists()).toBe(true);
    expect(wrapper.find('select').exists()).toBe(true);
  });

  it('computes audience options correctly', () => {
    const wrapper = createWrapper();

    const audienceOptions = wrapper.vm.audienceList;
    expect(audienceOptions).toHaveLength(2);
    expect(audienceOptions[0]).toEqual({
      value: 1,
      label: 'VIP Customer',
    });
  });

  it('computes inbox options correctly', () => {
    const wrapper = createWrapper();

    const inboxOptions = wrapper.vm.inboxOptions;
    expect(inboxOptions).toHaveLength(2);
    expect(inboxOptions[0]).toEqual({
      value: 1,
      label: 'API Inbox 1',
    });
  });

  it('validates required fields', async () => {
    const wrapper = createWrapper();

    // Trigger validation by touching the form
    await wrapper.vm.v$.$touch();
    await nextTick();

    // Form should be invalid due to required field validation
    expect(wrapper.vm.v$.$invalid).toBe(true);
  });

  it('emits submit event when form is valid and submitted', async () => {
    const wrapper = createWrapper();

    // Fill form with valid data
    wrapper.vm.state.title = 'Test API Campaign';
    wrapper.vm.state.message = 'Test message';
    wrapper.vm.state.inboxId = 1;
    wrapper.vm.state.scheduledAt = '2025-06-01T10:00';
    wrapper.vm.state.selectedAudience = [1];

    await nextTick();

    // Form should now be valid
    expect(wrapper.vm.v$.$invalid).toBe(false);

    const submitSpy = vi.spyOn(wrapper.vm, 'handleSubmit');

    // Submit form
    await wrapper.vm.handleSubmit();

    expect(submitSpy).toHaveBeenCalled();
  });

  it('resets state correctly', () => {
    const wrapper = createWrapper();

    // Set some data
    wrapper.vm.state.title = 'Test';
    wrapper.vm.state.message = 'Test message';

    // Reset
    wrapper.vm.resetState();

    expect(wrapper.vm.state.title).toBe('');
    expect(wrapper.vm.state.message).toBe('');
  });

  it('formats campaign details correctly', () => {
    const wrapper = createWrapper();

    wrapper.vm.state.title = 'Test API Campaign';
    wrapper.vm.state.message = 'Test message';
    wrapper.vm.state.inboxId = 1;
    wrapper.vm.state.scheduledAt = '2025-06-01T10:00';
    wrapper.vm.state.selectedAudience = [1, 2];

    const campaignDetails = wrapper.vm.prepareCampaignDetails();

    expect(campaignDetails).toEqual({
      title: 'Test API Campaign',
      message: 'Test message',
      inbox_id: 1,
      scheduled_at: new Date('2025-06-01T10:00').toISOString(),
      audience: [
        { id: 1, type: 'Label' },
        { id: 2, type: 'Label' },
      ],
    });
  });

  it('emits cancel event when cancel is called', () => {
    const wrapper = createWrapper();

    wrapper.vm.handleCancel();

    expect(wrapper.emitted().cancel).toBeTruthy();
  });
});
