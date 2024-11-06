import { ref } from 'vue';
import ContactAPI from 'dashboard/api/contacts';

export function useContacts(label) {
  const data = ref(null);
  const loading = ref(true);
  const error = ref(null);

  const fetchData = async () => {
    try {
      loading.value = true;
      const response = await ContactAPI.get(1, '-last_activity_at', label);
      data.value = response.data.payload;
    } catch (e) {
      error.value = e;
    } finally {
      loading.value = false;
    }
  };

  fetchData();

  return { data, loading, error };
}
