<template>
  <article
    class="group flex flex-col bg-white dark:bg-dark-grey p-4 rounded-lg cursor-pointer max-w-[280px]"
  >
    <h3
      class="font-bold select-none pointer-events-none"
      :class="managerStore.dragging ? '' : 'group-hover:text-main-purple'"
    >
      {{ contact.name }}
    </h3>
    <p
      class="text-xs text-medium-grey font-bold select-none pointer-events-none"
    >
      {{ contact.email }}
    </p>
  </article>
</template>

<script setup>
import { computed } from 'vue';
const managerStore = {};
const props = defineProps({
  contact: {
    type: Object,
    required: true,
  },
});

const subcontactsCompleted = computed(() => {
  const completed = props.contact.subcontacts?.filter(
    sub => sub.isCompleted
  )?.length;
  const total = props.contact.subcontacts?.length;
  return `${completed} of ${total}`;
});
</script>
