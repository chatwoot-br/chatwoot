<script setup>
import { computed } from 'vue';
import { useMessageContext } from './provider.js';

const { contentAttributes } = useMessageContext();

const reactions = computed(() => {
  const reactionData = contentAttributes.value?.reactions;
  if (!reactionData || typeof reactionData !== 'object') return [];

  return Object.entries(reactionData)
    .filter(([, senders]) => Array.isArray(senders) && senders.length > 0)
    .map(([emoji, senders]) => ({
      emoji,
      count: senders.length,
    }));
});

const hasReactions = computed(() => reactions.value.length > 0);
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <div v-if="hasReactions" class="flex flex-wrap gap-1">
    <span
      v-for="reaction in reactions"
      :key="reaction.emoji"
      class="inline-flex items-center px-1.5 py-0.5 rounded-full text-xs bg-n-alpha-2"
    >
      <span>{{ reaction.emoji }}</span>
      <span v-if="reaction.count > 1" class="ml-0.5 text-n-slate-11">{{
        reaction.count
      }}</span>
    </span>
  </div>
</template>
