<template>
  <div v-if="chatControlConfig.visible" class="chat-control-container">
    <tui-badge
      :hidden="chatStore.unReadCount === 0"
      :value="chatStore.unReadCount"
      :max="10"
    >
      <icon-button
        :title="t('Chat')"
        :is-active="sidebarName === 'chat'"
        @click-icon="toggleChatSidebar"
      >
        <IconChat size="24" />
      </icon-button>
    </tui-badge>
  </div>
</template>

<script setup lang="ts">
import IconButton from '../common/base/IconButton.vue';
import { IconChat } from '@tencentcloud/uikit-base-component-vue3';
import { useBasicStore } from '../../stores/basic';
import { useChatStore } from '../../stores/chat';
import { storeToRefs } from 'pinia';
import { useI18n } from '../../locales';
import TuiBadge from '../common/base/Badge.vue';
import { roomService, MetricsKey } from '../../services';
const { t } = useI18n();
const chatControlConfig = roomService.getComponentConfig('ChatControl');
const basicStore = useBasicStore();
const chatStore = useChatStore();
const { sidebarName } = storeToRefs(basicStore);

async function toggleChatSidebar() {
  if (basicStore.isSidebarOpen && basicStore.sidebarName === 'chat') {
    basicStore.setSidebarOpenStatus(false);
    basicStore.setSidebarName('');
    return;
  }
  basicStore.setSidebarOpenStatus(true);
  basicStore.setSidebarName('chat');
  chatStore.updateUnReadCount(0);
  roomService.dataReportManager.reportCount(MetricsKey.openChat);
  roomService.trackingManager.sendMessage('experience-chat');
}
</script>
